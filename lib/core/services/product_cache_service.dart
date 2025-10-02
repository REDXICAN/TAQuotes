/// Product Cache Service Stub
///
/// Firebase already caches products through its offline persistence.
/// This is kept as a stub for compatibility with existing code.
library;

import '../models/models.dart';

class ProductCacheService {
  static ProductCacheService? _instance;
  static ProductCacheService get instance => _instance ??= ProductCacheService._();

  ProductCacheService._();

  // Initialization flag kept for compatibility but not actively used
  // Firebase handles all caching automatically
  // ignore: unused_field
  bool _isInitialized = true;

  // No initialization needed - Firebase handles caching
  Future<void> initialize() async {
    _isInitialized = true;
  }

  // Firebase automatically caches products
  Future<void> cacheAllProducts({bool forceRefresh = false}) async {
    // Firebase handles this through offline persistence
  }

  // Firebase retrieves from cache when offline
  Future<List<Product>> getCachedProducts() async {
    return []; // Let Firebase providers handle product retrieval
  }

  // Firebase manages its own cache
  Future<void> clearCache() async {
    // Firebase handles this
  }

  bool get isInitialized => true;
}