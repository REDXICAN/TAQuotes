// lib/core/services/offline_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'app_logger.dart';

enum SyncStatus { idle, syncing, success, error }

enum OperationType { create, update, delete }

class PendingOperation {
  final String id;
  final String collection;
  final OperationType operation;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retryCount;

  PendingOperation({
    required this.id,
    required this.collection,
    required this.operation,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection': collection,
      'operation': operation.toString(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory PendingOperation.fromMap(Map<String, dynamic> map) {
    return PendingOperation(
      id: map['id'],
      collection: map['collection'],
      operation: OperationType.values.firstWhere(
        (e) => e.toString() == map['operation'],
      ),
      data: Map<String, dynamic>.from(map['data']),
      timestamp: DateTime.parse(map['timestamp']),
      retryCount: map['retryCount'] ?? 0,
    );
  }
}

class OfflineService {
  static final OfflineService? _instance = kIsWeb ? null : OfflineService._internal();
  factory OfflineService() => _instance ?? OfflineService._internal();
  OfflineService._internal();

  late Box<dynamic> _cacheBox;
  late Box<dynamic> _productsBox;
  late Box<dynamic> _clientsBox;
  late Box<dynamic> _quotesBox;
  late Box<dynamic> _cartBox;
  late Box<dynamic> _pendingOperationsBox;

  final _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  bool _isOnline = true;

  final List<PendingOperation> _pendingOperations = [];
  final _queueController = StreamController<List<PendingOperation>>.broadcast();

  Stream<bool> get connectionStream => _connectivityController.stream;
  Stream<List<PendingOperation>> get queueStream => _queueController.stream;
  List<PendingOperation> get pendingOperations => _pendingOperations;

  bool get isOnline => _isOnline;

  // Static accessors for singleton instance
  static Stream<bool> get staticConnectionStream => 
      kIsWeb ? Stream.value(true) : _instance!.connectionStream;
  static Stream<List<PendingOperation>> get staticQueueStream => 
      kIsWeb ? Stream.value([]) : _instance!.queueStream;
  static List<PendingOperation> get staticPendingOperations => 
      kIsWeb ? [] : _instance!.pendingOperations;
  static bool get staticIsOnline => 
      kIsWeb ? true : _instance!.isOnline;
  
  // Check if service is initialized
  static bool get isInitialized => kIsWeb || _instance != null;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;

  Future<void> initialize() async {
    _cacheBox = await Hive.openBox('cache');
    _productsBox = await Hive.openBox('products');
    _clientsBox = await Hive.openBox('clients');
    _quotesBox = await Hive.openBox('quotes');
    _cartBox = await Hive.openBox('cart');
    _pendingOperationsBox = await Hive.openBox('pendingOperations');

    // Load pending operations
    await _loadPendingOperations();

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final wasOffline = !_isOnline;
      _isOnline = result != ConnectivityResult.none;
      _connectivityController.add(_isOnline);

      if (_isOnline && wasOffline) {
        _syncPendingChanges();
      }
    });

    // Check initial connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final connectivityResult = connectivityResults.isNotEmpty ? connectivityResults.first : ConnectivityResult.none;
    _isOnline = connectivityResult != ConnectivityResult.none;
  }

  static Future<void> staticInitialize() async {
    if (kIsWeb) return; // Skip on web
    await _instance!.initialize();
  }

  Future<void> _loadPendingOperations() async {
    final operations = _pendingOperationsBox.values.toList();
    _pendingOperations.clear();
    for (var op in operations) {
      _pendingOperations
          .add(PendingOperation.fromMap(Map<String, dynamic>.from(op)));
    }
    _queueController.add(_pendingOperations);
  }

  // Products
  Future<void> saveProduct(Product product) async {
    await _productsBox.put(product.id, product.toMap());
  }

  List<Product> getProducts() {
    return _productsBox.keys.map((key) {
      final data = _productsBox.get(key);
      return Product.fromMap(Map<String, dynamic>.from(data));
    }).toList();
  }

  // Clients
  Future<void> saveClient(Client client) async {
    await _clientsBox.put(client.id, client.toMap());
  }

  List<Client> getClients() {
    return _clientsBox.keys.map((key) {
      final data = _clientsBox.get(key);
      return Client.fromMap(Map<String, dynamic>.from(data));
    }).toList();
  }

  // Quotes
  Future<void> saveQuote(Quote quote) async {
    await _quotesBox.put(quote.id, quote.toMap());
  }

  List<Quote> getQuotes() {
    return _quotesBox.keys.map((key) {
      final data = _quotesBox.get(key);
      return Quote.fromMap(Map<String, dynamic>.from(data));
    }).toList();
  }

  // Cart
  Future<void> saveCart(List<CartItem> items) async {
    await _cartBox.clear();
    for (var item in items) {
      await _cartBox.put(item.productId, item.toMap());
    }
  }

  List<CartItem> getCart() {
    return _cartBox.keys.map((key) {
      final data = _cartBox.get(key);
      return CartItem.fromMap(Map<String, dynamic>.from(data));
    }).toList();
  }

  // Static method to get cart
  static List<CartItem> getStaticCart() {
    if (_instance == null || !isInitialized) {
      return [];
    }
    try {
      return _instance!.getCart();
    } catch (e) {
      return [];
    }
  }

  // Sync methods
  static Future<void> syncPendingChanges() async {
    if (kIsWeb) return; // Skip on web
    await _instance!._syncPendingChanges();
  }

  Future<void> _syncPendingChanges() async {
    if (!_isOnline || _pendingOperations.isEmpty) return;

    _syncStatus = SyncStatus.syncing;
    final database = FirebaseDatabase.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _syncStatus = SyncStatus.error;
      return;
    }

    for (var operation in List.from(_pendingOperations)) {
      try {
        // Sync operation with Firebase based on operation type
        bool success = false;

        switch (operation.collection) {
          case 'clients':
            success = await _syncClientOperation(database, user.uid, operation);
            break;
          case 'quotes':
            success = await _syncQuoteOperation(database, user.uid, operation);
            break;
          case 'cart_items':
            success = await _syncCartOperation(database, user.uid, operation);
            break;
          case 'products':
            // Products are typically read-only for most users
            // Only sync if user is admin
            if (user.email == 'andres@turboairmexico.com' ||
                user.email == 'admin@turboairinc.com') {
              success = await _syncProductOperation(database, operation);
            } else {
              success = true; // Skip for non-admin users
            }
            break;
          default:
            // Unknown collection, log and skip
            AppLogger.warning('Unknown collection for sync: ${operation.collection}', category: LogCategory.sync);
            success = true; // Mark as success to remove from queue
        }

        if (success) {
          _pendingOperations.remove(operation);
          await _pendingOperationsBox.delete(operation.id);
        } else {
          throw Exception('Sync failed for operation ${operation.id}');
        }
      } catch (e) {
        operation.retryCount++;
        if (operation.retryCount > 3) {
          // Max retries reached, remove from queue
          AppLogger.error('Max retries reached for operation ${operation.id}', error: e, category: LogCategory.sync);
          _pendingOperations.remove(operation);
          await _pendingOperationsBox.delete(operation.id);
        } else {
          // Update retry count in storage
          await _pendingOperationsBox.put(operation.id, operation.toMap());
        }
      }
    }

    _syncStatus = _pendingOperations.isEmpty ? SyncStatus.success : SyncStatus.error;
    _queueController.add(_pendingOperations);
  }

