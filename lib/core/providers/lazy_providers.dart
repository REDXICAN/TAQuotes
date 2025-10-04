// Lazy-loaded providers for performance optimization
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/app_logger.dart';
import '../models/models.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// Lazy initialization flag provider
final _providersInitializedProvider = StateProvider<Set<String>>((ref) => {});

// Helper to check if a provider is initialized
bool _isInitialized(WidgetRef ref, String providerName) {
  return ref.read(_providersInitializedProvider).contains(providerName);
}

// Helper to mark a provider as initialized
void _markInitialized(WidgetRef ref, String providerName) {
  ref.read(_providersInitializedProvider.notifier).update((set) => {...set, providerName});
}

// Lazy-loaded products provider - only loads when first accessed
final lazyProductsProvider = FutureProvider.family<List<Product>, int>((ref, limit) async {
  AppLogger.info('Lazy loading products (limit: $limit)', category: LogCategory.performance);

  final database = FirebaseDatabase.instance;
  final snapshot = await database.ref('products').limitToFirst(limit).get();

  if (!snapshot.exists || snapshot.value == null) {
    return [];
  }

  final productsMap = Map<String, dynamic>.from(snapshot.value as Map);
  final products = <Product>[];

  for (final entry in productsMap.entries) {
    try {
      products.add(Product.fromJson({
        'id': entry.key,
        ...Map<String, dynamic>.from(entry.value as Map),
      }));
    } catch (e) {
      AppLogger.error('Error parsing product ${entry.key}', error: e);
    }
  }

  return products;
});

// Lazy-loaded clients provider - only loads when first accessed
final lazyClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) async {
  AppLogger.info('Lazy loading clients', category: LogCategory.performance);

  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final database = FirebaseDatabase.instance;
  final snapshot = await database.ref('clients/${user.uid}').get();

  if (!snapshot.exists || snapshot.value == null) {
    return [];
  }

  final clientsMap = Map<String, dynamic>.from(snapshot.value as Map);
  final clients = <Client>[];

  for (final entry in clientsMap.entries) {
    try {
      clients.add(Client.fromJson({
        'id': entry.key,
        ...Map<String, dynamic>.from(entry.value as Map),
      }));
    } catch (e) {
      AppLogger.error('Error parsing client ${entry.key}', error: e);
    }
  }

  return clients;
});

