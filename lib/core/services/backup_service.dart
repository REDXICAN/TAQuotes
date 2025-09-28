// lib/core/services/backup_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'app_logger.dart';
import 'rbac_service.dart';
import '../utils/download_helper.dart';

/// Service for handling database backups
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a complete database backup
  Future<BackupData> generateBackup({
    bool includeProducts = true,
    bool includeClients = true,
    bool includeQuotes = true,
    bool includeUsers = true,
    bool includeSpareParts = true,
    bool includeWarehouseData = true,
  }) async {
    try {
      AppLogger.info('Starting database backup generation');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is admin
      final canManageBackups = await RBACService.hasPermission('manage_backups');

      final Map<String, dynamic> backupData = {
        'metadata': {
          'version': '1.0',
          'created_at': DateTime.now().toIso8601String(),
          'created_by': user.email,
          'app_version': '1.5.3',
          'is_complete': canManageBackups,
          'sections': [],
        },
        'data': {},
      };

      // Fetch products (all users can backup)
      if (includeProducts) {
        AppLogger.info('Fetching products for backup');
        final productsSnapshot = await _db.ref('products').get();
        if (productsSnapshot.exists) {
          backupData['data']['products'] = productsSnapshot.value;
          backupData['metadata']['sections'].add('products');
          AppLogger.info('Added products to backup');
        }
      }

      // Fetch spare parts (all users can backup)
      if (includeSpareParts) {
        AppLogger.info('Fetching spare parts for backup');
        final sparePartsSnapshot = await _db.ref('spareparts').get();
        if (sparePartsSnapshot.exists) {
          backupData['data']['spareparts'] = sparePartsSnapshot.value;
          backupData['metadata']['sections'].add('spareparts');
          AppLogger.info('Added spare parts to backup');
        }
      }

      // Fetch user-specific data
      if (includeClients) {
        AppLogger.info('Fetching clients for backup');
        if (canManageBackups) {
          // Admin gets all clients
          final clientsSnapshot = await _db.ref('clients').get();
          if (clientsSnapshot.exists) {
            backupData['data']['clients'] = clientsSnapshot.value;
            backupData['metadata']['sections'].add('clients');
          }
        } else {
          // Regular user gets only their clients
          final clientsSnapshot = await _db.ref('clients/${user.uid}').get();
          if (clientsSnapshot.exists) {
            backupData['data']['clients'] = {
              user.uid: clientsSnapshot.value,
            };
            backupData['metadata']['sections'].add('clients');
          }
        }
        AppLogger.info('Added clients to backup');
      }

      if (includeQuotes) {
        AppLogger.info('Fetching quotes for backup');
        if (canManageBackups) {
          // Admin gets all quotes
          final quotesSnapshot = await _db.ref('quotes').get();
          if (quotesSnapshot.exists) {
            backupData['data']['quotes'] = quotesSnapshot.value;
            backupData['metadata']['sections'].add('quotes');
          }
        } else {
          // Regular user gets only their quotes
          final quotesSnapshot = await _db.ref('quotes/${user.uid}').get();
          if (quotesSnapshot.exists) {
            backupData['data']['quotes'] = {
              user.uid: quotesSnapshot.value,
            };
            backupData['metadata']['sections'].add('quotes');
          }
        }
        AppLogger.info('Added quotes to backup');
      }

      // Admin-only sections
      if (canManageBackups) {
        if (includeUsers) {
          AppLogger.info('Fetching users for backup');
          final usersSnapshot = await _db.ref('users').get();
          if (usersSnapshot.exists) {
            backupData['data']['users'] = usersSnapshot.value;
            backupData['metadata']['sections'].add('users');
          }

          final profilesSnapshot = await _db.ref('user_profiles').get();
          if (profilesSnapshot.exists) {
            backupData['data']['user_profiles'] = profilesSnapshot.value;
            backupData['metadata']['sections'].add('user_profiles');
          }
          AppLogger.info('Added users to backup');
        }

        if (includeWarehouseData) {
          AppLogger.info('Fetching warehouse data for backup');
          final warehouseSnapshot = await _db.ref('warehouse_stock').get();
          if (warehouseSnapshot.exists) {
            backupData['data']['warehouse_stock'] = warehouseSnapshot.value;
            backupData['metadata']['sections'].add('warehouse_stock');
          }
          AppLogger.info('Added warehouse data to backup');
        }
      }

      // Calculate backup size
      final jsonString = jsonEncode(backupData);
      final bytes = utf8.encode(jsonString);
      final sizeInMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);

      backupData['metadata']['size_mb'] = sizeInMB;
      backupData['metadata']['item_counts'] = _calculateItemCounts(backupData['data']);

      AppLogger.info('Backup generated successfully', data: {
        'size_mb': sizeInMB,
        'sections': backupData['metadata']['sections'],
      });

      return BackupData(
        data: backupData,
        sizeInMB: double.parse(sizeInMB),
        timestamp: DateTime.now(),
        sections: List<String>.from(backupData['metadata']['sections']),
      );

    } catch (e, stackTrace) {
      AppLogger.error('Failed to generate backup', error: e, stackTrace: stackTrace);
      throw Exception('Failed to generate backup: $e');
    }
  }

  /// Download backup as JSON file
  Future<void> downloadBackup(BackupData backup) async {
    try {
      // Convert backup data to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup.data);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      // Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(backup.timestamp);
      final filename = 'taquotes_backup_$timestamp.json';

      // Use DownloadHelper to handle platform-specific download
      await DownloadHelper.downloadFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/json',
      );

      AppLogger.info('Backup downloaded', data: {
        'filename': filename,
        'size_mb': backup.sizeInMB,
      });

    } catch (e) {
      AppLogger.error('Failed to download backup', error: e);
      throw Exception('Failed to download backup: $e');
    }
  }

  /// Download a partial backup with selected sections
  Future<void> downloadPartialBackup({
    required List<String> sections,
    String? customFilename,
  }) async {
    try {
      // Generate backup with only selected sections
      final backup = await generateBackup(
        includeProducts: sections.contains('products'),
        includeClients: sections.contains('clients'),
        includeQuotes: sections.contains('quotes'),
        includeUsers: sections.contains('users'),
        includeSpareParts: sections.contains('spareparts'),
        includeWarehouseData: sections.contains('warehouse_stock'),
      );

      // Download the backup
      await downloadBackup(backup);

    } catch (e) {
      AppLogger.error('Failed to download partial backup', error: e);
      rethrow;
    }
  }

  /// Restore database from backup
  Future<RestoreResult> restoreFromBackup(String jsonContent) async {
    try {
      AppLogger.info('Starting database restore');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Parse the backup JSON
      final Map<String, dynamic> backupData = jsonDecode(jsonContent);

      // Validate backup structure
      if (!backupData.containsKey('metadata') || !backupData.containsKey('data')) {
        throw Exception('Invalid backup file structure');
      }

      final metadata = backupData['metadata'];
      final data = backupData['data'] as Map<String, dynamic>;

      // Check if user is admin
      final canManageBackups = await RBACService.hasPermission('manage_backups');

      int itemsRestored = 0;
      final List<String> restoredSections = [];
      final List<String> errors = [];

      // Restore products (admin only)
      if (data.containsKey('products') && canManageBackups) {
        try {
          await _db.ref('products').set(data['products']);
          restoredSections.add('products');
          itemsRestored += (data['products'] as Map).length;
        } catch (e) {
          errors.add('Failed to restore products: $e');
        }
      }

      // Restore spare parts (admin only)
      if (data.containsKey('spareparts') && canManageBackups) {
        try {
          await _db.ref('spareparts').set(data['spareparts']);
          restoredSections.add('spareparts');
          itemsRestored += (data['spareparts'] as Map).length;
        } catch (e) {
          errors.add('Failed to restore spare parts: $e');
        }
      }

      // Restore clients
      if (data.containsKey('clients')) {
        try {
          if (canManageBackups) {
            // Admin can restore all clients
            await _db.ref('clients').set(data['clients']);
            itemsRestored += _countNestedItems(data['clients'] as Map);
          } else {
            // Regular user can only restore their own clients
            final userClients = (data['clients'] as Map)[user.uid];
            if (userClients != null) {
              await _db.ref('clients/${user.uid}').set(userClients);
              itemsRestored += (userClients as Map).length;
            }
          }
          restoredSections.add('clients');
        } catch (e) {
          errors.add('Failed to restore clients: $e');
        }
      }

      // Restore quotes
      if (data.containsKey('quotes')) {
        try {
          if (canManageBackups) {
            // Admin can restore all quotes
            await _db.ref('quotes').set(data['quotes']);
            itemsRestored += _countNestedItems(data['quotes'] as Map);
          } else {
            // Regular user can only restore their own quotes
            final userQuotes = (data['quotes'] as Map)[user.uid];
            if (userQuotes != null) {
              await _db.ref('quotes/${user.uid}').set(userQuotes);
              itemsRestored += (userQuotes as Map).length;
            }
          }
          restoredSections.add('quotes');
        } catch (e) {
          errors.add('Failed to restore quotes: $e');
        }
      }

      // Restore users and profiles (admin only)
      if (data.containsKey('users') && canManageBackups) {
        try {
          await _db.ref('users').set(data['users']);
          restoredSections.add('users');
          itemsRestored += (data['users'] as Map).length;
        } catch (e) {
          errors.add('Failed to restore users: $e');
        }
      }

      if (data.containsKey('user_profiles') && canManageBackups) {
        try {
          await _db.ref('user_profiles').set(data['user_profiles']);
          restoredSections.add('user_profiles');
          itemsRestored += (data['user_profiles'] as Map).length;
        } catch (e) {
          errors.add('Failed to restore user profiles: $e');
        }
      }

      // Restore warehouse data (admin only)
      if (data.containsKey('warehouse_stock') && canManageBackups) {
        try {
          await _db.ref('warehouse_stock').set(data['warehouse_stock']);
          restoredSections.add('warehouse_stock');
          itemsRestored += _countNestedItems(data['warehouse_stock'] as Map);
        } catch (e) {
          errors.add('Failed to restore warehouse stock: $e');
        }
      }

      AppLogger.info('Database restore completed', data: {
        'items_restored': itemsRestored,
        'sections_restored': restoredSections,
        'errors': errors.length,
      });

      return RestoreResult(
        success: errors.isEmpty,
        itemsRestored: itemsRestored,
        sectionsRestored: restoredSections,
        errors: errors,
        timestamp: DateTime.now(),
      );

    } catch (e, stackTrace) {
      AppLogger.error('Failed to restore from backup', error: e, stackTrace: stackTrace);
      throw Exception('Failed to restore from backup: $e');
    }
  }

  /// Calculate item counts in backup data
  Map<String, int> _calculateItemCounts(Map<String, dynamic> data) {
    final counts = <String, int>{};

    data.forEach((key, value) {
      if (value is Map) {
        // For nested structures (like clients/userId/items)
        if (key == 'clients' || key == 'quotes') {
          counts[key] = _countNestedItems(value);
        } else {
          counts[key] = value.length;
        }
      }
    });

    return counts;
  }

  /// Count items in nested map structure
  int _countNestedItems(Map items) {
    int count = 0;
    items.forEach((key, value) {
      if (value is Map) {
        count += value.length;
      }
    });
    return count;
  }

  /// Get backup history from Firebase
  Stream<List<BackupEntry>> getBackupHistory({int? limit}) async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    final canManageBackups = await RBACService.hasPermission('manage_backups');
    final ref = canManageBackups
        ? _db.ref('backup_history')
        : _db.ref('backup_history').orderByChild('userId').equalTo(user.uid);

    await for (final event in ref
        .orderByChild('createdAt')
        .limitToLast(limit ?? 50)
        .onValue) {
      if (event.snapshot.value == null) {
        yield [];
        continue;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final entries = <BackupEntry>[];

      data.forEach((key, value) {
        try {
          final entry = BackupEntry.fromMap(Map<String, dynamic>.from(value), key);
          entries.add(entry);
        } catch (e) {
          AppLogger.error('Error parsing backup entry', error: e);
        }
      });

      // Sort by createdAt descending
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      yield entries;
    }
  }

  /// Save backup info to Firebase
  Future<void> saveBackupEntry(BackupEntry entry) async {
    try {
      await _db.ref('backup_history/${entry.id}').set(entry.toMap());
      AppLogger.info('Backup entry saved', data: {
        'id': entry.id,
        'size_mb': entry.fileSize != null ? (entry.fileSize! / 1048576).toStringAsFixed(2) : 'N/A',
      });
    } catch (e) {
      AppLogger.error('Failed to save backup entry', error: e);
    }
  }

  /// Create manual backup with Firebase tracking
  Future<BackupResult> createManualBackup({
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return BackupResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Create backup entry
      final entry = BackupEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        userEmail: user.email ?? 'unknown',
        type: BackupType.manual,
        status: BackupStatus.running,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      // Save initial entry
      await saveBackupEntry(entry);

      // Generate backup
      final backup = await generateBackup();

      // Update entry with success
      entry.status = BackupStatus.completed;
      entry.completedAt = DateTime.now();
      entry.fileSize = (backup.sizeInMB * 1048576).round();
      entry.sections = backup.sections;
      entry.downloadUrl = 'local'; // Mark as available for download

      await saveBackupEntry(entry);

      return BackupResult(
        success: true,
        fileSize: entry.fileSize,
        entry: entry,
      );

    } catch (e) {
      AppLogger.error('Failed to create manual backup', error: e);
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get backup statistics
  Future<Map<String, dynamic>> getBackupStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'totalBackups': 0,
          'completedBackups': 0,
          'failedBackups': 0,
          'totalSize': 0,
        };
      }

      final canManageBackups = await RBACService.hasPermission('manage_backups');

      final snapshot = await (canManageBackups
          ? _db.ref('backup_history').get()
          : _db.ref('backup_history').orderByChild('userId').equalTo(user.uid).get());

      if (!snapshot.exists || snapshot.value == null) {
        return {
          'totalBackups': 0,
          'completedBackups': 0,
          'failedBackups': 0,
          'totalSize': 0,
        };
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int totalBackups = 0;
      int completedBackups = 0;
      int failedBackups = 0;
      int totalSize = 0;

      data.forEach((key, value) {
        final entry = Map<String, dynamic>.from(value);
        totalBackups++;

        final status = entry['status'];
        if (status == 'completed') {
          completedBackups++;
          totalSize += (entry['fileSize'] ?? 0) as int;
        } else if (status == 'failed') {
          failedBackups++;
        }
      });

      return {
        'totalBackups': totalBackups,
        'completedBackups': completedBackups,
        'failedBackups': failedBackups,
        'totalSize': totalSize,
      };

    } catch (e) {
      AppLogger.error('Failed to get backup stats', error: e);
      return {
        'totalBackups': 0,
        'completedBackups': 0,
        'failedBackups': 0,
        'totalSize': 0,
      };
    }
  }
}