  Future<bool> _syncClientOperation(FirebaseDatabase database, String userId, PendingOperation operation) async {
    final ref = database.ref('clients/$userId/${operation.data['id'] ?? database.ref().push().key}');

    switch (operation.operation) {
      case OperationType.create:
      case OperationType.update:
        await ref.set(operation.data);
        return true;
      case OperationType.delete:
        await ref.remove();
        return true;
    }
  }

  Future<bool> _syncQuoteOperation(FirebaseDatabase database, String userId, PendingOperation operation) async {
    final ref = database.ref('quotes/$userId/${operation.data['id'] ?? database.ref().push().key}');

    switch (operation.operation) {
      case OperationType.create:
      case OperationType.update:
        await ref.set(operation.data);
        return true;
      case OperationType.delete:
        await ref.remove();
        return true;
    }
  }

  Future<bool> _syncCartOperation(FirebaseDatabase database, String userId, PendingOperation operation) async {
    final ref = database.ref('cart_items/$userId/${operation.data['id'] ?? database.ref().push().key}');

    switch (operation.operation) {
      case OperationType.create:
      case OperationType.update:
        await ref.set(operation.data);
        return true;
      case OperationType.delete:
        await ref.remove();
        return true;
    }
  }

  Future<bool> _syncProductOperation(FirebaseDatabase database, PendingOperation operation) async {
    final ref = database.ref('products/${operation.data['id'] ?? database.ref().push().key}');

    switch (operation.operation) {
      case OperationType.create:
      case OperationType.update:
        await ref.set(operation.data);
        return true;
      case OperationType.delete:
        await ref.remove();
        return true;
    }
  }

  Future<void> syncWithFirebase() async {
    // Sync implementation
    await _syncPendingChanges();
  }

