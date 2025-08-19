// lib/core/services/realtime_database_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'app_logger.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Enable offline persistence
  Future<void> enableOfflinePersistence() async {
    // setPersistenceEnabled is not supported on web platform
    if (!kIsWeb) {
      _db.setPersistenceEnabled(true);
      _db.setPersistenceCacheSizeBytes(100 * 1024 * 1024); // 100MB cache
    }
  }

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  // ============ PRODUCTS ============
  Stream<List<Map<String, dynamic>>> getProducts({String? category}) {
    Query query = _db.ref('products');

    return query.onValue.map((event) {
      final List<Map<String, dynamic>> products = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final product = Map<String, dynamic>.from(value);
          product['id'] = key;

          // Filter by category if provided
          if (category == null || product['category'] == category) {
            products.add(product);
          }
        });
      }

      // Sort by SKU
      products.sort((a, b) => (a['sku'] ?? '').compareTo(b['sku'] ?? ''));
      return products;
    });
  }

  Future<Map<String, dynamic>?> getProduct(String productId) async {
    final snapshot = await _db.ref('products/$productId').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = productId;
      return data;
    }
    return null;
  }

  Future<void> addProduct(Map<String, dynamic> product) async {
    final newProductRef = _db.ref('products').push();
    await newProductRef.set({
      ...product,
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final snapshot = await _db.ref('products').get();
    final List<Map<String, dynamic>> results = [];

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        final product = Map<String, dynamic>.from(value);
        product['id'] = key;

        final searchText = query.toLowerCase();
        final sku = (product['sku'] ?? '').toString().toLowerCase();
        final description =
            (product['description'] ?? '').toString().toLowerCase();
        final category = (product['category'] ?? '').toString().toLowerCase();

        if (sku.contains(searchText) ||
            description.contains(searchText) ||
            category.contains(searchText)) {
          results.add(product);
        }
      });
    }

    return results;
  }

  // ============ CLIENTS ============
  Stream<List<Map<String, dynamic>>> getClients() {
    if (userId == null) return Stream.value([]);

    return _db
        .ref('clients/$userId')
        .onValue
        .map((event) {
      final List<Map<String, dynamic>> clients = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final client = Map<String, dynamic>.from(value);
          client['id'] = key;
          clients.add(client);
        });
      }
      return clients;
    });
  }

  Future<Map<String, dynamic>?> getClient(String clientId) async {
    if (userId == null) return null;
    final snapshot = await _db.ref('clients/$userId/$clientId').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = clientId;
      return data;
    }
    return null;
  }

  Future<String> addClient(Map<String, dynamic> client) async {
    if (userId == null) throw Exception('User not authenticated');

    final newClientRef = _db.ref('clients/$userId').push();
    await newClientRef.set({
      ...client,
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });
    return newClientRef.key!;
  }

  Future<void> updateClient(
      String clientId, Map<String, dynamic> updates) async {
    if (userId == null) return;
    await _db.ref('clients/$userId/$clientId').update({
      ...updates,
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> deleteClient(String clientId) async {
    if (userId == null) return;
    await _db.ref('clients/$userId/$clientId').remove();
  }

  // ============ CART ============
  Stream<List<Map<String, dynamic>>> getCartItems() {
    if (userId == null) return Stream.value([]);

    return _db
        .ref('cart_items/$userId')
        .onValue
        .map((event) {
      final List<Map<String, dynamic>> items = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final item = Map<String, dynamic>.from(value);
          item['id'] = key;
          items.add(item);
        });
      }
      return items;
    });
  }

  Future<void> addToCart(String productId, int quantity) async {
    if (userId == null) throw Exception('User not authenticated');

    // If quantity is 0 or negative, remove from cart
    if (quantity <= 0) {
      await removeProductFromCart(productId);
      return;
    }

    // Check if item already exists in cart
    final existingSnapshot = await _db
        .ref('cart_items/$userId')
        .once();

    if (existingSnapshot.snapshot.value != null) {
      final data =
          Map<String, dynamic>.from(existingSnapshot.snapshot.value as Map);
      for (var entry in data.entries) {
        final item = Map<String, dynamic>.from(entry.value);
        if (item['product_id'] == productId) {
          // Set the absolute quantity (not add to existing)
          await _db.ref('cart_items/$userId/${entry.key}').update({
            'quantity': quantity,
            'updated_at': ServerValue.timestamp,
          });
          return;
        }
      }
    }

    // Add new item
    final newCartRef = _db.ref('cart_items/$userId').push();
    await newCartRef.set({
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> removeProductFromCart(String productId) async {
    if (userId == null) return;
    
    // Find and remove the cart item with this product ID
    final existingSnapshot = await _db
        .ref('cart_items/$userId')
        .once();

    if (existingSnapshot.snapshot.value != null) {
      final data =
          Map<String, dynamic>.from(existingSnapshot.snapshot.value as Map);
      for (var entry in data.entries) {
        final item = Map<String, dynamic>.from(entry.value);
        if (item['product_id'] == productId) {
          await _db.ref('cart_items/$userId/${entry.key}').remove();
          return;
        }
      }
    }
  }

  Future<void> updateCartItem(String cartItemId, int quantity) async {
    if (userId == null) return;
    if (quantity <= 0) {
      await removeFromCart(cartItemId);
    } else {
      await _db.ref('cart_items/$userId/$cartItemId').update({
        'quantity': quantity,
        'updated_at': ServerValue.timestamp,
      });
    }
  }

  Future<void> removeFromCart(String cartItemId) async {
    if (userId == null) return;
    await _db.ref('cart_items/$userId/$cartItemId').remove();
  }

  Future<void> clearCart() async {
    if (userId == null) return;

    await _db.ref('cart_items/$userId').remove();
  }

  // ============ QUOTES ============
  Stream<List<Map<String, dynamic>>> getQuotes() {
    if (userId == null) return Stream.value([]);

    return _db
        .ref('quotes/$userId')
        .onValue
        .map((event) {
      final List<Map<String, dynamic>> quotes = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final quote = Map<String, dynamic>.from(value);
          quote['id'] = key;
          quotes.add(quote);
        });
      }
      // Sort by created_at descending
      quotes.sort((a, b) {
        final aTime = a['created_at'] ?? 0;
        final bTime = b['created_at'] ?? 0;
        return bTime.compareTo(aTime);
      });
      return quotes;
    });
  }

  Future<Map<String, dynamic>?> getQuote(String quoteId) async {
    if (userId == null) return null;
    final snapshot = await _db.ref('quotes/$userId/$quoteId').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = quoteId;
      return data;
    }
    return null;
  }

  Future<String> createQuote({
    required String clientId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double taxRate,
    required double taxAmount,
    required double totalAmount,
  }) async {
    if (userId == null) throw Exception('User not authenticated');
    
    // Validate inputs
    if (clientId.isEmpty) throw Exception('Client ID cannot be empty');
    if (items.isEmpty) throw Exception('Cannot create quote with no items');

    try {
      final quoteNumber = 'Q${DateTime.now().millisecondsSinceEpoch}';
      final newQuoteRef = _db.ref('quotes/$userId').push();

      await newQuoteRef.set({
        'client_id': clientId,
        'quote_number': quoteNumber,
        'quote_items': items,  // Store items directly in the quote
        'subtotal': subtotal,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'status': 'draft',
        'user_id': userId,  // Add user ID for reference
        'created_at': ServerValue.timestamp,
        'updated_at': ServerValue.timestamp,
      });

      final key = newQuoteRef.key;
      if (key == null) throw Exception('Failed to generate quote ID');
      
      return key;
    } catch (e) {
      AppLogger.error('Error creating quote', 
        error: e, 
        category: LogCategory.quote,
        data: {
          'clientId': clientId,
          'itemsCount': items.length,
          'total': totalAmount,
        });
      throw Exception('Failed to create quote: $e');
    }
  }

  Future<void> updateQuoteStatus(String quoteId, String status) async {
    if (userId == null) return;
    await _db.ref('quotes/$userId/$quoteId').update({
      'status': status,
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> updateQuote(String quoteId, Map<String, dynamic> updates) async {
    if (userId == null) throw Exception('User not authenticated');
    
    try {
      await _db.ref('quotes/$userId/$quoteId').update(updates);
      
      AppLogger.info(
        'Quote updated: $quoteId',
        category: LogCategory.database,
      );
    } catch (e) {
      AppLogger.error(
        'Failed to update quote',
        error: e,
        category: LogCategory.database,
      );
      rethrow;
    }
  }

  Future<void> deleteQuote(String quoteId) async {
    try {
      if (userId == null) {
        throw Exception('User must be authenticated to delete quotes');
      }
      
      // Delete from user's quotes
      final quoteRef = _db.ref('quotes/$userId/$quoteId');
      
      // Check if quote exists
      final snapshot = await quoteRef.get();
      if (!snapshot.exists) {
        throw Exception('Quote not found');
      }
      
      // Delete the quote
      await quoteRef.remove();
      
    } catch (e) {
      // Log error and rethrow
      rethrow;
    }
  }

  // ============ USER PROFILES ============
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snapshot = await _db.ref('user_profiles/$uid').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = uid;
      return data;
    }
    return null;
  }

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String name,
    String role = 'distributor',
    String status = 'active',
  }) async {
    await _db.ref('user_profiles/$uid').set({
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'status': status,
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> updateUserProfile(
      String uid, Map<String, dynamic> updates) async {
    await _db.ref('user_profiles/$uid').update({
      ...updates,
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _db.ref('user_profiles').once();
    if (snapshot.snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      return data.entries.map((entry) {
        final userMap = Map<String, dynamic>.from(entry.value);
        userMap['id'] = entry.key;
        return userMap;
      }).toList();
    }
    return [];
  }

  // ============ STATISTICS ============
  Future<int> getTotalClients() async {
    if (userId == null) return 0;

    final snapshot = await _db
        .ref('clients/$userId')
        .once();

    if (snapshot.snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      return data.length;
    }
    return 0;
  }

  Future<int> getTotalQuotes() async {
    if (userId == null) return 0;

    final snapshot = await _db.ref('quotes/$userId').once();

    if (snapshot.snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      return data.length;
    }
    return 0;
  }

  Future<int> getTotalProducts() async {
    final snapshot = await _db.ref('products').once();

    if (snapshot.snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      return data.length;
    }
    return 0;
  }
}
