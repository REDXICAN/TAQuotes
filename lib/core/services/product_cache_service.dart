// lib/core/services/product_cache_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProductCacheService {
  static const String _productsBoxName = 'cached_products';
  static const String _productImagesBoxName = 'cached_product_images';
  static const String _cacheMetaBoxName = 'cache_metadata';
  
  static ProductCacheService? _instance;
  static ProductCacheService get instance => _instance ??= ProductCacheService._();
  
  ProductCacheService._();
  
  late Box<Map> _productsBox;
  late Box<String> _productImagesBox;
  late Box<dynamic> _cacheMetaBox;
  bool _isInitialized = false;
  
  // Cache all products immediately after login
  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;
    
    try {
      _productsBox = await Hive.openBox<Map>(_productsBoxName);
      _productImagesBox = await Hive.openBox<String>(_productImagesBoxName);
      _cacheMetaBox = await Hive.openBox(_cacheMetaBoxName);
      _isInitialized = true;
      
      AppLogger.info('ProductCacheService initialized', 
        category: LogCategory.business,
        data: {
          'cached_products': _productsBox.length,
          'expected_products': 835,
          'cached_images': _productImagesBox.length,
        });
        
      // Check if we need to refresh cache
      await _checkAndRefreshCache();
    } catch (e) {
      AppLogger.error('Failed to initialize ProductCacheService', 
        error: e, 
        category: LogCategory.business);
    }
  }
  
  // Force cache all products from Firebase
  Future<void> cacheAllProducts({bool forceRefresh = false}) async {
    if (!_isInitialized && !kIsWeb) await initialize();
    
    try {
      AppLogger.info('Starting to cache all 835 products', 
        category: LogCategory.business,
        data: {'force_refresh': forceRefresh});
      
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        AppLogger.info('No internet connection, using cached products', 
          category: LogCategory.business);
        return;
      }
      
      // Clear cache if forcing refresh
      if (forceRefresh) {
        await _productsBox.clear();
        await _productImagesBox.clear();
        AppLogger.info('Cleared product cache for refresh', category: LogCategory.business);
      }
      
      // Fetch all products from Firebase
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('products').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        AppLogger.warning('No products found in Firebase', category: LogCategory.business);
        return;
      }
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int cachedCount = 0;
      final int totalProducts = data.length;
      
      AppLogger.info('Processing $totalProducts products for caching...', 
        category: LogCategory.business);
      
      // Batch process products for better performance
      final List<MapEntry<String, dynamic>> entries = data.entries.toList();
      const int batchSize = 50; // Process 50 products at a time
      
      for (int i = 0; i < entries.length; i += batchSize) {
        final int end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
        final batch = entries.sublist(i, end);
        
        // Process batch
        for (var entry in batch) {
          try {
            final productMap = Map<String, dynamic>.from(entry.value);
            productMap['id'] = entry.key;
            
            // Cache product data
            await _productsBox.put(entry.key, productMap);
            
            // Cache product image URL if available
            if (productMap['image_url'] != null) {
              await _productImagesBox.put(entry.key, productMap['image_url']);
            }
            
            cachedCount++;
          } catch (e) {
            AppLogger.error('Failed to cache product ${entry.key}', 
              error: e, 
              category: LogCategory.business);
          }
        }
        
        // Log progress
        if (cachedCount % 100 == 0) {
          AppLogger.info('Cached $cachedCount/$totalProducts products...', 
            category: LogCategory.business);
        }
      }
      
      // Update cache metadata
      await _cacheMetaBox.put('last_cache_time', DateTime.now().toIso8601String());
      await _cacheMetaBox.put('total_products_cached', cachedCount);
      
      AppLogger.info('Successfully cached all products', 
        category: LogCategory.business,
        data: {
          'total_cached': cachedCount,
          'expected': 835,
          'cache_time': DateTime.now().toIso8601String(),
        });
        
    } catch (e) {
      AppLogger.error('Failed to cache products', 
        error: e, 
        category: LogCategory.business);
    }
  }
  
  // Get all cached products
  Future<List<Product>> getCachedProducts({String? category}) async {
    if (!_isInitialized && !kIsWeb) await initialize();
    
    try {
      final List<Product> products = [];
      
      // Try to get from cache first
      if (_productsBox.isNotEmpty) {
        for (var key in _productsBox.keys) {
          final productMap = _productsBox.get(key);
          if (productMap != null) {
            final product = Product.fromMap(Map<String, dynamic>.from(productMap));
            
            // Filter by category if specified
            if (category == null || product.category == category) {
              products.add(product);
            }
          }
        }
        
        AppLogger.info('Retrieved products from cache', 
          category: LogCategory.business,
          data: {
            'count': products.length,
            'category': category ?? 'all',
          });
      }
      
      // If cache is empty, try to fetch from Firebase
      if (products.isEmpty) {
        AppLogger.info('Cache empty, fetching from Firebase', category: LogCategory.business);
        await cacheAllProducts();
        
        // Retry getting from cache
        return getCachedProducts(category: category);
      }
      
      // Sort by SKU
      products.sort((a, b) => (a.sku ?? '').compareTo(b.sku ?? ''));
      return products;
      
    } catch (e) {
      AppLogger.error('Failed to get cached products', 
        error: e, 
        category: LogCategory.business);
      return [];
    }
  }
  
  // Get single cached product
  Future<Product?> getCachedProduct(String productId) async {
    if (!_isInitialized && !kIsWeb) await initialize();
    
    try {
      final productMap = _productsBox.get(productId);
      if (productMap != null) {
        return Product.fromMap(Map<String, dynamic>.from(productMap));
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get cached product $productId', 
        error: e, 
        category: LogCategory.business);
      return null;
    }
  }
  
  // Check if cache needs refresh (older than 24 hours or incomplete)
  Future<void> _checkAndRefreshCache() async {
    try {
      final lastCacheTime = _cacheMetaBox.get('last_cache_time');
      final cachedCount = _productsBox.length;
      
      // Check if we have all 835 products cached
      if (cachedCount < 835) {
        AppLogger.info('Incomplete cache detected: $cachedCount/835 products. Refreshing...', 
          category: LogCategory.business);
        await cacheAllProducts(forceRefresh: true);
        return;
      }
      
      if (lastCacheTime == null) {
        // No cache time recorded, refresh cache
        await cacheAllProducts();
        return;
      }
      
      final lastCache = DateTime.parse(lastCacheTime);
      final now = DateTime.now();
      final difference = now.difference(lastCache);
      
      // Refresh if cache is older than 24 hours
      if (difference.inHours > 24) {
        AppLogger.info('Cache is stale (${difference.inHours} hours old), refreshing', 
          category: LogCategory.business);
        await cacheAllProducts(forceRefresh: true);
      } else {
        AppLogger.info('Cache is fresh (${difference.inHours} hours old)', 
          category: LogCategory.business);
      }
    } catch (e) {
      AppLogger.error('Failed to check cache freshness', 
        error: e, 
        category: LogCategory.business);
    }
  }
  
  // Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_isInitialized && !kIsWeb) await initialize();
    
    return {
      'total_products': _productsBox.length,
      'total_images': _productImagesBox.length,
      'last_cache_time': _cacheMetaBox.get('last_cache_time') ?? 'Never',
      'cache_size_kb': await _estimateCacheSize(),
    };
  }
  
  // Estimate cache size
  Future<int> _estimateCacheSize() async {
    int totalSize = 0;
    
    // Estimate product data size
    for (var key in _productsBox.keys) {
      final product = _productsBox.get(key);
      if (product != null) {
        totalSize += product.toString().length;
      }
    }
    
    // Estimate image URL size
    for (var key in _productImagesBox.keys) {
      final imageUrl = _productImagesBox.get(key);
      if (imageUrl != null) {
        totalSize += imageUrl.length;
      }
    }
    
    return totalSize ~/ 1024; // Convert to KB
  }
  
  // Clear all cached products
  Future<void> clearCache() async {
    if (!_isInitialized && !kIsWeb) await initialize();
    
    try {
      await _productsBox.clear();
      await _productImagesBox.clear();
      await _cacheMetaBox.clear();
      
      AppLogger.info('Cleared all product cache', category: LogCategory.business);
    } catch (e) {
      AppLogger.error('Failed to clear cache', 
        error: e, 
        category: LogCategory.business);
    }
  }
  
  // Close boxes when app terminates
  Future<void> dispose() async {
    if (_isInitialized) {
      await _productsBox.close();
      await _productImagesBox.close();
      await _cacheMetaBox.close();
      _isInitialized = false;
    }
  }
}