// lib/core/services/offline_fallback_service.dart
import 'dart:async';
import '../models/models.dart';
import 'offline_service.dart';
import 'app_logger.dart';

/// Fallback service for when OfflineService is not available
/// Provides in-memory storage and graceful degradation
class OfflineFallbackService {
  static final OfflineFallbackService _instance = OfflineFallbackService._internal();
  factory OfflineFallbackService() => _instance;
  OfflineFallbackService._internal();

  // In-memory storage for fallback
  final List<Product> _products = [];
  final List<Client> _clients = [];
  final List<Quote> _quotes = [];
  final List<CartItem> _cartItems = [];
  final List<PendingOperation> _pendingOperations = [];

  bool _isOnline = true;
  final _connectivityController = StreamController<bool>.broadcast();
  final _queueController = StreamController<List<PendingOperation>>.broadcast();

  Stream<bool> get connectionStream => _connectivityController.stream;
  Stream<List<PendingOperation>> get queueStream => _queueController.stream;
  List<PendingOperation> get pendingOperations => _pendingOperations;
  bool get isOnline => _isOnline;

  /// Add a pending operation to the in-memory queue
  void addPendingOperation(String collection, OperationType operation, Map<String, dynamic> data) {
    final op = PendingOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      collection: collection,
      operation: operation,
      data: data,
      timestamp: DateTime.now(),
    );

    _pendingOperations.add(op);
    _queueController.add(_pendingOperations);
  }

  /// Save product to in-memory storage
  void saveProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _products[index] = product;
    } else {
      _products.add(product);
    }
  }

  /// Get products from in-memory storage
  List<Product> getProducts() => List.unmodifiable(_products);

  /// Save client to in-memory storage
  void saveClient(Client client) {
    final index = _clients.indexWhere((c) => c.id == client.id);
    if (index >= 0) {
      _clients[index] = client;
    } else {
      _clients.add(client);
    }
  }

  /// Get clients from in-memory storage
  List<Client> getClients() => List.unmodifiable(_clients);

  /// Save quote to in-memory storage
  void saveQuote(Quote quote) {
    final index = _quotes.indexWhere((q) => q.id == quote.id);
    if (index >= 0) {
      _quotes[index] = quote;
    } else {
      _quotes.add(quote);
    }
  }

  /// Get quotes from in-memory storage
  List<Quote> getQuotes() => List.unmodifiable(_quotes);

  /// Save cart items to in-memory storage
  void saveCart(List<CartItem> items) {
    _cartItems.clear();
    _cartItems.addAll(items);
  }

  /// Get cart items from in-memory storage
  List<CartItem> getCart() => List.unmodifiable(_cartItems);

  /// Check if there is offline data
  bool hasOfflineData() => _pendingOperations.isNotEmpty;

  /// Get sync queue count
  int getSyncQueueCount() => _pendingOperations.length;

  /// Get cache info
  Map<String, dynamic> getCacheInfo() {
    return {
      'products': _products.length,
      'clients': _clients.length,
      'quotes': _quotes.length,
      'cart': _cartItems.length,
      'pending': _pendingOperations.length,
      'is_online': _isOnline,
      'pending_operations': _pendingOperations.length,
      'last_sync': 'Fallback mode',
      'last_cache_cleanup': 'N/A',
      'active_cache_duration_days': 0,
      'reference_cache_duration_days': 0,
      'status': 'Fallback mode - in-memory only',
    };
  }

  /// Clear all data
  void clearAll() {
    _products.clear();
    _clients.clear();
    _quotes.clear();
    _cartItems.clear();
    _pendingOperations.clear();
    _queueController.add(_pendingOperations);
  }

  /// Remove a pending operation
  void removePendingOperation(String operationId) {
    _pendingOperations.removeWhere((op) => op.id == operationId);
    _queueController.add(_pendingOperations);
  }

  /// Dispose the service
  void dispose() {
    _connectivityController.close();
    _queueController.close();
  }

  /// Set online status (for testing)
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    _connectivityController.add(_isOnline);
  }
}

/// Unified service that automatically falls back to in-memory storage
/// when OfflineService is not available
class UnifiedOfflineService {
  static bool get isOfflineServiceAvailable =>
      OfflineService.isInitialized && !OfflineService.initializationFailed;

  static Stream<bool> get connectionStream {
    if (isOfflineServiceAvailable) {
      return OfflineService.staticConnectionStream;
    }
    return OfflineFallbackService().connectionStream;
  }

  static Stream<List<PendingOperation>> get queueStream {
    if (isOfflineServiceAvailable) {
      return OfflineService.staticQueueStream;
    }
    return OfflineFallbackService().queueStream;
  }

  static List<PendingOperation> get pendingOperations {
    if (isOfflineServiceAvailable) {
      return OfflineService.staticPendingOperations;
    }
    return OfflineFallbackService().pendingOperations;
  }

  static bool get isOnline {
    if (isOfflineServiceAvailable) {
      return OfflineService.staticIsOnline;
    }
    return OfflineFallbackService().isOnline;
  }

  static List<CartItem> getCart() {
    if (isOfflineServiceAvailable) {
      return OfflineService.getStaticCart();
    }
    return OfflineFallbackService().getCart();
  }

  static Future<bool> hasOfflineData() async {
    if (isOfflineServiceAvailable) {
      return await OfflineService.staticHasOfflineData();
    }
    return OfflineFallbackService().hasOfflineData();
  }

  static Future<int> getSyncQueueCount() async {
    if (isOfflineServiceAvailable) {
      return await OfflineService.staticGetSyncQueueCount();
    }
    return OfflineFallbackService().getSyncQueueCount();
  }

  static Future<Map<String, dynamic>> getCacheInfo() async {
    if (isOfflineServiceAvailable) {
      return await OfflineService.getCacheInfo();
    }
    return OfflineFallbackService().getCacheInfo();
  }

  static Future<void> syncPendingChanges() async {
    if (isOfflineServiceAvailable) {
      await OfflineService.syncPendingChanges();
    } else {
      // In fallback mode, we can't actually sync but we won't error
      AppLogger.info('Sync requested but offline service not available - using fallback mode');
    }
  }

  /// Get a status message about the current service state
  static String getServiceStatus() {
    if (isOfflineServiceAvailable) {
      return 'Full offline support enabled';
    } else if (OfflineService.initializationFailed) {
      return 'Offline service failed - using fallback mode';
    } else {
      return 'Web platform - in-memory fallback only';
    }
  }

  /// Check if we're in fallback mode
  static bool get isInFallbackMode => !isOfflineServiceAvailable;
}