/// Backup data model
class BackupData {
  final Map<String, dynamic> data;
  final double sizeInMB;
  final DateTime timestamp;
  final List<String> sections;

  BackupData({
    required this.data,
    required this.sizeInMB,
    required this.timestamp,
    required this.sections,
  });
}

/// Restore result model
class RestoreResult {
  final bool success;
  final int itemsRestored;
  final List<String> sectionsRestored;
  final List<String> errors;
  final DateTime timestamp;

  RestoreResult({
    required this.success,
    required this.itemsRestored,
    required this.sectionsRestored,
    required this.errors,
    required this.timestamp,
  });
}

/// Backup result model
class BackupResult {
  final bool success;
  final String? error;
  final int? fileSize;
  final BackupEntry? entry;

  BackupResult({
    required this.success,
    this.error,
    this.fileSize,
    this.entry,
  });
}

/// Backup types
enum BackupType {
  manual,
  scheduled,
  emergency,
}

/// Backup status
enum BackupStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

/// Backup entry model for Firebase
class BackupEntry {
  final String id;
  final String userId;
  final String userEmail;
  BackupType type;
  BackupStatus status;
  final DateTime createdAt;
  DateTime? completedAt;
  int? fileSize;
  List<String>? sections;
  String? downloadUrl;
  String? error;
  Map<String, dynamic>? metadata;

  BackupEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.fileSize,
    this.sections,
    this.downloadUrl,
    this.error,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'fileSize': fileSize,
      'sections': sections,
      'downloadUrl': downloadUrl,
      'error': error,
      'metadata': metadata,
    };
  }

  factory BackupEntry.fromMap(Map<String, dynamic> map, String id) {
    return BackupEntry(
      id: id,
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      type: BackupType.values.firstWhere(
        (t) => t.toString().split('.').last == map['type'],
        orElse: () => BackupType.manual,
      ),
      status: BackupStatus.values.firstWhere(
        (s) => s.toString().split('.').last == map['status'],
        orElse: () => BackupStatus.pending,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      fileSize: map['fileSize'],
      sections: map['sections'] != null
          ? List<String>.from(map['sections'])
          : null,
      downloadUrl: map['downloadUrl'],
      error: map['error'],
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }
}