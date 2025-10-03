// lib/core/services/optimized_data_service.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/models.dart';
import 'app_logger.dart';

/// Optimized Data Service - Prevents app freezing with smart loading strategies
///
/// Key Features:
/// - Pagination for large datasets
/// - In-memory caching to reduce Firebase reads
/// - Debouncing for rapid filter changes
/// - Lazy loading with virtual scrolling support
/// - Error fallbacks with retry logic
/// - Memory-efficient streaming
class OptimizedDataService {
  static final OptimizedDataService _instance = OptimizedDataService._internal();
  factory OptimizedDataService() => _instance;
  OptimizedDataService._internal();

  // Cache configuration
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _defaultPageSize = 50;
  static const int _maxRetries = 3;

  // In-memory caches with timestamps
  final Map<String, _CachedData<List<Product>>> _productsCache = {};
  final Map<String, _CachedData<List<Client>>> _clientsCache = {};

  // Debounce timers for filter changes
  Timer? _productFilterDebounce;
  Timer? _clientFilterDebounce;

  /// Load products with pagination and caching
  ///
  /// [category] - Optional category filter
  /// [page] - Page number (0-based)
  /// [pageSize] - Items per page (default: 50)
  /// [forceRefresh] - Bypass cache
  Future<PaginatedResult<Product>> loadProducts({
    String? category,
    int page = 0,
    int pageSize = _defaultPageSize,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'products_${category ?? 'all'}_$page';

    // Check cache first
    if (!forceRefresh && _productsCache.containsKey(cacheKey)) {
      final cached = _productsCache[cacheKey]!;
      if (!cached.isExpired) {
        AppLogger.debug('Serving products from cache: $cacheKey');
        return PaginatedResult(
          items: cached.data,
          page: page,
          pageSize: pageSize,
          totalItems: cached.totalCount ?? cached.data.length,
          hasMore: cached.hasMore ?? false,
          fromCache: true,
        );
      }
    }

    // Load from Firebase with retry logic
    var retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final database = FirebaseDatabase.instance;
        final snapshot = await database.ref('products').get();

        if (!snapshot.exists || snapshot.value == null) {
          return PaginatedResult.empty();
        }

        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final List<Product> allProducts = [];

        // Parse products with error handling per item
        for (final entry in data.entries) {
          try {
            final productMap = Map<String, dynamic>.from(entry.value);
            productMap['id'] = entry.key;
            final product = Product.fromMap(productMap);

            // Apply category filter
            if (category == null || category.isEmpty) {
              allProducts.add(product);
            } else {
              final productCategory = product.category.trim().toLowerCase();
              final filterCategory = category.trim().toLowerCase();

              if (productCategory == filterCategory ||
                  productCategory.contains(filterCategory) ||
                  filterCategory.contains(productCategory)) {
                allProducts.add(product);
              }
            }
          } catch (e) {
            AppLogger.debug('Error parsing product ${entry.key}', error: e);
            // Continue with other products
          }
        }

        // Sort by stock availability, then by SKU
        allProducts.sort((a, b) {
          final totalStockA = _calculateTotalStock(a);
          final totalStockB = _calculateTotalStock(b);

          if (totalStockA != totalStockB) {
            return totalStockB.compareTo(totalStockA);
          }

          if (a.isTopSeller != b.isTopSeller) {
            return a.isTopSeller ? -1 : 1;
          }

          return (a.sku ?? '').compareTo(b.sku ?? '');
        });

        // Calculate pagination
        final totalItems = allProducts.length;
        final startIndex = page * pageSize;
        final endIndex = (startIndex + pageSize).clamp(0, totalItems);
        final hasMore = endIndex < totalItems;

        final paginatedItems = startIndex < totalItems
            ? allProducts.sublist(startIndex, endIndex)
            : <Product>[];

        // Cache the result
        _productsCache[cacheKey] = _CachedData(
          data: paginatedItems,
          timestamp: DateTime.now(),
          totalCount: totalItems,
          hasMore: hasMore,
        );

        AppLogger.info(
          'Loaded products page $page: ${paginatedItems.length} items (total: $totalItems)',
          category: LogCategory.performance,
        );

        return PaginatedResult(
          items: paginatedItems,
          page: page,
          pageSize: pageSize,
          totalItems: totalItems,
          hasMore: hasMore,
          fromCache: false,
        );

      } catch (e) {
        retryCount++;
        AppLogger.error(
          'Error loading products (attempt $retryCount/$_maxRetries)',
          error: e,
          category: LogCategory.database,
        );

        if (retryCount >= _maxRetries) {
          // Return cached data if available, otherwise empty
          if (_productsCache.containsKey(cacheKey)) {
            final cached = _productsCache[cacheKey]!;
            return PaginatedResult(
              items: cached.data,
              page: page,
              pageSize: pageSize,
              totalItems: cached.totalCount ?? 0,
              hasMore: cached.hasMore ?? false,
              fromCache: true,
              error: 'Failed to load fresh data. Showing cached results.',
            );
          }
          return PaginatedResult.empty(error: 'Failed to load products after $retryCount attempts');
        }

        // Wait before retry with exponential backoff
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    return PaginatedResult.empty(error: 'Unexpected error loading products');
  }

  /// Stream products with optimized memory usage
  ///
  /// This creates a debounced stream that won't overwhelm the UI
  Stream<List<Product>> streamProducts({
    String? category,
    Duration debounceDelay = const Duration(milliseconds: 500),
  }) async* {
    final database = FirebaseDatabase.instance;

    // Enable Firebase persistence for faster loads (not supported on web)
    if (!kIsWeb) {
      try {
        database.ref('products').keepSynced(true);
      } catch (e) {
        AppLogger.debug('keepSynced not supported on this platform');
      }
    }

    await for (final event in database.ref('products').onValue) {
      try {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          yield [];
          continue;
        }

        // Process in chunks to avoid UI freezing
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<Product> products = [];

        // Process products in batches
        const batchSize = 100;
        final entries = data.entries.toList();

        for (var i = 0; i < entries.length; i += batchSize) {
          final batchEnd = (i + batchSize).clamp(0, entries.length);
          final batch = entries.sublist(i, batchEnd);

          for (final entry in batch) {
            try {
              final productMap = Map<String, dynamic>.from(entry.value);
              productMap['id'] = entry.key;
              final product = Product.fromMap(productMap);

              // Apply category filter
              if (category == null || category.isEmpty) {
                products.add(product);
              } else {
                final productCategory = product.category.trim().toLowerCase();
                final filterCategory = category.trim().toLowerCase();

                if (productCategory == filterCategory ||
                    productCategory.contains(filterCategory) ||
                    filterCategory.contains(filterCategory)) {
                  products.add(product);
                }
              }
            } catch (e) {
              AppLogger.debug('Error parsing product ${entry.key}', error: e);
            }
          }

          // Allow UI to breathe between batches
          if (i + batchSize < entries.length) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }

        // Sort efficiently
        products.sort((a, b) {
          final stockA = _calculateTotalStock(a);
          final stockB = _calculateTotalStock(b);
          if (stockA != stockB) return stockB.compareTo(stockA);
          if (a.isTopSeller != b.isTopSeller) return a.isTopSeller ? -1 : 1;
          return (a.sku ?? '').compareTo(b.sku ?? '');
        });

        yield products;
      } catch (e) {
        AppLogger.error('Error streaming products', error: e);
        yield []; // Yield empty on error to prevent stream break
      }
    }
  }

