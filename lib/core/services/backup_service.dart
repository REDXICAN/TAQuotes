// lib/core/services/backup_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

enum BackupType { manual, scheduled, emergency }
enum BackupStatus { pending, running, completed, failed, cancelled }

class BackupEntry {
  final String id;
  final String userId;
  final String userEmail;
  final BackupType type;
  final BackupStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? downloadUrl;
  final int? fileSize;
  final String? error;
  final Map<String, dynamic> metadata;

  BackupEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.downloadUrl,
    this.fileSize,
    this.error,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdAtIso': createdAt.toIso8601String(),
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'completedAtIso': completedAt?.toIso8601String(),
      'downloadUrl': downloadUrl,
      'fileSize': fileSize,
      'error': error,
      'metadata': metadata,
    };
  }

  factory BackupEntry.fromMap(Map<String, dynamic> map) {
    return BackupEntry(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      type: BackupType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => BackupType.manual,
      ),
      status: BackupStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => BackupStatus.pending,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      downloadUrl: map['downloadUrl'],
      fileSize: map['fileSize'],
      error: map['error'],
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : {},
    );
  }
}

class BackupResult {
  final bool success;
  final String? backupId;
  final String? downloadUrl;
  final int? fileSize;
  final String? error;
  final Duration duration;

  BackupResult({
    required this.success,
    this.backupId,
    this.downloadUrl,
    this.fileSize,
    this.error,
    required this.duration,
  });
}

class RestoreResult {
  final bool success;
  final int itemsRestored;
  final String? error;
  final Duration duration;

  RestoreResult({
    required this.success,
    required this.itemsRestored,
    this.error,
    required this.duration,
  });
}

