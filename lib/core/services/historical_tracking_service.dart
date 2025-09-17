// lib/core/services/historical_tracking_service.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

enum ActionType { create, update, delete, view, export, import_data }
enum EntityType { client, quote, product, user, cart_item, project }

class HistoryEntry {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final ActionType action;
  final EntityType entityType;
  final String entityId;
  final Map<String, dynamic>? beforeData;
  final Map<String, dynamic>? afterData;
  final DateTime timestamp;
  final String? description;
  final Map<String, dynamic>? metadata;

  HistoryEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.beforeData,
    this.afterData,
    required this.timestamp,
    this.description,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'action': action.toString().split('.').last,
      'entityType': entityType.toString().split('.').last,
      'entityId': entityId,
      'beforeData': beforeData,
      'afterData': afterData,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'timestampIso': timestamp.toIso8601String(),
      'description': description,
      'metadata': metadata,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      userName: map['userName'] ?? '',
      action: ActionType.values.firstWhere(
        (e) => e.toString().split('.').last == map['action'],
        orElse: () => ActionType.update,
      ),
      entityType: EntityType.values.firstWhere(
        (e) => e.toString().split('.').last == map['entityType'],
        orElse: () => EntityType.client,
      ),
      entityId: map['entityId'] ?? '',
      beforeData: map['beforeData'] != null
          ? Map<String, dynamic>.from(map['beforeData'])
          : null,
      afterData: map['afterData'] != null
          ? Map<String, dynamic>.from(map['afterData'])
          : null,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      description: map['description'],
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }
}