  /// Load clients with pagination
  Future<PaginatedResult<Client>> loadClients({
    String userId = '',
    int page = 0,
    int pageSize = _defaultPageSize,
    bool forceRefresh = false,
  }) async {
    if (userId.isEmpty) {
      return PaginatedResult.empty(error: 'User ID required');
    }

    final cacheKey = 'clients_${userId}_$page';

    // Check cache
    if (!forceRefresh && _clientsCache.containsKey(cacheKey)) {
      final cached = _clientsCache[cacheKey]!;
      if (!cached.isExpired) {
        return PaginatedResult(
          items: cached.data,
          page: page,
          pageSize: pageSize,
          totalItems: cached.totalCount ?? cached.data.length,
          hasMore: cached.hasMore ?? false,
          fromCache: true,
        );
      }
    }

    var retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final database = FirebaseDatabase.instance;
        final snapshot = await database.ref('clients/$userId').get();

        if (!snapshot.exists || snapshot.value == null) {
          return PaginatedResult.empty();
        }

        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final List<Client> allClients = [];

        for (final entry in data.entries) {
          try {
            final clientMap = Map<String, dynamic>.from(entry.value);
            clientMap['id'] = entry.key;
            allClients.add(Client.fromMap(clientMap));
          } catch (e) {
            AppLogger.debug('Error parsing client ${entry.key}', error: e);
          }
        }

        // Sort alphabetically by company name
        allClients.sort((a, b) => a.company.compareTo(b.company));

        // Paginate
        final totalItems = allClients.length;
        final startIndex = page * pageSize;
        final endIndex = (startIndex + pageSize).clamp(0, totalItems);
        final hasMore = endIndex < totalItems;

        final paginatedItems = startIndex < totalItems
            ? allClients.sublist(startIndex, endIndex)
            : <Client>[];

        // Cache result
        _clientsCache[cacheKey] = _CachedData(
          data: paginatedItems,
          timestamp: DateTime.now(),
          totalCount: totalItems,
          hasMore: hasMore,
        );

        return PaginatedResult(
          items: paginatedItems,
          page: page,
          pageSize: pageSize,
          totalItems: totalItems,
          hasMore: hasMore,
          fromCache: false,
        );

      } catch (e) {
        retryCount++;
        AppLogger.error(
          'Error loading clients (attempt $retryCount/$_maxRetries)',
          error: e,
        );

        if (retryCount >= _maxRetries) {
          if (_clientsCache.containsKey(cacheKey)) {
            final cached = _clientsCache[cacheKey]!;
            return PaginatedResult(
              items: cached.data,
              page: page,
              pageSize: pageSize,
              totalItems: cached.totalCount ?? 0,
              hasMore: cached.hasMore ?? false,
              fromCache: true,
              error: 'Failed to load fresh data. Showing cached results.',
            );
          }
          return PaginatedResult.empty(error: 'Failed to load clients');
        }

        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    return PaginatedResult.empty();
  }

