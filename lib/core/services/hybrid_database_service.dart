// lib/core/services/hybrid_database_service.dart
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/env_config.dart';
import 'app_logger.dart';
import 'rate_limiter_service.dart';

/// Service that handles both Realtime Database (products) and Firestore (users)
class HybridDatabaseService {
  final rtdb.FirebaseDatabase _realtimeDb = rtdb.FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RateLimiterService _rateLimiter = RateLimiterService();

  String? get userId => _auth.currentUser?.uid;
  bool get isSuperAdmin => _auth.currentUser?.email == EnvConfig.adminEmail;

  // ============ PRODUCTS (Realtime Database) ============
  Stream<List<Map<String, dynamic>>> getProducts({String? category}) {
    rtdb.Query query = _realtimeDb.ref('products');
    
    return query.onValue.map((event) {
      final List<Map<String, dynamic>> products = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final product = Map<String, dynamic>.from(value);
          product['id'] = key;
          
          if (category == null || product['category'] == category) {
            products.add(product);
          }
        });
      }
      return products;
    });
  }

  Future<Map<String, dynamic>?> getProduct(String productId) async {
    final snapshot = await _realtimeDb.ref('products/$productId').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = productId;
      return data;
    }
    return null;
  }

  // ============ USERS (Firestore) ============
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String name,
    String role = 'distributor',
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': name,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(uid).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    if (!isSuperAdmin) {
      return const Stream.empty();
    }
    return _firestore.collection('users').snapshots();
  }

  // ============ CLIENTS (Realtime Database) ============
  Stream<List<Map<String, dynamic>>> getClients() {
    if (userId == null) return Stream.value([]);
    
    final path = isSuperAdmin ? 'clients' : 'clients/$userId';
    
    return _realtimeDb.ref(path).onValue.map((event) {
      final List<Map<String, dynamic>> clients = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        if (isSuperAdmin) {
          // For superadmin, iterate through all user clients
          data.forEach((userId, userClients) {
            if (userClients is Map) {
              Map<String, dynamic>.from(userClients).forEach((key, value) {
                final client = Map<String, dynamic>.from(value);
                client['id'] = key;
                client['userId'] = userId;
                clients.add(client);
              });
            }
          });
        } else {
          // For regular users, just their clients
          data.forEach((key, value) {
            final client = Map<String, dynamic>.from(value);
            client['id'] = key;
            clients.add(client);
          });
        }
      }
      return clients;
    });
  }

  Future<String> addClient(Map<String, dynamic> client) async {
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

    final newClientRef = _realtimeDb.ref('clients/$userId').push();
    await newClientRef.set({
      ...client,
      'created_at': rtdb.ServerValue.timestamp,
      'updated_at': rtdb.ServerValue.timestamp,
    });
    return newClientRef.key!;
  }

  // ============ CART (Realtime Database) ============
  Stream<List<Map<String, dynamic>>> getCartItems() {
    if (userId == null) return Stream.value([]);
    
    return _realtimeDb.ref('cart_items/$userId').onValue.map((event) {
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
    
    final cartRef = _realtimeDb.ref('cart_items/$userId');
    final snapshot = await cartRef.once();
    
    if (snapshot.snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      for (var entry in data.entries) {
        final item = Map<String, dynamic>.from(entry.value);
        if (item['product_id'] == productId) {
          // Update existing
          await cartRef.child(entry.key).update({
            'quantity': (item['quantity'] ?? 0) + quantity,
            'updated_at': rtdb.ServerValue.timestamp,
          });
          return;
        }
      }
    }
    
    // Add new item
    await cartRef.push().set({
      'product_id': productId,
      'quantity': quantity,
      'created_at': rtdb.ServerValue.timestamp,
      'updated_at': rtdb.ServerValue.timestamp,
    });
  }

  Future<void> clearCart() async {
    if (userId == null) return;
    await _realtimeDb.ref('cart_items/$userId').remove();
  }

  // ============ QUOTES (Realtime Database) ============
  Stream<List<Map<String, dynamic>>> getQuotes() {
    if (userId == null) return Stream.value([]);
    
    final path = isSuperAdmin ? 'quotes' : 'quotes/$userId';
    
    return _realtimeDb.ref(path).onValue.map((event) {
      final List<Map<String, dynamic>> quotes = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        if (isSuperAdmin) {
          // For superadmin, iterate through all user quotes
          data.forEach((userId, userQuotes) {
            if (userQuotes is Map) {
              Map<String, dynamic>.from(userQuotes).forEach((key, value) {
                final quote = Map<String, dynamic>.from(value);
                quote['id'] = key;
                quote['userId'] = userId;
                quotes.add(quote);
              });
            }
          });
        } else {
          // For regular users, just their quotes
          data.forEach((key, value) {
            final quote = Map<String, dynamic>.from(value);
            quote['id'] = key;
            quotes.add(quote);
          });
        }
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

  Future<String> createQuote({
    required String clientId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double taxRate,
    required double taxAmount,
    required double totalAmount,
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
    final newQuoteRef = _realtimeDb.ref('quotes/$userId').push();
    
    await newQuoteRef.set({
      'client_id': clientId,
      'quote_number': quoteNumber,
      'items': items,
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'status': 'draft',
      'created_at': rtdb.ServerValue.timestamp,
      'updated_at': rtdb.ServerValue.timestamp,
    });
    
    return newQuoteRef.key!;
  }

  // ============ ANALYTICS & ADMIN METHODS ============

  /// Get total number of products
  Future<int> getTotalProducts() async {
    try {
      final snapshot = await _realtimeDb.ref('products').get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data.length;
      }
      return 0;
    } catch (e) {
      AppLogger.error('Error getting total products', error: e);
      return 0;
    }
  }

  /// Get total number of clients (for superadmin: all clients, for users: their clients)
  Future<int> getTotalClients() async {
    try {
      final path = isSuperAdmin ? 'clients' : 'clients/$userId';
      final snapshot = await _realtimeDb.ref(path).get();

      if (!snapshot.exists || snapshot.value == null) return 0;

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      if (isSuperAdmin) {
        // Count all clients across all users
        int totalClients = 0;
        data.forEach((userId, userClients) {
          if (userClients is Map) {
            totalClients += Map<String, dynamic>.from(userClients).length;
          }
        });
        return totalClients;
      } else {
        // Count user's clients
        return data.length;
      }
    } catch (e) {
      AppLogger.error('Error getting total clients', error: e);
      return 0;
    }
  }

  /// Get total number of quotes (for superadmin: all quotes, for users: their quotes)
  Future<int> getTotalQuotes() async {
    try {
      final path = isSuperAdmin ? 'quotes' : 'quotes/$userId';
      final snapshot = await _realtimeDb.ref(path).get();

      if (!snapshot.exists || snapshot.value == null) return 0;

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      if (isSuperAdmin) {
        // Count all quotes across all users
        int totalQuotes = 0;
        data.forEach((userId, userQuotes) {
          if (userQuotes is Map) {
            totalQuotes += Map<String, dynamic>.from(userQuotes).length;
          }
        });
        return totalQuotes;
      } else {
        // Count user's quotes
        return data.length;
      }
    } catch (e) {
      AppLogger.error('Error getting total quotes', error: e);
      return 0;
    }
  }

  /// Get all users (Firestore) - returns List<Map<String, dynamic>>
  Future<List<Map<String, dynamic>>> getAllUsersOnce() async {
    try {
      if (!isSuperAdmin) return [];

      final querySnapshot = await _firestore.collection('users').get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      AppLogger.error('Error getting all users', error: e);
      return [];
    }
  }

  /// Approve user request (compatible with Realtime Database)
  Future<void> approveUserRequest({required String requestId, String? approvedBy, String? reason}) async {
    try {
      if (!isSuperAdmin) throw Exception('Only superadmin can approve user requests');

      // Get the request details first
      final snapshot = await _realtimeDb.ref('user_approval_requests/$requestId').get();
      if (!snapshot.exists) {
        throw Exception('User approval request not found');
      }

      final requestData = Map<String, dynamic>.from(snapshot.value as Map);
      final userId = requestData['userId'];
      final requestedRole = requestData['requestedRole'] ?? 'distributor';

      // Update the request status in Realtime Database
      await _realtimeDb.ref('user_approval_requests/$requestId').update({
        'status': 'approved',
        'processedBy': approvedBy ?? _auth.currentUser?.email ?? 'superadmin',
        'processedAt': DateTime.now().toIso8601String(),
        'reason': reason,
      });

      // Update user role if needed (implementation depends on your user management system)
      if (userId != null) {
        await _realtimeDb.ref('users/$userId').update({
          'role': requestedRole,
          'approved': true,
          'approvedAt': DateTime.now().toIso8601String(),
          'approvedBy': approvedBy ?? _auth.currentUser?.email ?? 'superadmin',
        });

        AppLogger.info('User approved and role updated', data: {
          'requestId': requestId,
          'userId': userId,
          'role': requestedRole,
          'approvedBy': approvedBy
        });
      }

      AppLogger.info('User request approved', data: {'requestId': requestId, 'reason': reason});
    } catch (e) {
      AppLogger.error('Error approving user request', error: e, data: {'requestId': requestId});
      rethrow;
    }
  }

  /// Get pending user approval requests (for UserApprovalsWidget compatibility)
  Stream<List<Map<String, dynamic>>> getPendingUserApprovals() {
    try {
      return _realtimeDb
          .ref('user_approval_requests')
          .orderByChild('status')
          .equalTo('pending')
          .onValue
          .map((event) {
        final List<Map<String, dynamic>> requests = [];
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          data.forEach((key, value) {
            final request = Map<String, dynamic>.from(value);
            request['id'] = key;
            requests.add(request);
          });
        }
        // Sort by request date, newest first
        requests.sort((a, b) {
          final dateA = _safeParseDateTime(a['requestedAt']);
          final dateB = _safeParseDateTime(b['requestedAt']);
          return dateB.compareTo(dateA);
        });
        AppLogger.info('Loaded pending user approvals', data: {'count': requests.length});
        return requests;
      }).handleError((error) {
        AppLogger.error('Error loading pending user approvals', error: error);
        return <Map<String, dynamic>>[];
      });
    } catch (e) {
      AppLogger.error('Error setting up pending user approvals stream', error: e);
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  /// Helper method to safely parse DateTime from various formats
  DateTime _safeParseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is int || dateValue is double) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue.toInt());
      } else {
        return DateTime.now();
      }
    } catch (e) {
      AppLogger.error('Error parsing date', error: e, data: {'dateValue': dateValue});
      return DateTime.now();
    }
  }

  /// Reject user request (compatible with Realtime Database)
  Future<void> rejectUserRequest({required String requestId, String? rejectedBy, String? reason}) async {
    try {
      if (!isSuperAdmin) throw Exception('Only superadmin can reject user requests');

      // Get the request details first
      final snapshot = await _realtimeDb.ref('user_approval_requests/$requestId').get();
      if (!snapshot.exists) {
        throw Exception('User approval request not found');
      }

      final requestData = Map<String, dynamic>.from(snapshot.value as Map);
      final userId = requestData['userId'];

      // Update the request status in Realtime Database
      await _realtimeDb.ref('user_approval_requests/$requestId').update({
        'status': 'rejected',
        'processedBy': rejectedBy ?? _auth.currentUser?.email ?? 'superadmin',
        'processedAt': DateTime.now().toIso8601String(),
        'rejectionReason': reason,
      });

      // Optionally update user status to mark as rejected
      if (userId != null) {
        await _realtimeDb.ref('users/$userId').update({
          'approved': false,
          'rejectedAt': DateTime.now().toIso8601String(),
          'rejectedBy': rejectedBy ?? _auth.currentUser?.email ?? 'superadmin',
          'rejectionReason': reason,
        });

        AppLogger.info('User rejected and status updated', data: {
          'requestId': requestId,
          'userId': userId,
          'rejectedBy': rejectedBy,
          'reason': reason
        });
      }

      AppLogger.info('User request rejected', data: {'requestId': requestId, 'reason': reason});
    } catch (e) {
      AppLogger.error('Error rejecting user request', error: e, data: {'requestId': requestId});
      rethrow;
    }
  }
}