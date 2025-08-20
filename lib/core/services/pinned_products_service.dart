// lib/core/services/pinned_products_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Provider for pinned products service
final pinnedProductsServiceProvider = Provider<PinnedProductsService>((ref) {
  return PinnedProductsService();
});

// Provider for pinned products list
final pinnedProductsProvider = StreamProvider<Set<String>>((ref) {
  final service = ref.watch(pinnedProductsServiceProvider);
  return service.watchPinnedProducts();
});

class PinnedProductsService {
  static const String _boxName = 'pinned_products';
  static const String _pinnedKey = 'pinned_product_ids';
  
  late Box _box;
  
  PinnedProductsService() {
    _initBox();
  }
  
  Future<void> _initBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }
  
  // Get all pinned product IDs
  Set<String> getPinnedProducts() {
    try {
      final List<dynamic>? pinnedList = _box.get(_pinnedKey);
      if (pinnedList != null) {
        return Set<String>.from(pinnedList.cast<String>());
      }
    } catch (e) {
      print('Error getting pinned products: $e');
    }
    return {};
  }
  
  // Check if a product is pinned
  bool isProductPinned(String productId) {
    return getPinnedProducts().contains(productId);
  }
  
  // Toggle pin status for a product
  Future<void> toggleProductPin(String productId) async {
    final pinnedProducts = getPinnedProducts();
    
    if (pinnedProducts.contains(productId)) {
      pinnedProducts.remove(productId);
    } else {
      pinnedProducts.add(productId);
    }
    
    await _box.put(_pinnedKey, pinnedProducts.toList());
  }
  
  // Add a product to pinned
  Future<void> pinProduct(String productId) async {
    final pinnedProducts = getPinnedProducts();
    pinnedProducts.add(productId);
    await _box.put(_pinnedKey, pinnedProducts.toList());
  }
  
  // Remove a product from pinned
  Future<void> unpinProduct(String productId) async {
    final pinnedProducts = getPinnedProducts();
    pinnedProducts.remove(productId);
    await _box.put(_pinnedKey, pinnedProducts.toList());
  }
  
  // Clear all pinned products
  Future<void> clearPinnedProducts() async {
    await _box.delete(_pinnedKey);
  }
  
  // Watch pinned products for changes
  Stream<Set<String>> watchPinnedProducts() async* {
    // Emit initial value
    yield getPinnedProducts();
    
    // Then watch for changes
    await for (final event in _box.watch(key: _pinnedKey)) {
      final List<dynamic>? pinnedList = event.value as List<dynamic>?;
      if (pinnedList != null) {
        yield Set<String>.from(pinnedList.cast<String>());
      } else {
        yield {};
      }
    }
  }
}