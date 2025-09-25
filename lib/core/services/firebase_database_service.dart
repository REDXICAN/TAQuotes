// lib/core/services/firebase_database_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'app_logger.dart';
import 'rate_limiter_service.dart';

class FirebaseDatabaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static DatabaseReference get _ref => _database.ref();
  static final RateLimiterService _rateLimiter = RateLimiterService();

  // Get current user ID
  static String? get userId => FirebaseAuth.instance.currentUser?.uid;

  // ============ PRODUCTS ============
  static Stream<List<Map<String, dynamic>>> getProducts() {
    return _ref.child('products').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries.map((entry) {
        final product = Map<String, dynamic>.from(entry.value);
        product['id'] = entry.key;
        // Ensure price is a double
        if (product['price'] != null) {
          product['price'] = (product['price'] as num).toDouble();
        }
        return product;
      }).toList()
        ..sort((a, b) =>
            (a['sku'] ?? '').toString().compareTo((b['sku'] ?? '').toString()));
    });
  }

  static Future<Map<String, dynamic>?> getProduct(String productId) async {
    final snapshot = await _ref.child('products/$productId').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = productId;
      if (data['price'] != null) {
        data['price'] = (data['price'] as num).toDouble();
      }
      return data;
    }
    return null;
  }

  static Stream<List<Map<String, dynamic>>> getProductsByCategory(
      String category) {
    return _ref
        .child('products')
        .orderByChild('category')
        .equalTo(category)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries.map((entry) {
        final product = Map<String, dynamic>.from(entry.value);
        product['id'] = entry.key;
        if (product['price'] != null) {
          product['price'] = (product['price'] as num).toDouble();
        }
        return product;
      }).toList();
    });
  }

  static Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final snapshot = await _ref.child('products').get();
    if (!snapshot.exists) return [];

    final data = snapshot.value as Map<dynamic, dynamic>;
    final searchQuery = query.toLowerCase();

    return data.entries.map((entry) {
      final product = Map<String, dynamic>.from(entry.value);
      product['id'] = entry.key;
      if (product['price'] != null) {
        product['price'] = (product['price'] as num).toDouble();
      }
      return product;
    }).where((product) {
      final sku = (product['sku'] ?? '').toString().toLowerCase();
      final description =
          (product['description'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      final productType =
          (product['product_type'] ?? '').toString().toLowerCase();

      return sku.contains(searchQuery) ||
          description.contains(searchQuery) ||
          category.contains(searchQuery) ||
          productType.contains(searchQuery);
    }).toList();
  }

  // ============ CLIENTS ============
  static Stream<List<Map<String, dynamic>>> getClients() {
    if (userId == null) return Stream.value([]);

    return _ref
        .child('clients')
        .orderByChild('user_id')
        .equalTo(userId)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries.map((entry) {
        final client = Map<String, dynamic>.from(entry.value);
        client['id'] = entry.key;
        return client;
      }).toList()
        ..sort((a, b) => (a['company'] ?? '')
            .toString()
            .compareTo((b['company'] ?? '').toString()));
    });
  }

  static Future<String> addClient(Map<String, dynamic> clientData) async {
    if (userId == null) throw Exception('User not authenticated');

    // Check rate limiting for client creation
    final rateLimitResult = _rateLimiter.checkRateLimit(
      identifier: userId!,
      type: RateLimitType.quoteCreation, // Reuse quote creation rate limit for clients
    );

    if (!rateLimitResult.allowed) {
      AppLogger.warning(
        'Client creation rate limit exceeded for user: $userId',
        category: LogCategory.security,
        data: {
          'userId': userId,
          'blockedFor': rateLimitResult.blockedFor?.inMinutes,
          'remainingAttempts': rateLimitResult.remainingAttempts,
        },
      );

      throw Exception(rateLimitResult.message ?? 'Too many client creation attempts. Please wait before creating another client.');
    }

    clientData['user_id'] = userId;
    clientData['created_at'] = ServerValue.timestamp;
    clientData['updated_at'] = ServerValue.timestamp;

    final newRef = _ref.child('clients').push();
    await newRef.set(clientData);
    return newRef.key!;
  }

  static Future<void> updateClient(
      String clientId, Map<String, dynamic> data) async {
    data['updated_at'] = ServerValue.timestamp;
    await _ref.child('clients/$clientId').update(data);
  }

  static Future<void> deleteClient(String clientId) async {
    await _ref.child('clients/$clientId').remove();
  }

  static Future<Map<String, dynamic>?> getClient(String clientId) async {
    final snapshot = await _ref.child('clients/$clientId').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = clientId;
      return data;
    }
    return null;
  }

  // ============ CART ============
  static Stream<List<Map<String, dynamic>>> getCartItems() {
    if (userId == null) return Stream.value([]);

    return _ref
        .child('cart_items')
        .orderByChild('user_id')
        .equalTo(userId)
        .onValue
        .asyncMap((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final items = <Map<String, dynamic>>[];
      for (var entry in data.entries) {
        final item = Map<String, dynamic>.from(entry.value);
        item['id'] = entry.key;

        // Fetch product details
        if (item['product_id'] != null) {
          final product = await getProduct(item['product_id']);
          item['product'] = product;
        }

        items.add(item);
      }

      return items;
    });
  }

  static Future<void> addToCart({
    required String productId,
    required String? clientId,
    int quantity = 1,
  }) async {
    if (userId == null) throw Exception('User not authenticated');
    if (clientId == null) throw Exception('Client not selected');

    // Check if item already exists
    final existingSnapshot = await _ref
        .child('cart_items')
        .orderByChild('user_id')
        .equalTo(userId)
        .once();

    final data = existingSnapshot.snapshot.value as Map<dynamic, dynamic>?;
    String? existingKey;
    Map<String, dynamic>? existingItem;

    if (data != null) {
      for (var entry in data.entries) {
        final item = Map<String, dynamic>.from(entry.value);
        if (item['product_id'] == productId && item['client_id'] == clientId) {
          existingKey = entry.key;
          existingItem = item;
          break;
        }
      }
    }

    if (existingKey != null && existingItem != null) {
      // Update quantity
      await _ref.child('cart_items/$existingKey').update({
        'quantity': (existingItem['quantity'] ?? 0) + quantity,
        'updated_at': ServerValue.timestamp,
      });
    } else {
      // Add new item
      await _ref.child('cart_items').push().set({
        'user_id': userId,
        'product_id': productId,
        'client_id': clientId,
        'quantity': quantity,
        'created_at': ServerValue.timestamp,
        'updated_at': ServerValue.timestamp,
      });
    }
  }

  static Future<void> updateCartItemQuantity(
      String cartItemId, int quantity) async {
    if (quantity <= 0) {
      await _ref.child('cart_items/$cartItemId').remove();
    } else {
      await _ref.child('cart_items/$cartItemId').update({
        'quantity': quantity,
        'updated_at': ServerValue.timestamp,
      });
    }
  }

  static Future<void> removeFromCart(String cartItemId) async {
    await _ref.child('cart_items/$cartItemId').remove();
  }

  static Future<void> clearCart() async {
    if (userId == null) return;

    final snapshot = await _ref
        .child('cart_items')
        .orderByChild('user_id')
        .equalTo(userId)
        .once();

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (data != null) {
      for (var key in data.keys) {
        await _ref.child('cart_items/$key').remove();
      }
    }
  }

  // ============ QUOTES ============
  static Stream<List<Map<String, dynamic>>> getQuotes() {
    if (userId == null) return Stream.value([]);

    return _ref
        .child('quotes')
        .orderByChild('user_id')
        .equalTo(userId)
        .onValue
        .asyncMap((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final quotes = <Map<String, dynamic>>[];
      for (var entry in data.entries) {
        final quote = Map<String, dynamic>.from(entry.value);
        quote['id'] = entry.key;

        // Fetch client details
        if (quote['client_id'] != null) {
          final clientSnapshot =
              await _ref.child('clients/${quote['client_id']}').get();
          if (clientSnapshot.exists) {
            quote['client'] =
                Map<String, dynamic>.from(clientSnapshot.value as Map);
            quote['client']['id'] = quote['client_id'];
          }
        }

        // Fetch quote items
        final itemsSnapshot = await _ref
            .child('quote_items')
            .orderByChild('quote_id')
            .equalTo(entry.key)
            .once();

        final itemsData =
            itemsSnapshot.snapshot.value as Map<dynamic, dynamic>?;
        if (itemsData != null) {
          final items = await Future.wait(
            itemsData.entries.map((itemEntry) async {
              final item = Map<String, dynamic>.from(itemEntry.value);
              item['id'] = itemEntry.key;

              // Fetch product details for each item
              if (item['product_id'] != null) {
                final product = await getProduct(item['product_id']);
                item['product'] = product;
              }

              return item;
            }),
          );
          quote['items'] = items;
        } else {
          quote['items'] = [];
        }

        quotes.add(quote);
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

  static Future<String> createQuote({
    required String clientId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double taxRate,
    required double taxAmount,
    required double totalAmount,
    double? shipping,
    String? notes,
  }) async {
    if (userId == null) throw Exception('User not authenticated');

    // Check rate limiting for quote creation
    final rateLimitResult = _rateLimiter.checkRateLimit(
      identifier: userId!,
      type: RateLimitType.quoteCreation,
    );

    if (!rateLimitResult.allowed) {
      AppLogger.warning(
        'Quote creation rate limit exceeded for user: $userId',
        category: LogCategory.security,
        data: {
          'userId': userId,
          'blockedFor': rateLimitResult.blockedFor?.inMinutes,
          'remainingAttempts': rateLimitResult.remainingAttempts,
        },
      );

      throw Exception(rateLimitResult.message ?? 'Too many quote creation attempts. Please wait before creating another quote.');
    }

    final quoteNumber = 'Q${DateTime.now().millisecondsSinceEpoch}';

    // Create quote
    final quoteRef = _ref.child('quotes').push();
    await quoteRef.set({
      'user_id': userId,
      'client_id': clientId,
      'quote_number': quoteNumber,
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'shipping': shipping ?? 0,
      'total_amount': totalAmount,
      'notes': notes,
      'status': 'draft',
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });

    // Add quote items
    for (var item in items) {
      await _ref.child('quote_items').push().set({
        'quote_id': quoteRef.key,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'total_price': item['total_price'],
        'created_at': ServerValue.timestamp,
      });
    }

    return quoteRef.key!;
  }

  static Future<void> updateQuote(
      String quoteId, Map<String, dynamic> data) async {
    data['updated_at'] = ServerValue.timestamp;
    await _ref.child('quotes/$quoteId').update(data);
  }

  static Future<void> deleteQuote(String quoteId) async {
    // Delete quote items first
    final itemsSnapshot = await _ref
        .child('quote_items')
        .orderByChild('quote_id')
        .equalTo(quoteId)
        .once();

    final itemsData = itemsSnapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (itemsData != null) {
      for (var key in itemsData.keys) {
        await _ref.child('quote_items/$key').remove();
      }
    }

    // Delete quote
    await _ref.child('quotes/$quoteId').remove();
  }

  static Future<void> updateQuoteStatus(String quoteId, String status) async {
    await _ref.child('quotes/$quoteId').update({
      'status': status,
      'updated_at': ServerValue.timestamp,
    });
  }

  // ============ SEARCH HISTORY ============
  static Future<void> addSearchHistory(String query) async {
    if (userId == null) return;

    await _ref.child('search_history').push().set({
      'user_id': userId,
      'query': query,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<List<String>> getRecentSearches() {
    if (userId == null) return Stream.value([]);

    return _ref
        .child('search_history')
        .orderByChild('user_id')
        .equalTo(userId)
        .limitToLast(10)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final searches = data.entries
          .map((e) => Map<String, dynamic>.from(e.value))
          .toList()
        ..sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      return searches.map((s) => s['query'] as String).toSet().take(5).toList();
    });
  }

  static Future<void> clearSearchHistory() async {
    if (userId == null) return;

    final snapshot = await _ref
        .child('search_history')
        .orderByChild('user_id')
        .equalTo(userId)
        .once();

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (data != null) {
      for (var key in data.keys) {
        await _ref.child('search_history/$key').remove();
      }
    }
  }

  // ============ USER PROFILE ============
  static Future<void> updateUserProfile(
      Map<String, dynamic> profileData) async {
    if (userId == null) return;

    profileData['updated_at'] = ServerValue.timestamp;
    await _ref.child('user_profiles/$userId').update(profileData);
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (userId == null) return null;

    final snapshot = await _ref.child('user_profiles/$userId').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  static Future<void> createUserProfile(
      Map<String, dynamic> profileData) async {
    if (userId == null) return;

    profileData['created_at'] = ServerValue.timestamp;
    profileData['updated_at'] = ServerValue.timestamp;
    await _ref.child('user_profiles/$userId').set(profileData);
  }

  // ============ APP SETTINGS ============
  static Future<Map<String, dynamic>> getAppSettings() async {
    final snapshot = await _ref.child('app_settings').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {
      'tax_rate': 0.08,
      'currency': 'USD',
      'site_name': 'TurboAir Quote System',
    };
  }

  static Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    settings['updated_at'] = ServerValue.timestamp;
    await _ref.child('app_settings').update(settings);
  }

  // ============ ANALYTICS ============
  static Future<void> logEvent(
      String eventName, Map<String, dynamic>? parameters) async {
    if (userId == null) return;

    await _ref.child('analytics_events').push().set({
      'user_id': userId,
      'event_name': eventName,
      'parameters': parameters,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Future<Map<String, dynamic>> getDashboardStats() async {
    if (userId == null) return {};

    // Get counts for dashboard
    final clientsSnapshot = await _ref
        .child('clients')
        .orderByChild('user_id')
        .equalTo(userId)
        .once();

    final quotesSnapshot = await _ref
        .child('quotes')
        .orderByChild('user_id')
        .equalTo(userId)
        .once();

    final clientsCount = (clientsSnapshot.snapshot.value as Map?)?.length ?? 0;
    final quotesCount = (quotesSnapshot.snapshot.value as Map?)?.length ?? 0;

    // Calculate total value of quotes
    double totalQuotesValue = 0.0;
    if (quotesSnapshot.snapshot.value != null) {
      final quotes = quotesSnapshot.snapshot.value as Map;
      for (var quote in quotes.values) {
        totalQuotesValue += (quote['total_amount'] ?? 0.0);
      }
    }

    return {
      'total_clients': clientsCount,
      'total_quotes': quotesCount,
      'total_quotes_value': totalQuotesValue,
      'total_products':
          (await _ref.child('products').once()).snapshot.children.length,
    };
  }

  // ============ UTILITY METHODS ============
  static String generateId() {
    return _ref.push().key!;
  }

  static Future<bool> checkConnection() async {
    try {
      final snapshot = await _ref.child('.info/connected').get();
      return snapshot.value as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  static void goOnline() {
    _database.goOnline();
  }

  static void goOffline() {
    _database.goOffline();
  }
}
