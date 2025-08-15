// lib/core/services/cache_manager.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class CacheManager {
  static const String _cacheBox = 'app_cache';
  static const String _metadataBox = 'cache_metadata';
  static const Duration _defaultExpiration = Duration(hours: 24);

  static late Box _cache;
  static late Box _metadata;

  // Initialize cache boxes - static method
  static Future<void> initialize() async {
    if (kIsWeb) return; // Skip initialization on web
    _cache = await Hive.openBox(_cacheBox);
    _metadata = await Hive.openBox(_metadataBox);
  }

  // Cache a value with expiration
  static Future<void> cacheValue({
    required String key,
    required dynamic value,
    Duration expiration = _defaultExpiration,
  }) async {
    if (kIsWeb) return; // Skip caching on web
    final expirationTime = DateTime.now().add(expiration).toIso8601String();

    // Store the value
    await _cache.put(key, jsonEncode(value));

    // Store metadata
    await _metadata.put(key, {
      'expiration': expirationTime,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  // Get cached value if not expired
  static dynamic getCachedValue(String key) {
    if (kIsWeb) return null; // No caching on web
    // Check if cache is initialized
    if (!Hive.isBoxOpen(_metadataBox) || !Hive.isBoxOpen(_cacheBox)) {
      return null;
    }
    
    final metadata = _metadata.get(key);

    if (metadata == null) return null;

    final expiration = DateTime.parse(metadata['expiration']);

    if (DateTime.now().isAfter(expiration)) {
      // Cache expired, remove it
      _cache.delete(key);
      _metadata.delete(key);
      return null;
    }

    final cachedValue = _cache.get(key);
    if (cachedValue != null) {
      return jsonDecode(cachedValue);
    }

    return null;
  }

  // Check if cache exists and is valid
  static bool isCached(String key) {
    final metadata = _metadata.get(key);

    if (metadata == null) return false;

    final expiration = DateTime.parse(metadata['expiration']);
    return DateTime.now().isBefore(expiration);
  }

  // Clear specific cache
  static Future<void> clearCache(String key) async {
    await _cache.delete(key);
    await _metadata.delete(key);
  }

  // Clear all cache
  static Future<void> clearAllCache() async {
    await _cache.clear();
    await _metadata.clear();
  }

  // Get cache size
  static int getCacheSize() {
    int size = 0;

    for (var key in _cache.keys) {
      final value = _cache.get(key);
      if (value != null) {
        size += value.toString().length;
      }
    }

    return size;
  }

  // Clean expired cache entries
  static Future<void> cleanExpiredCache() async {
    final keysToRemove = <String>[];

    for (var key in _metadata.keys) {
      final metadata = _metadata.get(key);
      if (metadata != null) {
        final expiration = DateTime.parse(metadata['expiration']);
        if (DateTime.now().isAfter(expiration)) {
          keysToRemove.add(key as String);
        }
      }
    }

    for (var key in keysToRemove) {
      await _cache.delete(key);
      await _metadata.delete(key);
    }
  }

  // Preload critical data for offline use
  static Future<void> preloadCriticalData(String userId) async {
    try {
      final database = FirebaseDatabase.instance;

      // Preload products
      final productsSnapshot = await database.ref('products').once();
      if (productsSnapshot.snapshot.value != null) {
        await cacheValue(
          key: 'products_all',
          value: productsSnapshot.snapshot.value,
          expiration: const Duration(days: 7), // Products don't change often
        );
      }

      // Preload user's clients
      final clientsSnapshot = await database
          .ref('clients')
          .orderByChild('user_id')
          .equalTo(userId)
          .once();

      if (clientsSnapshot.snapshot.value != null) {
        await cacheValue(
          key: 'clients_$userId',
          value: clientsSnapshot.snapshot.value,
          expiration: const Duration(days: 1),
        );
      }

      // Preload user's quotes
      final quotesSnapshot = await database
          .ref('quotes')
          .orderByChild('user_id')
          .equalTo(userId)
          .once();

      if (quotesSnapshot.snapshot.value != null) {
        await cacheValue(
          key: 'quotes_$userId',
          value: quotesSnapshot.snapshot.value,
          expiration: const Duration(hours: 6),
        );
      }

      // Preload user's cart
      final cartSnapshot = await database
          .ref('cart_items')
          .orderByChild('user_id')
          .equalTo(userId)
          .once();

      if (cartSnapshot.snapshot.value != null) {
        await cacheValue(
          key: 'cart_$userId',
          value: cartSnapshot.snapshot.value,
          expiration: const Duration(hours: 1),
        );
      }

      // Preload user profile
      final profileSnapshot =
          await database.ref('user_profiles/$userId').once();

      if (profileSnapshot.snapshot.value != null) {
        await cacheValue(
          key: 'profile_$userId',
          value: profileSnapshot.snapshot.value,
          expiration: const Duration(days: 1),
        );
      }
    } catch (e) {
      // Error preloading critical data
    }
  }

  // Get cached data with fallback to database
  static Future<dynamic> getWithFallback({
    required String cacheKey,
    required Future<dynamic> Function() fetchFunction,
    Duration expiration = _defaultExpiration,
  }) async {
    // Try to get from cache first
    final cachedData = getCachedValue(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    // Fetch from database
    try {
      final data = await fetchFunction();

      // Cache the result
      if (data != null) {
        await cacheValue(
          key: cacheKey,
          value: data,
          expiration: expiration,
        );
      }

      return data;
    } catch (e) {
      // If fetch fails, try to return expired cache if available
      if (Hive.isBoxOpen(_cacheBox)) {
        final expiredCache = _cache.get(cacheKey);
        if (expiredCache != null) {
          return jsonDecode(expiredCache);
        }
      }

      rethrow;
    }
  }
  
  // Helper methods expected by UI components
  static List getProducts() {
    final data = getCachedValue('products_all');
    if (data is Map) {
      return data.values.toList();
    }
    return [];
  }
  
  static List getClients() {
    final data = getCachedValue('clients_current_user');
    if (data is Map) {
      return data.values.toList();
    }
    return [];
  }
  
  static List getQuotes() {
    final data = getCachedValue('quotes_current_user');
    if (data is Map) {
      return data.values.toList();
    }
    return [];
  }
  
  static List getCart() {
    final data = getCachedValue('cart_current_user');
    if (data is Map) {
      return data.values.toList();
    }
    return [];
  }
}