class BackupService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _scheduledBackupTimer;
  bool _isScheduledBackupEnabled = true;
  Duration _backupInterval = const Duration(days: 1); // Daily backups
  TimeOfDay _backupTime = TimeOfDay(hour: 2, minute: 0); // 2:00 AM

  final _backupStatusController = StreamController<BackupEntry>.broadcast();
  final _restoreStatusController = StreamController<String>.broadcast();

  // Streams
  Stream<BackupEntry> get backupStatusStream => _backupStatusController.stream;
  Stream<String> get restoreStatusStream => _restoreStatusController.stream;

  String? get userId => _auth.currentUser?.uid;
  String? get userEmail => _auth.currentUser?.email;

  /// Initialize the backup service
  Future<void> initialize() async {
    AppLogger.info('BackupService initializing', category: LogCategory.business);

    // Start scheduled backups if enabled
    if (_isScheduledBackupEnabled) {
      _scheduleNextBackup();
    }

    AppLogger.info('BackupService initialized', category: LogCategory.business);
  }

  /// Create a manual backup
  Future<BackupResult> createManualBackup({
    List<String>? collections,
    Map<String, dynamic>? metadata,
  }) async {
    return await _createBackup(
      type: BackupType.manual,
      collections: collections,
      metadata: metadata ?? {},
    );
  }

  /// Create a scheduled backup (admin only)
  Future<BackupResult> createScheduledBackup() async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin or superadmin users can create scheduled backups');
    }

    return await _createBackup(
      type: BackupType.scheduled,
      collections: ['products', 'clients', 'quotes', 'users', 'user_profiles'],
      metadata: {'scheduled': true, 'autoGenerated': true},
    );
  }

  /// Create an emergency backup
  Future<BackupResult> createEmergencyBackup() async {
    return await _createBackup(
      type: BackupType.emergency,
      collections: ['products', 'clients', 'quotes', 'users', 'user_profiles'],
      metadata: {'emergency': true, 'priority': 'high'},
    );
  }

  /// Main backup creation method
  Future<BackupResult> _createBackup({
    required BackupType type,
    List<String>? collections,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final startTime = DateTime.now();
    final backupId = _db.ref().push().key!;

    // Create backup entry
    final backupEntry = BackupEntry(
      id: backupId,
      userId: userId!,
      userEmail: userEmail ?? '',
      type: type,
      status: BackupStatus.running,
      createdAt: startTime,
      metadata: metadata,
    );

    try {
      AppLogger.info('Starting backup - Type: $type, ID: $backupId', category: LogCategory.business);

      // Save backup entry to database
      await _db.ref('backups/$backupId').set(backupEntry.toMap());
      _backupStatusController.add(backupEntry);

      // Determine collections to backup
      final collectionsToBackup = collections ?? _getDefaultCollections();

      // Create backup data
      final backupData = await _createBackupData(collectionsToBackup);

      // Convert to JSON
      final jsonData = jsonEncode(backupData);
      final bytes = utf8.encode(jsonData);

      // Upload to Firebase Storage
      final fileName = 'backup_${backupId}_${DateTime.now().millisecondsSinceEpoch}.json';
      final storageRef = _storage.ref().child('backups/$userId/$fileName');

      final uploadTask = storageRef.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(
          contentType: 'application/json',
          customMetadata: {
            'backupId': backupId,
            'userId': userId!,
            'type': type.toString().split('.').last,
            'collections': collectionsToBackup.join(','),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update backup entry with completion
      final completedEntry = BackupEntry(
        id: backupId,
        userId: userId!,
        userEmail: userEmail ?? '',
        type: type,
        status: BackupStatus.completed,
        createdAt: startTime,
        completedAt: DateTime.now(),
        downloadUrl: downloadUrl,
        fileSize: bytes.length,
        metadata: {
          ...metadata,
          'collections': collectionsToBackup,
          'itemCount': _countItems(backupData),
        },
      );

      await _db.ref('backups/$backupId').update(completedEntry.toMap());
      _backupStatusController.add(completedEntry);

      final duration = DateTime.now().difference(startTime);
      AppLogger.info(
        'Backup completed - ID: $backupId, Size: ${bytes.length} bytes, Duration: ${duration.inSeconds}s',
        category: LogCategory.business,
      );

      return BackupResult(
        success: true,
        backupId: backupId,
        downloadUrl: downloadUrl,
        fileSize: bytes.length,
        duration: duration,
      );

    } catch (e) {
      AppLogger.error('Backup failed - ID: $backupId', error: e, category: LogCategory.business);

      // Update backup entry with error
      final failedEntry = BackupEntry(
        id: backupId,
        userId: userId!,
        userEmail: userEmail ?? '',
        type: type,
        status: BackupStatus.failed,
        createdAt: startTime,
        completedAt: DateTime.now(),
        error: e.toString(),
        metadata: metadata,
      );

      await _db.ref('backups/$backupId').update(failedEntry.toMap());
      _backupStatusController.add(failedEntry);

      return BackupResult(
        success: false,
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Create backup data from specified collections
  Future<Map<String, dynamic>> _createBackupData(List<String> collections) async {
    final backupData = <String, dynamic>{
      'metadata': {
        'createdAt': DateTime.now().toIso8601String(),
        'userId': userId,
        'userEmail': userEmail,
        'collections': collections,
        'version': '1.0',
      },
      'data': <String, dynamic>{},
    };

    for (final collection in collections) {
      try {
        backupData['data'][collection] = await _exportCollection(collection);
      } catch (e) {
        AppLogger.error('Error backing up collection $collection', error: e, category: LogCategory.business);
        backupData['data'][collection] = {'error': e.toString()};
      }
    }

    return backupData;
  }

  /// Export a single collection
  Future<Map<String, dynamic>> _exportCollection(String collection) async {
    switch (collection) {
      case 'products':
        return await _exportProducts();
      case 'clients':
        return await _exportClients();
      case 'quotes':
        return await _exportQuotes();
      case 'users':
        return await _exportUsers();
      case 'user_profiles':
        return await _exportUserProfiles();
      case 'cart_items':
        return await _exportCartItems();
      default:
        throw Exception('Unknown collection: $collection');
    }
  }

  /// Export products (admin only)
  Future<Map<String, dynamic>> _exportProducts() async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can backup products');
    }

    final snapshot = await _db.ref('products').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  /// Export clients for current user
  Future<Map<String, dynamic>> _exportClients() async {
    if (userId == null) return {};

    final snapshot = await _db.ref('clients/$userId').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  /// Export quotes for current user
  Future<Map<String, dynamic>> _exportQuotes() async {
    if (userId == null) return {};

    final snapshot = await _db.ref('quotes/$userId').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  /// Export users (admin only)
  Future<Map<String, dynamic>> _exportUsers() async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can backup user data');
    }

    final snapshot = await _db.ref('users').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  /// Export user profiles (admin only)
  Future<Map<String, dynamic>> _exportUserProfiles() async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can backup user profiles');
    }

    final snapshot = await _db.ref('user_profiles').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  /// Export cart items for current user
  Future<Map<String, dynamic>> _exportCartItems() async {
    if (userId == null) return {};

    final snapshot = await _db.ref('cart_items/$userId').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  /// Restore from backup
  Future<RestoreResult> restoreFromBackup(String backupId, {
    List<String>? collections,
    bool overwriteExisting = false,
  }) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final startTime = DateTime.now();
    int itemsRestored = 0;

    try {
      AppLogger.info('Starting restore from backup: $backupId', category: LogCategory.business);
      _restoreStatusController.add('Starting restore from backup: $backupId');

      // Get backup entry
      final backupSnapshot = await _db.ref('backups/$backupId').get();
      if (!backupSnapshot.exists) {
        throw Exception('Backup not found');
      }

      final backupEntry = BackupEntry.fromMap(
        Map<String, dynamic>.from(backupSnapshot.value as Map),
      );

      if (backupEntry.downloadUrl == null) {
        throw Exception('Backup file not available');
      }

      // Download backup file
      _restoreStatusController.add('Downloading backup file...');
      final storageRef = _storage.refFromURL(backupEntry.downloadUrl!);
      final backupBytes = await storageRef.getData();

      if (backupBytes == null) {
        throw Exception('Failed to download backup file');
      }

      // Parse backup data
      _restoreStatusController.add('Parsing backup data...');
      final backupJson = utf8.decode(backupBytes);
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;

      final data = backupData['data'] as Map<String, dynamic>;
      final collectionsToRestore = collections ?? data.keys.toList();

      // Restore each collection
      for (final collection in collectionsToRestore) {
        if (!data.containsKey(collection)) {
          continue;
        }

        _restoreStatusController.add('Restoring $collection...');
        final collectionData = Map<String, dynamic>.from(data[collection]);

        final restored = await _restoreCollection(
          collection,
          collectionData,
          overwriteExisting,
        );

        itemsRestored += restored;
      }

      final duration = DateTime.now().difference(startTime);
      AppLogger.info(
        'Restore completed - Items: $itemsRestored, Duration: ${duration.inSeconds}s',
        category: LogCategory.business,
      );

      _restoreStatusController.add('Restore completed successfully');

      return RestoreResult(
        success: true,
        itemsRestored: itemsRestored,
        duration: duration,
      );

    } catch (e) {
      AppLogger.error('Restore failed', error: e, category: LogCategory.business);
      _restoreStatusController.add('Restore failed: ${e.toString()}');

      return RestoreResult(
        success: false,
        itemsRestored: itemsRestored,
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Restore a single collection
  Future<int> _restoreCollection(
    String collection,
    Map<String, dynamic> data,
    bool overwriteExisting,
  ) async {
    int itemsRestored = 0;

    switch (collection) {
      case 'clients':
        itemsRestored = await _restoreClients(data, overwriteExisting);
        break;
      case 'quotes':
        itemsRestored = await _restoreQuotes(data, overwriteExisting);
        break;
      case 'cart_items':
        itemsRestored = await _restoreCartItems(data, overwriteExisting);
        break;
      case 'products':
        if (_isCurrentUserAdminOrSuperAdmin()) {
          itemsRestored = await _restoreProducts(data, overwriteExisting);
        }
        break;
      case 'users':
      case 'user_profiles':
        if (_isCurrentUserAdminOrSuperAdmin()) {
          itemsRestored = await _restoreUserData(collection, data, overwriteExisting);
        }
        break;
      default:
        AppLogger.warning('Unknown collection for restore: $collection', category: LogCategory.business);
    }

    return itemsRestored;
  }

  /// Restore clients
  Future<int> _restoreClients(Map<String, dynamic> data, bool overwriteExisting) async {
    if (userId == null) return 0;

    int count = 0;
    final updates = <String, dynamic>{};

    for (final entry in data.entries) {
      final clientId = entry.key;
      final clientData = Map<String, dynamic>.from(entry.value);

      if (!overwriteExisting) {
        // Check if client already exists
        final exists = await _db.ref('clients/$userId/$clientId').get();
        if (exists.exists) continue;
      }

      updates['clients/$userId/$clientId'] = clientData;
      count++;
    }

    if (updates.isNotEmpty) {
      await _db.ref().update(updates);
    }

    return count;
  }

  /// Restore quotes
  Future<int> _restoreQuotes(Map<String, dynamic> data, bool overwriteExisting) async {
    if (userId == null) return 0;

    int count = 0;
    final updates = <String, dynamic>{};

    for (final entry in data.entries) {
      final quoteId = entry.key;
      final quoteData = Map<String, dynamic>.from(entry.value);

      if (!overwriteExisting) {
        // Check if quote already exists
        final exists = await _db.ref('quotes/$userId/$quoteId').get();
        if (exists.exists) continue;
      }

      updates['quotes/$userId/$quoteId'] = quoteData;
      count++;
    }

    if (updates.isNotEmpty) {
      await _db.ref().update(updates);
    }

    return count;
  }

  /// Restore cart items
  Future<int> _restoreCartItems(Map<String, dynamic> data, bool overwriteExisting) async {
    if (userId == null) return 0;

    int count = 0;
    final updates = <String, dynamic>{};

    for (final entry in data.entries) {
      final itemId = entry.key;
      final itemData = Map<String, dynamic>.from(entry.value);

      if (!overwriteExisting) {
        // Check if item already exists
        final exists = await _db.ref('cart_items/$userId/$itemId').get();
        if (exists.exists) continue;
      }

      updates['cart_items/$userId/$itemId'] = itemData;
      count++;
    }

    if (updates.isNotEmpty) {
      await _db.ref().update(updates);
    }

    return count;
  }

  /// Restore products (admin only)
  Future<int> _restoreProducts(Map<String, dynamic> data, bool overwriteExisting) async {
    int count = 0;
    final updates = <String, dynamic>{};

    for (final entry in data.entries) {
      final productId = entry.key;
      final productData = Map<String, dynamic>.from(entry.value);

      if (!overwriteExisting) {
        // Check if product already exists
        final exists = await _db.ref('products/$productId').get();
        if (exists.exists) continue;
      }

      updates['products/$productId'] = productData;
      count++;
    }

    if (updates.isNotEmpty) {
      await _db.ref().update(updates);
    }

    return count;
  }

  /// Restore user data (admin only)
  Future<int> _restoreUserData(String collection, Map<String, dynamic> data, bool overwriteExisting) async {
    int count = 0;
    final updates = <String, dynamic>{};

    for (final entry in data.entries) {
      final itemId = entry.key;
      final itemData = Map<String, dynamic>.from(entry.value);

      if (!overwriteExisting) {
        // Check if item already exists
        final exists = await _db.ref('$collection/$itemId').get();
        if (exists.exists) continue;
      }

      updates['$collection/$itemId'] = itemData;
      count++;
    }

    if (updates.isNotEmpty) {
      await _db.ref().update(updates);
    }

    return count;
  }

  /// Get backup history
  Stream<List<BackupEntry>> getBackupHistory({
    String? targetUserId,
    BackupType? type,
    BackupStatus? status,
    int? limit,
  }) {
    final isAdmin = _isCurrentUserAdminOrSuperAdmin();
    final searchUserId = isAdmin ? (targetUserId ?? userId) : userId;

    if (searchUserId == null) {
      return Stream.value([]);
    }

    Query query = _db.ref('backups');

    // Filter by user if not admin or specific user requested
    if (!isAdmin || targetUserId != null) {
      query = query.orderByChild('userId').equalTo(searchUserId);
    } else {
      query = query.orderByChild('createdAt');
    }

    return query.onValue.map((event) {
      final List<BackupEntry> entries = [];

      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final backupEntry = BackupEntry.fromMap(
              Map<String, dynamic>.from(entry.value),
            );

            // Apply filters
            if (type != null && backupEntry.type != type) continue;
            if (status != null && backupEntry.status != status) continue;

            entries.add(backupEntry);
          } catch (e) {
            AppLogger.error('Error parsing backup entry', error: e, category: LogCategory.business);
          }
        }
      }

      // Sort by creation date (newest first) and apply limit
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (limit != null && entries.length > limit) {
        return entries.take(limit).toList();
      }

      return entries;
    });
  }

  /// Delete backup
  Future<void> deleteBackup(String backupId) async {
    try {
      // Get backup entry
      final snapshot = await _db.ref('backups/$backupId').get();
      if (!snapshot.exists) {
        throw Exception('Backup not found');
      }

      final backupEntry = BackupEntry.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
      );

      // Check permissions
      if (!_isCurrentUserAdminOrSuperAdmin() && backupEntry.userId != userId) {
        throw Exception('Permission denied');
      }

      // Delete file from storage if it exists
      if (backupEntry.downloadUrl != null) {
        try {
          final storageRef = _storage.refFromURL(backupEntry.downloadUrl!);
          await storageRef.delete();
        } catch (e) {
          AppLogger.warning('Failed to delete backup file from storage', category: LogCategory.business);
        }
      }

      // Delete database entry
      await _db.ref('backups/$backupId').remove();

      AppLogger.info('Backup deleted: $backupId', category: LogCategory.business);

    } catch (e) {
      AppLogger.error('Error deleting backup', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Configure scheduled backups
  void configureScheduledBackups({
    bool? enabled,
    Duration? interval,
    TimeOfDay? time,
  }) {
    if (enabled != null) {
      _isScheduledBackupEnabled = enabled;
    }

    if (interval != null) {
      _backupInterval = interval;
    }

    if (time != null) {
      _backupTime = time;
    }

    // Restart scheduling
    _scheduledBackupTimer?.cancel();
    if (_isScheduledBackupEnabled) {
      _scheduleNextBackup();
    }

    AppLogger.info(
      'Scheduled backups configured - Enabled: $_isScheduledBackupEnabled, Interval: ${_backupInterval.inDays} days',
      category: LogCategory.business,
    );
  }

  /// Schedule next backup
  void _scheduleNextBackup() {
    if (!_isScheduledBackupEnabled) return;

    final now = DateTime.now();
    var nextBackup = DateTime(
      now.year,
      now.month,
      now.day,
      _backupTime.hour,
      _backupTime.minute,
    );

    // If today's backup time has passed, schedule for tomorrow
    if (nextBackup.isBefore(now)) {
      nextBackup = nextBackup.add(const Duration(days: 1));
    }

    final delay = nextBackup.difference(now);

    _scheduledBackupTimer = Timer(delay, () {
      // Create scheduled backup
      createScheduledBackup().then((result) {
        if (result.success) {
          AppLogger.info('Scheduled backup completed', category: LogCategory.business);
        } else {
          AppLogger.error('Scheduled backup failed: ${result.error}', category: LogCategory.business);
        }

        // Schedule next backup
        _scheduleNextBackup();
      }).catchError((e) {
        AppLogger.error('Scheduled backup error', error: e, category: LogCategory.business);
        _scheduleNextBackup(); // Still schedule next one
      });
    });

    AppLogger.info(
      'Next scheduled backup: ${nextBackup.toIso8601String()}',
      category: LogCategory.business,
    );
  }

  /// Get backup statistics
  Future<Map<String, dynamic>> getBackupStats() async {
    try {
      final isAdmin = _isCurrentUserAdminOrSuperAdmin();
      Query query = _db.ref('backups');

      if (!isAdmin && userId != null) {
        query = query.orderByChild('userId').equalTo(userId);
      }

      final snapshot = await query.get();

      if (!snapshot.exists) {
        return {
          'totalBackups': 0,
          'successfulBackups': 0,
          'failedBackups': 0,
          'totalSize': 0,
          'lastBackup': null,
        };
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int totalBackups = 0;
      int successfulBackups = 0;
      int failedBackups = 0;
      int totalSize = 0;
      DateTime? lastBackup;

      for (final entry in data.values) {
        final backupEntry = BackupEntry.fromMap(
          Map<String, dynamic>.from(entry),
        );

        totalBackups++;

        if (backupEntry.status == BackupStatus.completed) {
          successfulBackups++;
          totalSize += backupEntry.fileSize ?? 0;
        } else if (backupEntry.status == BackupStatus.failed) {
          failedBackups++;
        }

        if (lastBackup == null || backupEntry.createdAt.isAfter(lastBackup)) {
          lastBackup = backupEntry.createdAt;
        }
      }

      return {
        'totalBackups': totalBackups,
        'successfulBackups': successfulBackups,
        'failedBackups': failedBackups,
        'totalSize': totalSize,
        'lastBackup': lastBackup?.toIso8601String(),
        'isScheduledEnabled': _isScheduledBackupEnabled,
        'backupInterval': _backupInterval.inDays,
      };

    } catch (e) {
      AppLogger.error('Error getting backup stats', error: e, category: LogCategory.business);
      return {'error': e.toString()};
    }
  }

  /// Helper methods
  List<String> _getDefaultCollections() {
    if (_isCurrentUserAdminOrSuperAdmin()) {
      return ['products', 'clients', 'quotes', 'users', 'user_profiles'];
    }
    return ['clients', 'quotes', 'cart_items'];
  }

  bool _isCurrentUserAdminOrSuperAdmin() {
    return userEmail == 'andres@turboairmexico.com';
  }

  int _countItems(Map<String, dynamic> backupData) {
    int count = 0;
    final data = backupData['data'] as Map<String, dynamic>? ?? {};

    for (final collection in data.values) {
      if (collection is Map) {
        count += collection.length;
      }
    }

    return count;
  }

  /// Dispose resources
  void dispose() {
    _scheduledBackupTimer?.cancel();
    _backupStatusController.close();
    _restoreStatusController.close();
    AppLogger.info('BackupService disposed', category: LogCategory.business);
  }
}

class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}