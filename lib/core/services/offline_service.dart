// lib/core/services/offline_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  static OfflineService? _instance;
  static bool _isInitialized = false;
  static bool _initializationFailed = false;

  factory OfflineService() {
    if (kIsWeb) {
      throw UnsupportedError('OfflineService is not supported on web platform');
    }
    return _instance ??= OfflineService._internal();
  }

  OfflineService._internal();

  Box<dynamic>? _cacheBox;
  Box<dynamic>? _productsBox;
  Box<dynamic>? _clientsBox;
  Box<dynamic>? _quotesBox;
  Box<dynamic>? _cartBox;
  Box<dynamic>? _pendingOperationsBox;

  final _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  bool _isOnline = true;

  final List<PendingOperation> _pendingOperations = [];
  final _queueController = StreamController<List<PendingOperation>>.broadcast();

  Stream<bool> get connectionStream => _connectivityController.stream;
  Stream<List<PendingOperation>> get queueStream => _queueController.stream;
  List<PendingOperation> get pendingOperations => _pendingOperations;

  bool get isOnline => _isOnline;

  // Safe static accessors for singleton instance
  static Stream<bool> get staticConnectionStream {
    if (kIsWeb) return Stream.value(true);
    if (_instance == null || !_isInitialized) return Stream.value(true);
    try {
      return _instance!.connectionStream;
    } catch (e) {
      return Stream.value(true); // Fallback to online
    }
  }

  static Stream<List<PendingOperation>> get staticQueueStream {
    if (kIsWeb) return Stream.value([]);
    if (_instance == null || !_isInitialized) return Stream.value([]);
    try {
      return _instance!.queueStream;
    } catch (e) {
      return Stream.value([]);
    }
  }

  static List<PendingOperation> get staticPendingOperations {
    if (kIsWeb) return [];
    if (_instance == null || !_isInitialized) return [];
    try {
      return _instance!.pendingOperations;
    } catch (e) {
      return [];
    }
  }

  static bool get staticIsOnline {
    if (kIsWeb) return true;
    if (_instance == null || !_isInitialized) return true;
    try {
      return _instance!.isOnline;
    } catch (e) {
      return true; // Fallback to online
    }
  }

  // Check if service is properly initialized
  static bool get isInitialized => kIsWeb || (_instance != null && _isInitialized && !_initializationFailed);
  static bool get initializationFailed => !kIsWeb && _initializationFailed;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
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

      _isInitialized = true;
      _initializationFailed = false;
    } catch (e) {
      _initializationFailed = true;
      _isInitialized = false;
      rethrow;
    }
  }

  static Future<void> staticInitialize() async {
    if (kIsWeb) return; // Skip on web

    try {
      final instance = OfflineService();
      await instance.initialize();
    } catch (e) {
      // Log error but don't crash the app
      AppLogger.error('OfflineService initialization failed', error: e);
    }
  }

  Future<void> _loadPendingOperations() async {
    if (_pendingOperationsBox == null) return;

    try {
      final operations = _pendingOperationsBox!.values.toList();
      _pendingOperations.clear();
      for (var op in operations) {
        _pendingOperations
            .add(PendingOperation.fromMap(Map<String, dynamic>.from(op)));
      }
      _queueController.add(_pendingOperations);
    } catch (e) {
      AppLogger.error('Failed to load pending operations', error: e);
    }
  }

  // Products
  Future<void> saveProduct(Product product) async {
    if (_productsBox == null) return;

    try {
      await _productsBox!.put(product.id, product.toMap());
    } catch (e) {
      AppLogger.error('Failed to save product', error: e);
    }
  }

  List<Product> getProducts() {
    if (_productsBox == null) return [];

    try {
      return _productsBox!.keys.map((key) {
        final data = _productsBox!.get(key);
        return Product.fromMap(Map<String, dynamic>.from(data));
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get products', error: e);
      return [];
    }
  }

  // Clients
  Future<void> saveClient(Client client) async {
    if (_clientsBox == null) return;

    try {
      await _clientsBox!.put(client.id, client.toMap());
    } catch (e) {
      AppLogger.error('Failed to save client', error: e);
    }
  }

  List<Client> getClients() {
    if (_clientsBox == null) return [];

    try {
      return _clientsBox!.keys.map((key) {
        final data = _clientsBox!.get(key);
        return Client.fromMap(Map<String, dynamic>.from(data));
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get clients', error: e);
      return [];
    }
  }

  // Quotes
  Future<void> saveQuote(Quote quote) async {
    if (_quotesBox == null) return;

    try {
      await _quotesBox!.put(quote.id, quote.toMap());
    } catch (e) {
      AppLogger.error('Failed to save quote', error: e);
    }
  }

  List<Quote> getQuotes() {
    if (_quotesBox == null) return [];

    try {
      return _quotesBox!.keys.map((key) {
        final data = _quotesBox!.get(key);
        return Quote.fromMap(Map<String, dynamic>.from(data));
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get quotes', error: e);
      return [];
    }
  }

  // Cart
  Future<void> saveCart(List<CartItem> items) async {
    if (_cartBox == null) return;

    try {
      await _cartBox!.clear();
      for (var item in items) {
        await _cartBox!.put(item.productId, item.toMap());
      }
    } catch (e) {
      AppLogger.error('Failed to save cart', error: e);
    }
  }

  List<CartItem> getCart() {
    if (_cartBox == null) return [];

    try {
      return _cartBox!.keys.map((key) {
        final data = _cartBox!.get(key);
        return CartItem.fromMap(Map<String, dynamic>.from(data));
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get cart', error: e);
      return [];
    }
  }

  // Static method to get cart
  static List<CartItem> getStaticCart() {
    if (kIsWeb || _instance == null || !isInitialized || _initializationFailed) {
      return [];
    }
    try {
      return _instance!.getCart();
    } catch (e) {
      AppLogger.error('Failed to get static cart', error: e);
      return [];
    }
  }

  // Sync methods
  static Future<void> syncPendingChanges() async {
    if (kIsWeb || _instance == null || !isInitialized || _initializationFailed) return;

    try {
      await _instance!._syncPendingChanges();
    } catch (e) {
      AppLogger.error('Failed to sync pending changes', error: e);
    }
  }

  Future<void> _syncPendingChanges() async {
    if (!_isOnline || _pendingOperations.isEmpty) return;

    _syncStatus = SyncStatus.syncing;

    for (var operation in List.from(_pendingOperations)) {
      try {
        // Here you would sync with Firebase/Supabase
        // For now, just remove from queue
        _pendingOperations.remove(operation);
        await _pendingOperationsBox?.delete(operation.id);
      } catch (e) {
        operation.retryCount++;
        if (operation.retryCount > 3) {
          _pendingOperations.remove(operation);
          await _pendingOperationsBox?.delete(operation.id);
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
    if (kIsWeb || _instance == null || !isInitialized || _initializationFailed) return;

    try {
      await _instance!.syncWithFirebase();
    } catch (e) {
      AppLogger.error('Failed to sync with Firebase', error: e);
    }
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
    try {
      return _pendingOperations.isNotEmpty;
    } catch (e) {
      AppLogger.error('Failed to check offline data', error: e);
      return false;
    }
  }

  Future<int> getSyncQueueCount() async {
    try {
      return _pendingOperations.length;
    } catch (e) {
      AppLogger.error('Failed to get sync queue count', error: e);
      return 0;
    }
  }

  static Future<bool> staticHasOfflineData() async {
    if (kIsWeb || _instance == null || !isInitialized || _initializationFailed) return false;

    try {
      return await _instance!.hasOfflineData();
    } catch (e) {
      AppLogger.error('Failed to get static offline data status', error: e);
      return false;
    }
  }

  static Future<int> staticGetSyncQueueCount() async {
    if (kIsWeb || _instance == null || !isInitialized || _initializationFailed) return 0;

    try {
      return await _instance!.getSyncQueueCount();
    } catch (e) {
      AppLogger.error('Failed to get static sync queue count', error: e);
      return 0;
    }
  }

  static Future<Map<String, dynamic>> getCacheInfo() async {
    if (kIsWeb || _instance == null || !isInitialized || _initializationFailed) {
      return {
        'products': 0,
        'clients': 0,
        'quotes': 0,
        'cart': 0,
        'pending': 0,
        'is_online': true,
        'pending_operations': 0,
        'last_sync': 'Never',
        'last_cache_cleanup': 'Never',
        'active_cache_duration_days': 0,
        'reference_cache_duration_days': 0,
        'status': 'Offline service not available',
      };
    }

    try {
      return await _instance!._getCacheInfo();
    } catch (e) {
      AppLogger.error('Failed to get cache info', error: e);
      return {
        'error': 'Failed to get cache info',
        'status': 'Error',
      };
    }
  }

  Future<Map<String, dynamic>> _getCacheInfo() async {
    try {
      return {
        'products': _productsBox?.length ?? 0,
        'clients': _clientsBox?.length ?? 0,
        'quotes': _quotesBox?.length ?? 0,
        'cart': _cartBox?.length ?? 0,
        'pending': _pendingOperations.length,
        'is_online': _isOnline,
        'pending_operations': _pendingOperations.length,
        'last_sync': 'Recently', // You can add actual timestamp tracking
        'last_cache_cleanup': 'Recently',
        'active_cache_duration_days': 7,
        'reference_cache_duration_days': 30,
        'status': 'Initialized',
      };
    } catch (e) {
      return {
        'error': 'Failed to get cache info',
        'status': 'Error',
      };
    }
  }

  // Remove a pending operation by ID
  Future<void> removePendingOperation(String operationId) async {
    if (_pendingOperationsBox == null) return;

    try {
      _pendingOperations.removeWhere((op) => op.id == operationId);
      await _pendingOperationsBox!.delete(operationId);
      _queueController.add(_pendingOperations);
    } catch (e) {
      AppLogger.error('Failed to remove pending operation', error: e);
    }
  }

  Future<void> clearAll() async {
    try {
      await _cacheBox?.clear();
      await _productsBox?.clear();
      await _clientsBox?.clear();
      await _quotesBox?.clear();
      await _cartBox?.clear();
      _pendingOperations.clear();
      _queueController.add(_pendingOperations);
    } catch (e) {
      AppLogger.error('Failed to clear all data', error: e);
    }
  }

  Future<void> dispose() async {
    try {
      await _connectivityController.close();
      await _queueController.close();
      await _cacheBox?.close();
      await _productsBox?.close();
      await _clientsBox?.close();
      await _quotesBox?.close();
      await _cartBox?.close();
      _isInitialized = false;
    } catch (e) {
      AppLogger.error('Error disposing OfflineService', error: e);
    }
  }
}
