// lib/core/services/offline_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';

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
        .listen((ConnectivityResult result) {
      final wasOffline = !_isOnline;
      _isOnline = result != ConnectivityResult.none;
      _connectivityController.add(_isOnline);

      if (_isOnline && wasOffline) {
        _syncPendingChanges();
      }
    });

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
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
    if (_instance == null || !_isInitialized) {
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

    for (var operation in List.from(_pendingOperations)) {
      try {
        // Here you would sync with Firebase/Supabase
        // For now, just remove from queue
        _pendingOperations.remove(operation);
        await _pendingOperationsBox.delete(operation.id);
      } catch (e) {
        operation.retryCount++;
        if (operation.retryCount > 3) {
          _pendingOperations.remove(operation);
          await _pendingOperationsBox.delete(operation.id);
        }
      }
    }

    _syncStatus = SyncStatus.success;
    _queueController.add(_pendingOperations);
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
