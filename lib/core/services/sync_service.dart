// lib/core/services/sync_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import 'app_logger.dart';
import 'offline_service.dart';
import 'realtime_database_service.dart';
import '../config/app_config.dart';

/// Comprehensive data synchronization service for TAQuotes
/// Handles bi-directional sync between local Hive storage and Firebase
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final RealtimeDatabaseService _dbService = RealtimeDatabaseService();
  late OfflineService _offlineService;

  final _syncStatusController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncStatusStream => _syncStatusController.stream;

  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  // Track sync conflicts
  final List<SyncConflict> _conflicts = [];
  List<SyncConflict> get conflicts => _conflicts;

  /// Initialize the sync service
  Future<void> initialize() async {
    AppLogger.info('Initializing SyncService');

    if (!kIsWeb) {
      _offlineService = OfflineService();

      // Listen to connectivity changes
      Connectivity().onConnectivityChanged.listen((result) {
        if (result != ConnectivityResult.none) {
          // Automatically sync when connection is restored
          syncAll();
        }
      });

      // Set up periodic sync
      _startPeriodicSync();
    }

    AppLogger.info('SyncService initialized');
  }

  /// Start periodic synchronization
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(AppConfig.syncInterval, (_) {
      if (!_isSyncing) {
        syncAll();
      }
    });
  }

  /// Stop periodic synchronization
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// Main sync function - synchronizes all data
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      AppLogger.warning('Sync already in progress, skipping');
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        timestamp: DateTime.now(),
      );
    }

    _isSyncing = true;
    _conflicts.clear();

    final startTime = DateTime.now();
    AppLogger.info('Starting full data sync');
    _syncStatusController.add(SyncProgress(
      status: SyncStatus.syncing,
      message: 'Starting synchronization...',
      progress: 0,
    ));

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }

      // Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      int totalSteps = 5;
      int currentStep = 0;

      // 1. Sync pending operations from offline queue
      _updateProgress('Syncing pending operations...', ++currentStep / totalSteps);
      await _syncPendingOperations();

      // 2. Sync products (download only - products are read-only for users)
      _updateProgress('Syncing products...', ++currentStep / totalSteps);
      await _syncProducts();

      // 3. Sync clients (bi-directional)
      _updateProgress('Syncing clients...', ++currentStep / totalSteps);
      await _syncClients(user.uid);

      // 4. Sync quotes (bi-directional)
      _updateProgress('Syncing quotes...', ++currentStep / totalSteps);
      await _syncQuotes(user.uid);

      // 5. Sync cart items
      _updateProgress('Syncing cart...', ++currentStep / totalSteps);
      await _syncCart(user.uid);

      _lastSyncTime = DateTime.now();
      final duration = _lastSyncTime!.difference(startTime);

      final result = SyncResult(
        success: true,
        message: 'Sync completed successfully',
        timestamp: _lastSyncTime!,
        duration: duration,
        itemsSynced: _calculateItemsSynced(),
        conflicts: _conflicts,
      );

      _syncStatusController.add(SyncProgress(
        status: SyncStatus.success,
        message: result.message,
        progress: 1.0,
      ));

      AppLogger.info('Sync completed', additionalData: {
        'duration': duration.inMilliseconds,
        'conflicts': _conflicts.length,
      });

      return result;

    } catch (e, stackTrace) {
      AppLogger.error('Sync failed', error: e, stackTrace: stackTrace);

      final result = SyncResult(
        success: false,
        message: 'Sync failed: ${e.toString()}',
        timestamp: DateTime.now(),
        error: e.toString(),
      );

      _syncStatusController.add(SyncProgress(
        status: SyncStatus.error,
        message: result.message,
        progress: 0,
      ));

      return result;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync pending operations from offline queue
  Future<void> _syncPendingOperations() async {
    if (kIsWeb) return;

    final pendingOps = _offlineService.pendingOperations;
    AppLogger.info('Syncing ${pendingOps.length} pending operations');

    for (final op in pendingOps) {
      try {
        await _executePendingOperation(op);
        await _offlineService.removePendingOperation(op.id);
      } catch (e) {
        AppLogger.error('Failed to sync operation ${op.id}', error: e);

        // Increment retry count
        op.retryCount++;

        // Remove if too many retries
        if (op.retryCount > 3) {
          await _offlineService.removePendingOperation(op.id);
          _conflicts.add(SyncConflict(
            type: ConflictType.operationFailed,
            collection: op.collection,
            itemId: op.id,
            message: 'Operation failed after 3 retries',
            localData: op.data,
          ));
        }
      }
    }
  }

  /// Execute a single pending operation
  Future<void> _executePendingOperation(PendingOperation op) async {
    final db = FirebaseDatabase.instance;

    switch (op.operation) {
      case OperationType.create:
        await db.ref('${op.collection}/${op.id}').set(op.data);
        break;
      case OperationType.update:
        await db.ref('${op.collection}/${op.id}').update(op.data);
        break;
      case OperationType.delete:
        await db.ref('${op.collection}/${op.id}').remove();
        break;
    }
  }

  /// Sync products (download only)
  Future<void> _syncProducts() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('products').get();

      if (snapshot.exists && !kIsWeb) {
        final products = Map<String, dynamic>.from(snapshot.value as Map);

        // Save to local storage
        for (final entry in products.entries) {
          final productData = Map<String, dynamic>.from(entry.value);
          productData['id'] = entry.key;

          final product = Product.fromMap(productData);
          await _offlineService.saveProduct(product);
        }

        AppLogger.info('Synced ${products.length} products');
      }
    } catch (e) {
      AppLogger.error('Failed to sync products', error: e);
      rethrow;
    }
  }

  /// Sync clients (bi-directional)
  Future<void> _syncClients(String userId) async {
    try {
      // Get remote clients
      final remoteSnapshot = await FirebaseDatabase.instance
          .ref('clients/$userId')
          .get();

      final remoteClients = <String, Map<String, dynamic>>{};
      if (remoteSnapshot.exists) {
        final data = Map<String, dynamic>.from(remoteSnapshot.value as Map);
        data.forEach((key, value) {
          remoteClients[key] = Map<String, dynamic>.from(value);
        });
      }

      // Get local clients (if offline mode)
      final localClients = <String, Client>{};
      if (!kIsWeb) {
        final clients = _offlineService.getClients();
        for (final client in clients) {
          if (client.id != null) {
            localClients[client.id!] = client;
          }
        }
      }

      // Merge and detect conflicts
      for (final entry in remoteClients.entries) {
        final remoteClient = Client.fromMap({...entry.value, 'id': entry.key});
        final localClient = localClients[entry.key];

        if (localClient != null) {
          // Check for conflict
          if (localClient.updatedAt != null &&
              remoteClient.updatedAt != null &&
              localClient.updatedAt!.isAfter(remoteClient.updatedAt!)) {
            // Local is newer - upload
            await FirebaseDatabase.instance
                .ref('clients/$userId/${entry.key}')
                .set(localClient.toMap());
          } else if (!kIsWeb) {
            // Remote is newer - download
            await _offlineService.saveClient(remoteClient);
          }
        } else if (!kIsWeb) {
          // New remote client - download
          await _offlineService.saveClient(remoteClient);
        }
      }

      // Upload local-only clients
      for (final entry in localClients.entries) {
        if (!remoteClients.containsKey(entry.key)) {
          await FirebaseDatabase.instance
              .ref('clients/$userId/${entry.key}')
              .set(entry.value.toMap());
        }
      }

      AppLogger.info('Synced clients for user $userId');
    } catch (e) {
      AppLogger.error('Failed to sync clients', error: e);
      rethrow;
    }
  }

  /// Sync quotes (bi-directional)
  Future<void> _syncQuotes(String userId) async {
    try {
      // Get remote quotes
      final remoteSnapshot = await FirebaseDatabase.instance
          .ref('quotes/$userId')
          .get();

      final remoteQuotes = <String, Map<String, dynamic>>{};
      if (remoteSnapshot.exists) {
        final data = Map<String, dynamic>.from(remoteSnapshot.value as Map);
        data.forEach((key, value) {
          remoteQuotes[key] = Map<String, dynamic>.from(value);
        });
      }

      // Get local quotes (if offline mode)
      final localQuotes = <String, Quote>{};
      if (!kIsWeb) {
        final quotes = _offlineService.getQuotes();
        for (final quote in quotes) {
          if (quote.id != null) {
            localQuotes[quote.id!] = quote;
          }
        }
      }

      // Merge and detect conflicts
      for (final entry in remoteQuotes.entries) {
        final remoteQuote = Quote.fromMap({...entry.value, 'id': entry.key});
        final localQuote = localQuotes[entry.key];

        if (localQuote != null) {
          // Check for conflict based on updated timestamp
          if (localQuote.updatedAt != null &&
              remoteQuote.updatedAt != null &&
              localQuote.updatedAt!.isAfter(remoteQuote.updatedAt!)) {
            // Local is newer - upload
            await FirebaseDatabase.instance
                .ref('quotes/$userId/${entry.key}')
                .set(localQuote.toMap());
          } else if (!kIsWeb) {
            // Remote is newer - download
            await _offlineService.saveQuote(remoteQuote);
          }
        } else if (!kIsWeb) {
          // New remote quote - download
          await _offlineService.saveQuote(remoteQuote);
        }
      }

      // Upload local-only quotes
      for (final entry in localQuotes.entries) {
        if (!remoteQuotes.containsKey(entry.key)) {
          await FirebaseDatabase.instance
              .ref('quotes/$userId/${entry.key}')
              .set(entry.value.toMap());
        }
      }

      AppLogger.info('Synced quotes for user $userId');
    } catch (e) {
      AppLogger.error('Failed to sync quotes', error: e);
      rethrow;
    }
  }

  /// Sync cart items
  Future<void> _syncCart(String userId) async {
    try {
      // Get remote cart
      final remoteSnapshot = await FirebaseDatabase.instance
          .ref('carts/$userId')
          .get();

      if (remoteSnapshot.exists && !kIsWeb) {
        final remoteCart = Map<String, dynamic>.from(remoteSnapshot.value as Map);
        final items = (remoteCart['items'] as List?)
            ?.map((item) => CartItem.fromMap(Map<String, dynamic>.from(item)))
            .toList() ?? [];

        await _offlineService.saveCart(items);
        AppLogger.info('Synced ${items.length} cart items');
      }

      // Upload local cart if newer
      if (!kIsWeb) {
        final localCart = _offlineService.getCart();
        if (localCart.isNotEmpty) {
          await FirebaseDatabase.instance
              .ref('carts/$userId')
              .set({
                'items': localCart.map((item) => item.toMap()).toList(),
                'updatedAt': DateTime.now().toIso8601String(),
              });
        }
      }
    } catch (e) {
      AppLogger.error('Failed to sync cart', error: e);
      // Cart sync is non-critical, don't throw
    }
  }

  /// Update sync progress
  void _updateProgress(String message, double progress) {
    _syncStatusController.add(SyncProgress(
      status: SyncStatus.syncing,
      message: message,
      progress: progress,
    ));
  }

  /// Calculate total items synced
  int _calculateItemsSynced() {
    // This would track actual items synced during the process
    return 0; // Placeholder
  }

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Check if sync is needed
  bool get isSyncNeeded {
    if (_lastSyncTime == null) return true;

    final timeSinceSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceSync > AppConfig.syncInterval;
  }

  /// Clear all sync data and conflicts
  Future<void> clearSyncData() async {
    _conflicts.clear();
    _lastSyncTime = null;

    if (!kIsWeb) {
      await _offlineService.clearAll();
    }

    AppLogger.info('Cleared all sync data');
  }

  /// Dispose the service
  void dispose() {
    _periodicSyncTimer?.cancel();
    _syncStatusController.close();
  }
}

/// Sync progress information
class SyncProgress {
  final SyncStatus status;
  final String message;
  final double progress;

  SyncProgress({
    required this.status,
    required this.message,
    required this.progress,
  });
}

/// Sync result
class SyncResult {
  final bool success;
  final String message;
  final DateTime timestamp;
  final Duration? duration;
  final int? itemsSynced;
  final List<SyncConflict>? conflicts;
  final String? error;

  SyncResult({
    required this.success,
    required this.message,
    required this.timestamp,
    this.duration,
    this.itemsSynced,
    this.conflicts,
    this.error,
  });
}

/// Sync conflict information
class SyncConflict {
  final ConflictType type;
  final String collection;
  final String itemId;
  final String message;
  final Map<String, dynamic>? localData;
  final Map<String, dynamic>? remoteData;

  SyncConflict({
    required this.type,
    required this.collection,
    required this.itemId,
    required this.message,
    this.localData,
    this.remoteData,
  });
}

/// Types of sync conflicts
enum ConflictType {
  dataConflict,
  operationFailed,
  authenticationError,
  networkError,
}