  static Future<void> staticSyncWithFirebase() async {
    if (kIsWeb) return; // Skip on web
    await _instance!.syncWithFirebase();
  }

  // Cache methods expected by main.dart
  static void cacheProducts(List products) {
    // Implementation will be handled by the main cache system
  }
  
  static void cacheClients(List clients) {
    // Implementation will be handled by the main cache system
  }
  
  static void cacheQuotes(List quotes) {
    // Implementation will be handled by the main cache system  
  }
  
  static void cacheCartItems(List cartItems) {
    // Implementation will be handled by the main cache system
  }

  Future<bool> hasOfflineData() async {
    return _pendingOperations.isNotEmpty;
  }

  Future<int> getSyncQueueCount() async {
    return _pendingOperations.length;
  }

  static Future<bool> staticHasOfflineData() async {
    if (kIsWeb) return false; // No offline data on web
    return await _instance!.hasOfflineData();
  }

  static Future<int> staticGetSyncQueueCount() async {
    if (kIsWeb) return 0; // No sync queue on web
    return await _instance!.getSyncQueueCount();
  }

  static Future<Map<String, dynamic>> getCacheInfo() async {
    if (kIsWeb) return {}; // No cache info on web
    return await _instance!._getCacheInfo();
  }

  Future<Map<String, dynamic>> _getCacheInfo() async {
    return {
      'products': _productsBox.length,
      'clients': _clientsBox.length,
      'quotes': _quotesBox.length,
      'cart': _cartBox.length,
      'pending': _pendingOperations.length,
      'is_online': _isOnline,
      'pending_operations': _pendingOperations.length,
      'last_sync': 'Recently', // You can add actual timestamp tracking
      'last_cache_cleanup': 'Recently',
      'active_cache_duration_days': 7,
      'reference_cache_duration_days': 30,
    };
  }

  Future<void> clearAll() async {
    await _cacheBox.clear();
    await _productsBox.clear();
    await _clientsBox.clear();
    await _quotesBox.clear();
    await _cartBox.clear();
    _pendingOperations.clear();
    _queueController.add(_pendingOperations);
  }

  // Helper methods for queuing operations when offline
  Future<void> queueOperation({
    required String collection,
    required OperationType operation,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    final operationId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final pendingOp = PendingOperation(
      id: operationId,
      collection: collection,
      operation: operation,
      data: data,
      timestamp: DateTime.now(),
    );

    _pendingOperations.add(pendingOp);
    await _pendingOperationsBox.put(operationId, pendingOp.toMap());
    _queueController.add(_pendingOperations);

    // Try to sync immediately if online
    if (_isOnline) {
      _syncPendingChanges();
    }
  }

  // Static helper methods for external access
  static Future<void> queueClientOperation({
    required OperationType operation,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (kIsWeb || _instance == null) return;
    await _instance!.queueOperation(
      collection: 'clients',
      operation: operation,
      data: data,
      id: id,
    );
  }

  static Future<void> queueQuoteOperation({
    required OperationType operation,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (kIsWeb || _instance == null) return;
    await _instance!.queueOperation(
      collection: 'quotes',
      operation: operation,
      data: data,
      id: id,
    );
  }

  static Future<void> queueCartOperation({
    required OperationType operation,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (kIsWeb || _instance == null) return;
    await _instance!.queueOperation(
      collection: 'cart_items',
      operation: operation,
      data: data,
      id: id,
    );
  }

  static Future<void> queueProductOperation({
    required OperationType operation,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (kIsWeb || _instance == null) return;
    await _instance!.queueOperation(
      collection: 'products',
      operation: operation,
      data: data,
      id: id,
    );
  }

  // Method to manually trigger sync
  static Future<void> manualSync() async {
    if (kIsWeb || _instance == null) return;
    await _instance!._syncPendingChanges();
  }

  // Method to clear specific pending operation
  Future<void> removePendingOperation(String operationId) async {
    _pendingOperations.removeWhere((op) => op.id == operationId);
    await _pendingOperationsBox.delete(operationId);
    _queueController.add(_pendingOperations);
  }

  // Method to get pending operations by collection
  List<PendingOperation> getPendingOperationsByCollection(String collection) {
    return _pendingOperations.where((op) => op.collection == collection).toList();
  }

  // Static method to get pending operations by collection
  static List<PendingOperation> staticGetPendingOperationsByCollection(String collection) {
    if (kIsWeb || _instance == null) return [];
    return _instance!.getPendingOperationsByCollection(collection);
  }

  Future<void> dispose() async {
    await _connectivityController.close();
    await _queueController.close();
    await _cacheBox.close();
    await _productsBox.close();
    await _clientsBox.close();
    await _quotesBox.close();
    await _cartBox.close();
  }
}
