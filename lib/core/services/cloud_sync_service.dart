// lib/core/services/cloud_sync_service.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_service.dart';
import 'app_logger.dart';

enum SyncStatus { idle, syncing, success, error, conflict }
enum SyncDirection { upload, download, bidirectional }

class SyncResult {
  final bool success;
  final String? error;
  final int operationsProcessed;
  final int conflictsResolved;
  final Duration syncDuration;

  SyncResult({
    required this.success,
    this.error,
    required this.operationsProcessed,
    required this.conflictsResolved,
    required this.syncDuration,
  });
}

class ConflictResolution {
  final String id;
  final String collection;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime conflictTime;
  final String resolution; // 'local', 'remote', 'merged'

  ConflictResolution({
    required this.id,
    required this.collection,
    required this.localData,
    required this.remoteData,
    required this.conflictTime,
    required this.resolution,
  });
}

class CloudSyncService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _syncProgressController = StreamController<double>.broadcast();
  final _conflictController = StreamController<ConflictResolution>.broadcast();

  SyncStatus _currentStatus = SyncStatus.idle;
  Timer? _autoSyncTimer;
  bool _isAutoSyncEnabled = true;
  Duration _autoSyncInterval = const Duration(minutes: 5);

  // Sync tracking
  final List<ConflictResolution> _resolvedConflicts = [];
  DateTime? _lastSyncTime;
  int _totalOperationsProcessed = 0;

  // Streams
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<double> get syncProgressStream => _syncProgressController.stream;
  Stream<ConflictResolution> get conflictStream => _conflictController.stream;

  // Getters
  SyncStatus get currentStatus => _currentStatus;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<ConflictResolution> get resolvedConflicts => _resolvedConflicts;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;
  Duration get autoSyncInterval => _autoSyncInterval;

  String? get userId => _auth.currentUser?.uid;

  /// Initialize the sync service
  Future<void> initialize() async {
    AppLogger.info('CloudSyncService initializing', category: LogCategory.sync);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final isOnline = result != ConnectivityResult.none;

      if (isOnline && _currentStatus == SyncStatus.idle) {
        _scheduleSync();
      }
    });

    // Start auto-sync if enabled
    if (_isAutoSyncEnabled) {
      _startAutoSync();
    }

    AppLogger.info('CloudSyncService initialized', category: LogCategory.sync);
  }

  /// Start automatic synchronization
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (timer) {
      if (_currentStatus == SyncStatus.idle) {
        _scheduleSync();
      }
    });
  }

  /// Schedule a sync operation
  void _scheduleSync() {
    Timer(const Duration(seconds: 2), () {
      syncWithFirebase();
    });
  }

  /// Main sync method - performs bidirectional sync with conflict resolution
  Future<SyncResult> syncWithFirebase({
    SyncDirection direction = SyncDirection.bidirectional,
    bool forceSync = false,
  }) async {
    if (_currentStatus == SyncStatus.syncing && !forceSync) {
      AppLogger.warning('Sync already in progress', category: LogCategory.sync);
      return SyncResult(
        success: false,
        error: 'Sync already in progress',
        operationsProcessed: 0,
        conflictsResolved: 0,
        syncDuration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    _updateSyncStatus(SyncStatus.syncing);
    _updateProgress(0.0);

    try {
      AppLogger.info('Starting cloud sync - Direction: $direction', category: LogCategory.sync);

      int operationsProcessed = 0;
      int conflictsResolved = 0;

      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      final connectivityResult = connectivityResults.isNotEmpty ? connectivityResults.first : ConnectivityResult.none;
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection available');
      }

      // Sync different collections based on direction
      switch (direction) {
        case SyncDirection.upload:
          final result = await _uploadPendingChanges();
          operationsProcessed += result.operationsProcessed;
          conflictsResolved += result.conflictsResolved;
          break;

        case SyncDirection.download:
          final result = await _downloadRemoteChanges();
          operationsProcessed += result.operationsProcessed;
          conflictsResolved += result.conflictsResolved;
          break;

        case SyncDirection.bidirectional:
          _updateProgress(0.25);

          // First upload pending changes
          final uploadResult = await _uploadPendingChanges();
          operationsProcessed += uploadResult.operationsProcessed;
          conflictsResolved += uploadResult.conflictsResolved;

          _updateProgress(0.75);

          // Then download remote changes
          final downloadResult = await _downloadRemoteChanges();
          operationsProcessed += downloadResult.operationsProcessed;
          conflictsResolved += downloadResult.conflictsResolved;
          break;
      }

      _updateProgress(1.0);
      _updateSyncStatus(SyncStatus.success);
      _lastSyncTime = DateTime.now();
      _totalOperationsProcessed += operationsProcessed;

      final duration = DateTime.now().difference(startTime);
      AppLogger.info(
        'Cloud sync completed - Operations: $operationsProcessed, Conflicts: $conflictsResolved, Duration: ${duration.inSeconds}s',
        category: LogCategory.sync,
      );

      return SyncResult(
        success: true,
        operationsProcessed: operationsProcessed,
        conflictsResolved: conflictsResolved,
        syncDuration: duration,
      );

    } catch (e) {
      AppLogger.error('Cloud sync failed', error: e, category: LogCategory.sync);
      _updateSyncStatus(SyncStatus.error);

      return SyncResult(
        success: false,
        error: e.toString(),
        operationsProcessed: 0,
        conflictsResolved: 0,
        syncDuration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Upload pending changes to Firebase
  Future<SyncResult> _uploadPendingChanges() async {
    int operationsProcessed = 0;
    int conflictsResolved = 0;

    try {
      // Get pending operations from offline service
      final pendingOps = OfflineService.staticPendingOperations;

      for (int i = 0; i < pendingOps.length; i++) {
        final operation = pendingOps[i];

        try {
          await _processPendingOperation(operation);
          operationsProcessed++;

          // Update progress
          _updateProgress(0.25 + (0.5 * (i + 1) / pendingOps.length));

        } catch (e) {
          if (e.toString().contains('conflict')) {
            final conflict = await _resolveConflict(operation);
            if (conflict != null) {
              _resolvedConflicts.add(conflict);
              _conflictController.add(conflict);
              conflictsResolved++;
            }
          }
          AppLogger.error('Error processing operation ${operation.id}', error: e, category: LogCategory.sync);
        }
      }

      return SyncResult(
        success: true,
        operationsProcessed: operationsProcessed,
        conflictsResolved: conflictsResolved,
        syncDuration: Duration.zero,
      );

    } catch (e) {
      AppLogger.error('Error uploading pending changes', error: e, category: LogCategory.sync);
      rethrow;
    }
  }

  /// Download remote changes from Firebase
  Future<SyncResult> _downloadRemoteChanges() async {
    int operationsProcessed = 0;
    int conflictsResolved = 0;

    try {
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Download clients
      final clientsResult = await _downloadCollection('clients');
      operationsProcessed += clientsResult.operationsProcessed;
      conflictsResolved += clientsResult.conflictsResolved;

      // Download quotes
      final quotesResult = await _downloadCollection('quotes');
      operationsProcessed += quotesResult.operationsProcessed;
      conflictsResolved += quotesResult.conflictsResolved;

      // Download cart items
      final cartResult = await _downloadCollection('cart_items');
      operationsProcessed += cartResult.operationsProcessed;
      conflictsResolved += cartResult.conflictsResolved;

      return SyncResult(
        success: true,
        operationsProcessed: operationsProcessed,
        conflictsResolved: conflictsResolved,
        syncDuration: Duration.zero,
      );

    } catch (e) {
      AppLogger.error('Error downloading remote changes', error: e, category: LogCategory.sync);
      rethrow;
    }
  }

  /// Download a specific collection from Firebase
  Future<SyncResult> _downloadCollection(String collection) async {
    int operationsProcessed = 0;
    int conflictsResolved = 0;

    try {
      final snapshot = await _db.ref('$collection/$userId').get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        for (final entry in data.entries) {
          final itemData = Map<String, dynamic>.from(entry.value);
          itemData['id'] = entry.key;

          // Check for local conflicts
          final conflict = await _checkForConflict(collection, entry.key, itemData);
          if (conflict != null) {
            _resolvedConflicts.add(conflict);
            _conflictController.add(conflict);
            conflictsResolved++;
          }

          operationsProcessed++;
        }
      }

      return SyncResult(
        success: true,
        operationsProcessed: operationsProcessed,
        conflictsResolved: conflictsResolved,
        syncDuration: Duration.zero,
      );

    } catch (e) {
      AppLogger.error('Error downloading collection $collection', error: e, category: LogCategory.sync);
      rethrow;
    }
  }

  /// Process a pending operation
  Future<void> _processPendingOperation(PendingOperation operation) async {
    try {
      final path = '${operation.collection}/$userId/${operation.id}';

      switch (operation.operation) {
        case OperationType.create:
          await _db.ref(path).set(operation.data);
          break;

        case OperationType.update:
          await _db.ref(path).update(operation.data);
          break;

        case OperationType.delete:
          await _db.ref(path).remove();
          break;
      }

      AppLogger.info('Processed operation ${operation.id} for ${operation.collection}', category: LogCategory.sync);

    } catch (e) {
      AppLogger.error('Error processing operation ${operation.id}', error: e, category: LogCategory.sync);
      rethrow;
    }
  }

  /// Check for conflicts between local and remote data
  Future<ConflictResolution?> _checkForConflict(String collection, String id, Map<String, dynamic> remoteData) async {
    // This would check against local data and detect conflicts
    // For now, we'll implement a simple timestamp-based conflict detection

    try {
      final localTimestamp = remoteData['updated_at'] as int?;
      final remoteTimestamp = remoteData['updated_at'] as int?;

      if (localTimestamp != null && remoteTimestamp != null) {
        if (localTimestamp > remoteTimestamp) {
          // Local data is newer - use local version
          return ConflictResolution(
            id: id,
            collection: collection,
            localData: remoteData, // This would be actual local data
            remoteData: remoteData,
            conflictTime: DateTime.now(),
            resolution: 'local',
          );
        }
      }

      return null;

    } catch (e) {
      AppLogger.error('Error checking conflict for $collection/$id', error: e, category: LogCategory.sync);
      return null;
    }
  }

  /// Resolve a conflict using configured strategy
  Future<ConflictResolution?> _resolveConflict(PendingOperation operation) async {
    try {
      // Get remote data
      final remotePath = '${operation.collection}/$userId/${operation.id}';
      final snapshot = await _db.ref(remotePath).get();

      if (!snapshot.exists) {
        // No remote data, proceed with local operation
        await _processPendingOperation(operation);
        return null;
      }

      final remoteData = Map<String, dynamic>.from(snapshot.value as Map);

      // Simple conflict resolution: newer timestamp wins
      final localTimestamp = operation.data['updated_at'] as int? ?? 0;
      final remoteTimestamp = remoteData['updated_at'] as int? ?? 0;

      if (localTimestamp >= remoteTimestamp) {
        // Local data is newer or equal, proceed with local operation
        await _processPendingOperation(operation);

        return ConflictResolution(
          id: operation.id,
          collection: operation.collection,
          localData: operation.data,
          remoteData: remoteData,
          conflictTime: DateTime.now(),
          resolution: 'local',
        );
      } else {
        // Remote data is newer, keep remote data
        return ConflictResolution(
          id: operation.id,
          collection: operation.collection,
          localData: operation.data,
          remoteData: remoteData,
          conflictTime: DateTime.now(),
          resolution: 'remote',
        );
      }

    } catch (e) {
      AppLogger.error('Error resolving conflict for operation ${operation.id}', error: e, category: LogCategory.sync);
      return null;
    }
  }

  /// Force sync all data
  Future<SyncResult> forceSyncAll() async {
    AppLogger.info('Starting force sync all', category: LogCategory.sync);
    return await syncWithFirebase(
      direction: SyncDirection.bidirectional,
      forceSync: true,
    );
  }

  /// Sync specific collection
  Future<SyncResult> syncCollection(String collection) async {
    AppLogger.info('Starting sync for collection: $collection', category: LogCategory.sync);

    final startTime = DateTime.now();
    _updateSyncStatus(SyncStatus.syncing);

    try {
      final result = await _downloadCollection(collection);
      _updateSyncStatus(SyncStatus.success);
      _lastSyncTime = DateTime.now();

      return SyncResult(
        success: true,
        operationsProcessed: result.operationsProcessed,
        conflictsResolved: result.conflictsResolved,
        syncDuration: DateTime.now().difference(startTime),
      );

    } catch (e) {
      _updateSyncStatus(SyncStatus.error);
      return SyncResult(
        success: false,
        error: e.toString(),
        operationsProcessed: 0,
        conflictsResolved: 0,
        syncDuration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Configure auto-sync settings
  void configureAutoSync({
    bool? enabled,
    Duration? interval,
  }) {
    if (enabled != null) {
      _isAutoSyncEnabled = enabled;
      if (enabled) {
        _startAutoSync();
      } else {
        _autoSyncTimer?.cancel();
      }
    }

    if (interval != null) {
      _autoSyncInterval = interval;
      if (_isAutoSyncEnabled) {
        _startAutoSync(); // Restart with new interval
      }
    }

    AppLogger.info(
      'Auto-sync configured - Enabled: $_isAutoSyncEnabled, Interval: ${_autoSyncInterval.inMinutes}min',
      category: LogCategory.sync,
    );
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'totalOperationsProcessed': _totalOperationsProcessed,
      'resolvedConflicts': _resolvedConflicts.length,
      'currentStatus': _currentStatus.toString(),
      'isAutoSyncEnabled': _isAutoSyncEnabled,
      'autoSyncInterval': _autoSyncInterval.inMinutes,
    };
  }

  /// Clear conflict history
  void clearConflictHistory() {
    _resolvedConflicts.clear();
    AppLogger.info('Conflict history cleared', category: LogCategory.sync);
  }

  /// Update sync status
  void _updateSyncStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  /// Update sync progress
  void _updateProgress(double progress) {
    _syncProgressController.add(progress);
  }

  /// Get sync queue status
  Future<Map<String, dynamic>> getSyncQueueStatus() async {
    final pendingCount = await OfflineService.staticGetSyncQueueCount();
    final hasOfflineData = await OfflineService.staticHasOfflineData();

    return {
      'pendingOperations': pendingCount,
      'hasOfflineData': hasOfflineData,
      'isOnline': OfflineService.staticIsOnline,
      'currentStatus': _currentStatus.toString(),
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    _autoSyncTimer?.cancel();
    _syncStatusController.close();
    _syncProgressController.close();
    _conflictController.close();
    AppLogger.info('CloudSyncService disposed', category: LogCategory.sync);
  }
}