class HistoricalTrackingService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _maxHistoryEntries = 10000; // Per user
  static const int _cleanupThreshold = 12000; // Start cleanup when this many entries

  String? get userId => _auth.currentUser?.uid;
  String? get userEmail => _auth.currentUser?.email;
  String? get userName => _auth.currentUser?.displayName ?? _auth.currentUser?.email?.split('@').first;

  /// Track a CRUD operation
  Future<String> trackOperation({
    required ActionType action,
    required EntityType entityType,
    required String entityId,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final historyId = _db.ref().push().key!;
      final now = DateTime.now();

      final historyEntry = HistoryEntry(
        id: historyId,
        userId: userId!,
        userEmail: userEmail ?? '',
        userName: userName ?? 'Unknown',
        action: action,
        entityType: entityType,
        entityId: entityId,
        beforeData: beforeData,
        afterData: afterData,
        timestamp: now,
        description: description ?? _generateDescription(action, entityType, entityId),
        metadata: metadata,
      );

      // Store in user's history
      await _db.ref('history/$userId/$historyId').set(historyEntry.toMap());

      // Store in global history for admin access
      await _db.ref('global_history/$historyId').set({
        ...historyEntry.toMap(),
        'userHistory': true,
      });

      AppLogger.info(
        'Tracked operation: ${action.toString().split('.').last} ${entityType.toString().split('.').last} $entityId',
        category: LogCategory.audit,
      );

      // Cleanup old entries if necessary
      _scheduleCleanup();

      return historyId;

    } catch (e) {
      AppLogger.error('Error tracking operation', error: e, category: LogCategory.audit);
      rethrow;
    }
  }

  /// Track client operations
  Future<String> trackClientOperation(
    ActionType action,
    String clientId, {
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? description,
  }) async {
    return await trackOperation(
      action: action,
      entityType: EntityType.client,
      entityId: clientId,
      beforeData: beforeData,
      afterData: afterData,
      description: description,
    );
  }

  /// Track quote operations
  Future<String> trackQuoteOperation(
    ActionType action,
    String quoteId, {
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    return await trackOperation(
      action: action,
      entityType: EntityType.quote,
      entityId: quoteId,
      beforeData: beforeData,
      afterData: afterData,
      description: description,
      metadata: metadata,
    );
  }

  /// Track product operations
  Future<String> trackProductOperation(
    ActionType action,
    String productId, {
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? description,
  }) async {
    return await trackOperation(
      action: action,
      entityType: EntityType.product,
      entityId: productId,
      beforeData: beforeData,
      afterData: afterData,
      description: description,
    );
  }

  /// Track cart operations
  Future<String> trackCartOperation(
    ActionType action,
    String cartItemId, {
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? description,
  }) async {
    return await trackOperation(
      action: action,
      entityType: EntityType.cart_item,
      entityId: cartItemId,
      beforeData: beforeData,
      afterData: afterData,
      description: description,
    );
  }

  /// Track user operations
  Future<String> trackUserOperation(
    ActionType action,
    String targetUserId, {
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? description,
  }) async {
    return await trackOperation(
      action: action,
      entityType: EntityType.user,
      entityId: targetUserId,
      beforeData: beforeData,
      afterData: afterData,
      description: description,
    );
  }

  /// Get history for current user
  Stream<List<HistoryEntry>> getUserHistory({
    int? limit,
    EntityType? entityType,
    ActionType? actionType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (userId == null) return Stream.value([]);

    Query query = _db.ref('history/$userId');

    // Apply ordering by timestamp (descending)
    query = query.orderByChild('timestamp');

    return query.onValue.map((event) {
      final List<HistoryEntry> entries = [];

      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final historyEntry = HistoryEntry.fromMap(
              Map<String, dynamic>.from(entry.value),
            );

            // Apply filters
            if (entityType != null && historyEntry.entityType != entityType) continue;
            if (actionType != null && historyEntry.action != actionType) continue;
            if (startDate != null && historyEntry.timestamp.isBefore(startDate)) continue;
            if (endDate != null && historyEntry.timestamp.isAfter(endDate)) continue;

            entries.add(historyEntry);
          } catch (e) {
            AppLogger.error('Error parsing history entry', error: e, category: LogCategory.audit);
          }
        }
      }

      // Sort by timestamp (newest first) and apply limit
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (limit != null && entries.length > limit) {
        return entries.take(limit).toList();
      }

      return entries;
    });
  }

  /// Get history for a specific entity
  Future<List<HistoryEntry>> getEntityHistory(
    EntityType entityType,
    String entityId, {
    int? limit,
  }) async {
    if (userId == null) return [];

    try {
      final snapshot = await _db.ref('history/$userId')
          .orderByChild('entityId')
          .equalTo(entityId)
          .get();

      final List<HistoryEntry> entries = [];

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final historyEntry = HistoryEntry.fromMap(
              Map<String, dynamic>.from(entry.value),
            );

            // Filter by entity type
            if (historyEntry.entityType == entityType) {
              entries.add(historyEntry);
            }
          } catch (e) {
            AppLogger.error('Error parsing entity history entry', error: e, category: LogCategory.audit);
          }
        }
      }

      // Sort by timestamp (newest first) and apply limit
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (limit != null && entries.length > limit) {
        return entries.take(limit).toList();
      }

      return entries;

    } catch (e) {
      AppLogger.error('Error getting entity history', error: e, category: LogCategory.audit);
      return [];
    }
  }

  /// Get global history (admin only)
  Stream<List<HistoryEntry>> getGlobalHistory({
    int? limit,
    EntityType? entityType,
    ActionType? actionType,
    String? targetUserId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Check if current user is admin
    if (!_isCurrentUserAdmin()) {
      AppLogger.warning('Unauthorized access to global history', category: LogCategory.audit);
      return Stream.value([]);
    }

    Query query = _db.ref('global_history');
    query = query.orderByChild('timestamp');

    return query.onValue.map((event) {
      final List<HistoryEntry> entries = [];

      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final historyEntry = HistoryEntry.fromMap(
              Map<String, dynamic>.from(entry.value),
            );

            // Apply filters
            if (entityType != null && historyEntry.entityType != entityType) continue;
            if (actionType != null && historyEntry.action != actionType) continue;
            if (targetUserId != null && historyEntry.userId != targetUserId) continue;
            if (startDate != null && historyEntry.timestamp.isBefore(startDate)) continue;
            if (endDate != null && historyEntry.timestamp.isAfter(endDate)) continue;

            entries.add(historyEntry);
          } catch (e) {
            AppLogger.error('Error parsing global history entry', error: e, category: LogCategory.audit);
          }
        }
      }

      // Sort by timestamp (newest first) and apply limit
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (limit != null && entries.length > limit) {
        return entries.take(limit).toList();
      }

      return entries;
    });
  }

  /// Rollback functionality - create reverse operation
  Future<Map<String, dynamic>?> createRollbackData(String historyId) async {
    try {
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _db.ref('history/$userId/$historyId').get();

      if (!snapshot.exists) {
        throw Exception('History entry not found');
      }

      final historyEntry = HistoryEntry.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
      );

      // Generate rollback instructions based on action type
      switch (historyEntry.action) {
        case ActionType.create:
          // Rollback create = delete
          return {
            'action': 'delete',
            'entityType': historyEntry.entityType.toString().split('.').last,
            'entityId': historyEntry.entityId,
            'reason': 'Rollback of create operation',
            'originalHistoryId': historyId,
          };

        case ActionType.update:
          // Rollback update = restore previous data
          if (historyEntry.beforeData != null) {
            return {
              'action': 'update',
              'entityType': historyEntry.entityType.toString().split('.').last,
              'entityId': historyEntry.entityId,
              'data': historyEntry.beforeData,
              'reason': 'Rollback of update operation',
              'originalHistoryId': historyId,
            };
          }
          break;

        case ActionType.delete:
          // Rollback delete = recreate
          if (historyEntry.beforeData != null) {
            return {
              'action': 'create',
              'entityType': historyEntry.entityType.toString().split('.').last,
              'entityId': historyEntry.entityId,
              'data': historyEntry.beforeData,
              'reason': 'Rollback of delete operation',
              'originalHistoryId': historyId,
            };
          }
          break;

        default:
          break;
      }

      return null;

    } catch (e) {
      AppLogger.error('Error creating rollback data', error: e, category: LogCategory.audit);
      return null;
    }
  }

  /// Get history statistics
  Future<Map<String, dynamic>> getHistoryStats({
    String? targetUserId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final isAdmin = _isCurrentUserAdmin();
      final searchUserId = isAdmin ? (targetUserId ?? userId) : userId;

      if (searchUserId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _db.ref('history/$searchUserId').get();

      if (!snapshot.exists) {
        return {
          'totalEntries': 0,
          'actionBreakdown': {},
          'entityBreakdown': {},
          'dailyActivity': {},
        };
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final entries = <HistoryEntry>[];

      for (final entry in data.entries) {
        try {
          final historyEntry = HistoryEntry.fromMap(
            Map<String, dynamic>.from(entry.value),
          );

          // Apply date filters
          if (startDate != null && historyEntry.timestamp.isBefore(startDate)) continue;
          if (endDate != null && historyEntry.timestamp.isAfter(endDate)) continue;

          entries.add(historyEntry);
        } catch (e) {
          // Skip invalid entries
        }
      }

      // Calculate statistics
      final actionBreakdown = <String, int>{};
      final entityBreakdown = <String, int>{};
      final dailyActivity = <String, int>{};

      for (final entry in entries) {
        // Action breakdown
        final actionKey = entry.action.toString().split('.').last;
        actionBreakdown[actionKey] = (actionBreakdown[actionKey] ?? 0) + 1;

        // Entity breakdown
        final entityKey = entry.entityType.toString().split('.').last;
        entityBreakdown[entityKey] = (entityBreakdown[entityKey] ?? 0) + 1;

        // Daily activity
        final dateKey = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
        dailyActivity[dateKey] = (dailyActivity[dateKey] ?? 0) + 1;
      }

      return {
        'totalEntries': entries.length,
        'actionBreakdown': actionBreakdown,
        'entityBreakdown': entityBreakdown,
        'dailyActivity': dailyActivity,
        'dateRange': {
          'start': entries.isNotEmpty ? entries.map((e) => e.timestamp).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String() : null,
          'end': entries.isNotEmpty ? entries.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String() : null,
        },
      };

    } catch (e) {
      AppLogger.error('Error getting history stats', error: e, category: LogCategory.audit);
      return {
        'totalEntries': 0,
        'actionBreakdown': {},
        'entityBreakdown': {},
        'dailyActivity': {},
        'error': e.toString(),
      };
    }
  }

  /// Clean up old history entries
  Future<void> cleanupOldEntries({int? retainCount}) async {
    try {
      if (userId == null) return;

      final retain = retainCount ?? _maxHistoryEntries;
      final snapshot = await _db.ref('history/$userId')
          .orderByChild('timestamp')
          .get();

      if (!snapshot.exists) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final entries = data.entries.toList();

      // Sort by timestamp (oldest first)
      entries.sort((a, b) {
        final aTime = (a.value as Map)['timestamp'] ?? 0;
        final bTime = (b.value as Map)['timestamp'] ?? 0;
        return aTime.compareTo(bTime);
      });

      if (entries.length <= retain) return;

      // Delete oldest entries
      final toDelete = entries.take(entries.length - retain);
      final updates = <String, dynamic>{};

      for (final entry in toDelete) {
        updates['history/$userId/${entry.key}'] = null;
        updates['global_history/${entry.key}'] = null;
      }

      await _db.ref().update(updates);

      AppLogger.info(
        'Cleaned up ${toDelete.length} old history entries',
        category: LogCategory.audit,
      );

    } catch (e) {
      AppLogger.error('Error cleaning up history entries', error: e, category: LogCategory.audit);
    }
  }

  /// Schedule cleanup if needed
  void _scheduleCleanup() {
    // Run cleanup in background after a delay
    Timer(const Duration(seconds: 30), () async {
      try {
        if (userId == null) return;

        final count = await _getHistoryCount();
        if (count > _cleanupThreshold) {
          await cleanupOldEntries();
        }
      } catch (e) {
        AppLogger.error('Error in scheduled cleanup', error: e, category: LogCategory.audit);
      }
    });
  }

  /// Get total history count for user
  Future<int> _getHistoryCount() async {
    try {
      if (userId == null) return 0;

      final snapshot = await _db.ref('history/$userId').get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data.length;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Check if current user is admin
  bool _isCurrentUserAdmin() {
    // This would check user role from database or auth claims
    // For now, we'll check if email is the admin email
    return userEmail == 'andres@turboairmexico.com';
  }

  /// Generate description for operation
  String _generateDescription(ActionType action, EntityType entityType, String entityId) {
    final actionStr = action.toString().split('.').last;
    final entityStr = entityType.toString().split('.').last;

    switch (action) {
      case ActionType.create:
        return 'Created $entityStr $entityId';
      case ActionType.update:
        return 'Updated $entityStr $entityId';
      case ActionType.delete:
        return 'Deleted $entityStr $entityId';
      case ActionType.view:
        return 'Viewed $entityStr $entityId';
      case ActionType.export:
        return 'Exported $entityStr $entityId';
      case ActionType.import_data:
        return 'Imported $entityStr data';
      default:
        return 'Performed $actionStr on $entityStr $entityId';
    }
  }

  /// Export history data
  Future<List<Map<String, dynamic>>> exportHistoryData({
    DateTime? startDate,
    DateTime? endDate,
    EntityType? entityType,
    ActionType? actionType,
  }) async {
    try {
      if (userId == null) return [];

      final snapshot = await _db.ref('history/$userId').get();
      if (!snapshot.exists) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final exportData = <Map<String, dynamic>>[];

      for (final entry in data.entries) {
        try {
          final historyEntry = HistoryEntry.fromMap(
            Map<String, dynamic>.from(entry.value),
          );

          // Apply filters
          if (entityType != null && historyEntry.entityType != entityType) continue;
          if (actionType != null && historyEntry.action != actionType) continue;
          if (startDate != null && historyEntry.timestamp.isBefore(startDate)) continue;
          if (endDate != null && historyEntry.timestamp.isAfter(endDate)) continue;

          exportData.add(historyEntry.toMap());
        } catch (e) {
          // Skip invalid entries
        }
      }

      // Sort by timestamp (newest first)
      exportData.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      AppLogger.info('Exported ${exportData.length} history entries', category: LogCategory.audit);
      return exportData;

    } catch (e) {
      AppLogger.error('Error exporting history data', error: e, category: LogCategory.audit);
      return [];
    }
  }
}