// Lazy-loaded quotes provider - only loads when first accessed
final lazyQuotesProvider = FutureProvider.autoDispose<List<Quote>>((ref) async {
  AppLogger.info('Lazy loading quotes', category: LogCategory.performance);

  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final database = FirebaseDatabase.instance;
  final snapshot = await database.ref('quotes/${user.uid}').get();

  if (!snapshot.exists || snapshot.value == null) {
    return [];
  }

  final quotesMap = Map<String, dynamic>.from(snapshot.value as Map);
  final quotes = <Quote>[];

  for (final entry in quotesMap.entries) {
    try {
      final quoteData = Map<String, dynamic>.from(entry.value as Map);
      quotes.add(Quote(
        id: entry.key,
        quoteNumber: quoteData['quoteNumber'] ?? '',
        createdAt: DateTime.tryParse(quoteData['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(quoteData['updatedAt'] ?? '') ?? DateTime.now(),
        status: quoteData['status'] ?? 'draft',
        clientId: quoteData['clientId'],
        items: [],
        subtotal: (quoteData['subtotal'] ?? 0).toDouble(),
        tax: (quoteData['tax'] ?? 0).toDouble(),
        total: (quoteData['total'] ?? 0).toDouble(),
        notes: quoteData['notes'],
      ));
    } catch (e) {
      AppLogger.error('Error parsing quote ${entry.key}', error: e);
    }
  }

  quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return quotes;
});

// Paginated products provider for infinite scrolling
final paginatedProductsProvider = StateNotifierProvider<PaginatedProductsNotifier, AsyncValue<List<Product>>>((ref) {
  return PaginatedProductsNotifier(ref);
});

class PaginatedProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final Ref ref;
  final int _pageSize = 24;
  String? _lastKey;
  bool _hasMore = true;
  final List<Product> _allProducts = [];

  PaginatedProductsNotifier(this.ref) : super(const AsyncValue.loading());

  bool get hasMore => _hasMore;

  Future<void> loadInitial() async {
    if (_allProducts.isNotEmpty) {
      state = AsyncValue.data(_allProducts);
      return;
    }

    state = const AsyncValue.loading();

    try {
      AppLogger.info('Loading initial products page', category: LogCategory.performance);

      final database = FirebaseDatabase.instance;
      final query = database.ref('products').orderByKey().limitToFirst(_pageSize + 1);
      final snapshot = await query.get();

      if (!snapshot.exists || snapshot.value == null) {
        state = const AsyncValue.data([]);
        _hasMore = false;
        return;
      }

      final productsMap = Map<String, dynamic>.from(snapshot.value as Map);
      final products = <Product>[];
      final keys = productsMap.keys.toList()..sort();

      for (int i = 0; i < keys.length && i < _pageSize; i++) {
        final key = keys[i];
        try {
          products.add(Product.fromJson({
            'id': key,
            ...Map<String, dynamic>.from(productsMap[key] as Map),
          }));
        } catch (e) {
          AppLogger.error('Error parsing product $key', error: e);
        }
      }

      _hasMore = keys.length > _pageSize;
      if (_hasMore) {
        _lastKey = keys[_pageSize - 1];
      }

      _allProducts.clear();
      _allProducts.addAll(products);
      state = AsyncValue.data(List.from(_allProducts));

      AppLogger.info('Loaded ${products.length} products, hasMore: $_hasMore', category: LogCategory.performance);
    } catch (e, stack) {
      AppLogger.error('Error loading initial products', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading || _lastKey == null) return;

    try {
      AppLogger.info('Loading more products from key: $_lastKey', category: LogCategory.performance);

      final database = FirebaseDatabase.instance;
      final query = database.ref('products')
          .orderByKey()
          .startAfter(_lastKey)
          .limitToFirst(_pageSize + 1);
      final snapshot = await query.get();

      if (!snapshot.exists || snapshot.value == null) {
        _hasMore = false;
        return;
      }

      final productsMap = Map<String, dynamic>.from(snapshot.value as Map);
      final products = <Product>[];
      final keys = productsMap.keys.toList()..sort();

      for (int i = 0; i < keys.length && i < _pageSize; i++) {
        final key = keys[i];
        try {
          products.add(Product.fromJson({
            'id': key,
            ...Map<String, dynamic>.from(productsMap[key] as Map),
          }));
        } catch (e) {
          AppLogger.error('Error parsing product $key', error: e);
        }
      }

      _hasMore = keys.length > _pageSize;
      if (_hasMore && keys.length > _pageSize) {
        _lastKey = keys[_pageSize - 1];
      }

      _allProducts.addAll(products);
      state = AsyncValue.data(List.from(_allProducts));

      AppLogger.info('Loaded ${products.length} more products, total: ${_allProducts.length}', category: LogCategory.performance);
    } catch (e, stack) {
      AppLogger.error('Error loading more products', error: e, stackTrace: stack);
    }
  }

  void reset() {
    _allProducts.clear();
    _lastKey = null;
    _hasMore = true;
    state = const AsyncValue.loading();
  }
}

// Cached providers with TTL
final _cacheTimestamps = <String, DateTime>{};
const _cacheTTL = Duration(minutes: 5);

bool _isCacheValid(String key) {
  final timestamp = _cacheTimestamps[key];
  if (timestamp == null) return false;
  return DateTime.now().difference(timestamp) < _cacheTTL;
}

void _updateCacheTimestamp(String key) {
  _cacheTimestamps[key] = DateTime.now();
}

// Export convenience methods
class LazyProviders {
  static Future<List<Product>> getProducts(WidgetRef ref, {int limit = 50}) async {
    return await ref.read(lazyProductsProvider(limit).future);
  }

  static Future<List<Client>> getClients(WidgetRef ref) async {
    return await ref.read(lazyClientsProvider.future);
  }

  static Future<List<Quote>> getQuotes(WidgetRef ref) async {
    return await ref.read(lazyQuotesProvider.future);
  }

  static void preloadEssentials(WidgetRef ref) {
    // Preload only the most essential data
    ref.read(lazyProductsProvider(24)); // Load first 24 products
    ref.read(lazyClientsProvider); // Load clients for current user
  }
}