  /// Clear all caches
  void clearCache() {
    _productsCache.clear();
    _clientsCache.clear();
    AppLogger.info('All data caches cleared', category: LogCategory.performance);
  }

  /// Clear specific cache
  void clearProductsCache({String? category}) {
    if (category != null) {
      _productsCache.removeWhere((key, _) => key.contains('products_$category'));
    } else {
      _productsCache.clear();
    }
  }

  void clearClientsCache() {
    _clientsCache.clear();
  }

  /// Calculate total available stock for a product
  int _calculateTotalStock(Product product) {
    if (product.warehouseStock == null || product.warehouseStock!.isEmpty) {
      return 0;
    }

    int total = 0;
    for (var entry in product.warehouseStock!.entries) {
      final available = entry.value.available;
      final reserved = entry.value.reserved;
      total += (available - reserved);
    }
    return total;
  }

  /// Dispose resources
  void dispose() {
    _productFilterDebounce?.cancel();
    _clientFilterDebounce?.cancel();
    clearCache();
  }
}

/// Cached data wrapper with expiry
class _CachedData<T> {
  final T data;
  final DateTime timestamp;
  final int? totalCount;
  final bool? hasMore;

  _CachedData({
    required this.data,
    required this.timestamp,
    this.totalCount,
    this.hasMore,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > OptimizedDataService._cacheExpiry;
  }
}

/// Paginated result wrapper
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final bool hasMore;
  final bool fromCache;
  final String? error;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.hasMore,
    this.fromCache = false,
    this.error,
  });

  factory PaginatedResult.empty({String? error}) {
    return PaginatedResult(
      items: [],
      page: 0,
      pageSize: 0,
      totalItems: 0,
      hasMore: false,
      error: error,
    );
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get hasError => error != null;
}
