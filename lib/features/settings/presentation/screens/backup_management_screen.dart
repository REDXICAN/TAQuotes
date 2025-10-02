// lib/features/settings/presentation/screens/backup_management_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart' hide currentUserRoleProvider;

// Providers for backup management
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final backupHistoryProvider = StreamProvider.autoDispose<List<BackupEntry>>((ref) {
  final service = ref.watch(backupServiceProvider);
  return service.getBackupHistory(limit: 20);
});

final backupStatsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final service = ref.watch(backupServiceProvider);

  // Initial load
  yield await service.getBackupStats();

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await service.getBackupStats();
    } catch (e) {
      AppLogger.warning('Failed to refresh backup stats, using last known values', error: e);
      // Continue with previous data on error
      yield <String, dynamic>{
        'totalBackups': 0,
        'completedBackups': 0,
        'failedBackups': 0,
        'totalSize': 0,
      };
    }
  }
});

class BackupManagementScreen extends ConsumerStatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  ConsumerState<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends ConsumerState<BackupManagementScreen> {
  bool _isCreatingBackup = false;
  bool _isRestoringBackup = false;
  String? _lastBackupError;
  int _retryCount = 0;
  static const int maxRetries = 3;

  // Backup creation options
  bool _includeProducts = true;
  bool _includeClients = true;
  bool _includeQuotes = true;
  bool _includeUsers = false;
  bool _includeSpareParts = true;
  bool _includeWarehouseData = false;

  @override
  Widget build(BuildContext context) {
    final backupHistoryAsync = ref.watch(backupHistoryProvider);
    final backupStatsAsync = ref.watch(backupStatsProvider);
    final hasBackupPermission = ref.watch(hasPermissionProvider(Permission.manageDatabase));
    final isAdmin = ref.watch(isAdminProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Management'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(backupHistoryProvider);
              ref.invalidate(backupStatsProvider);
              setState(() {
                _lastBackupError = null;
                _retryCount = 0;
              });
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Access Information Card
            _buildAccessInfoCard(currentUser, hasBackupPermission, isAdmin),
            const SizedBox(height: 24),

            // Error Display
            if (_lastBackupError != null) ...[
              _buildErrorCard(),
              const SizedBox(height: 16),
            ],

            // Backup Statistics
            _buildStatsSection(backupStatsAsync),
            const SizedBox(height: 24),

            // Quick Actions Section
            _buildQuickActionsSection(hasBackupPermission, isAdmin),
            const SizedBox(height: 24),

            // Advanced Backup Options
            _buildAdvancedOptionsSection(hasBackupPermission, isAdmin),
            const SizedBox(height: 24),

            // Backup History
            _buildBackupHistorySection(backupHistoryAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessInfoCard(
    User? currentUser,
    AsyncValue<bool> hasBackupPermission,
    AsyncValue<bool> isAdmin
  ) {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Access Level',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (currentUser != null) ...[
              Text('User: ${currentUser.email}'),
              const SizedBox(height: 8),
              hasBackupPermission.when(
                data: (hasPermission) => isAdmin.when(
                  data: (isAdminUser) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasPermission ? Icons.check_circle : Icons.cancel,
                            color: hasPermission ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasPermission
                              ? 'Full backup access granted'
                              : 'Limited backup access (personal data only)',
                            style: TextStyle(
                              color: hasPermission ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (isAdminUser) ...[
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.admin_panel_settings, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Admin privileges enabled',
                              style: TextStyle(color: Colors.blue, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error: $e'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error checking permissions: $e'),
              ),
            ] else ...[
              const Text(
                'Please log in to access backup functionality',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Last Operation Error',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_lastBackupError!),
            if (_retryCount > 0) ...[
              const SizedBox(height: 8),
              Text('Retry attempts: $_retryCount/$maxRetries'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _lastBackupError = null;
                      _retryCount = 0;
                    });
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                if (_retryCount < maxRetries)
                  ElevatedButton.icon(
                    onPressed: _retryLastOperation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(AsyncValue<Map<String, dynamic>> backupStatsAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            backupStatsAsync.when(
              data: (stats) => _buildStatsGrid(stats),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => _buildErrorRetryWidget(
                'Failed to load backup statistics',
                error.toString(),
                () => ref.invalidate(backupStatsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
          'Total Backups',
          stats['totalBackups']?.toString() ?? '0',
          Icons.inventory_2,
          Colors.blue,
        ),
        _buildStatCard(
          'Successful',
          stats['completedBackups']?.toString() ?? '0',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Failed',
          stats['failedBackups']?.toString() ?? '0',
          Icons.error,
          Colors.red,
        ),
        _buildStatCard(
          'Total Size',
          _formatFileSize(stats['totalSize'] ?? 0),
          Icons.storage,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(
    AsyncValue<bool> hasBackupPermission,
    AsyncValue<bool> isAdmin
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingBackup ? null : _createQuickBackup,
                    icon: _isCreatingBackup
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.backup),
                    label: Text(_isCreatingBackup ? 'Creating...' : 'Quick Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRestoringBackup ? null : _selectAndRestoreBackup,
                    icon: _isRestoringBackup
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore),
                    label: Text(_isRestoringBackup ? 'Restoring...' : 'Restore'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportDatabaseToExcel,
                icon: const Icon(Icons.table_chart),
                label: const Text('Export Database to Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Excel export downloads the entire product database in a format that can be edited and re-uploaded',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsSection(
    AsyncValue<bool> hasBackupPermission,
    AsyncValue<bool> isAdmin
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Backup Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Backup section toggles
            _buildSectionToggle(
              'Products',
              'Product catalog and inventory',
              _includeProducts,
              (value) => setState(() => _includeProducts = value),
              enabled: true,
            ),
            _buildSectionToggle(
              'Clients',
              'Your client database',
              _includeClients,
              (value) => setState(() => _includeClients = value),
              enabled: true,
            ),
            _buildSectionToggle(
              'Quotes',
              'Your quotes and proposals',
              _includeQuotes,
              (value) => setState(() => _includeQuotes = value),
              enabled: true,
            ),
            _buildSectionToggle(
              'Spare Parts',
              'Spare parts catalog',
              _includeSpareParts,
              (value) => setState(() => _includeSpareParts = value),
              enabled: true,
            ),

            // Admin-only sections
            hasBackupPermission.when(
              data: (hasPermission) => hasPermission ? Column(
                children: [
                  _buildSectionToggle(
                    'Users',
                    'User accounts and profiles (Admin only)',
                    _includeUsers,
                    (value) => setState(() => _includeUsers = value),
                    enabled: true,
                    adminOnly: true,
                  ),
                  _buildSectionToggle(
                    'Warehouse Data',
                    'Stock levels and warehouse info (Admin only)',
                    _includeWarehouseData,
                    (value) => setState(() => _includeWarehouseData = value),
                    enabled: true,
                    adminOnly: true,
                  ),
                ],
              ) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreatingBackup ? null : _createCustomBackup,
                icon: _isCreatingBackup
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.settings_backup_restore),
                label: Text(_isCreatingBackup ? 'Creating Custom Backup...' : 'Create Custom Backup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionToggle(
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
    bool adminOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Row(
          children: [
            Text(title),
            if (adminOnly) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          description,
          style: const TextStyle(fontSize: 12),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        dense: true,
      ),
    );
  }

  Widget _buildBackupHistorySection(AsyncValue<List<BackupEntry>> backupHistoryAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            backupHistoryAsync.when(
              data: (backups) => _buildBackupList(backups),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => _buildErrorRetryWidget(
                'Failed to load backup history',
                error.toString(),
                () => ref.invalidate(backupHistoryProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupList(List<BackupEntry> backups) {
    if (backups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No backups found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first backup using the buttons above',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: backups.length,
      itemBuilder: (context, index) {
        final backup = backups[index];
        return _buildBackupListItem(backup);
      },
    );
  }

  Widget _buildBackupListItem(BackupEntry backup) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(backup.status).withValues(alpha: 0.2),
          child: Icon(
            _getStatusIcon(backup.status),
            color: _getStatusColor(backup.status),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              backup.type.toString().split('.').last.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(backup.status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                backup.status.toString().split('.').last,
                style: TextStyle(
                  fontSize: 11,
                  color: _getStatusColor(backup.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Created: ${dateFormat.format(backup.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (backup.fileSize != null)
              Text(
                'Size: ${_formatFileSize(backup.fileSize!)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (backup.completedAt != null) ...[
                  Text('Completed: ${dateFormat.format(backup.completedAt!)}'),
                  const SizedBox(height: 8),
                ],
                if (backup.sections != null && backup.sections!.isNotEmpty) ...[
                  const Text(
                    'Included Sections:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: backup.sections!.map((section) => Chip(
                      label: Text(
                        section,
                        style: const TextStyle(fontSize: 10),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (backup.error != null) ...[
                  Text(
                    'Error: ${backup.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    if (backup.status == BackupStatus.completed)
                      ElevatedButton.icon(
                        onPressed: () => _downloadBackup(backup),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (backup.status == BackupStatus.failed)
                      ElevatedButton.icon(
                        onPressed: () => _retryBackup(backup),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRetryWidget(String title, String error, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[300],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Action Methods
  Future<void> _createQuickBackup() async {
    await _executeWithRetry(() async {
      setState(() {
        _isCreatingBackup = true;
        _lastBackupError = null;
      });

      try {
        final service = ref.read(backupServiceProvider);
        final result = await service.createManualBackup(
          metadata: {
            'source': 'backup_management_screen',
            'type': 'quick_backup',
            'created_from': 'quick_action',
          },
        );

        if (result.success) {
          _showSuccessMessage('Quick backup created successfully! Size: ${_formatFileSize(result.fileSize ?? 0)}');
          ref.invalidate(backupHistoryProvider);
          ref.invalidate(backupStatsProvider);
        } else {
          throw Exception(result.error ?? 'Backup creation failed');
        }
      } catch (e) {
        setState(() {
          _lastBackupError = 'Failed to create quick backup: $e';
        });
        rethrow;
      } finally {
        setState(() => _isCreatingBackup = false);
      }
    });
  }

  Future<void> _createCustomBackup() async {
    await _executeWithRetry(() async {
      setState(() {
        _isCreatingBackup = true;
        _lastBackupError = null;
      });

      try {
        final service = ref.read(backupServiceProvider);
        final backup = await service.generateBackup(
          includeProducts: _includeProducts,
          includeClients: _includeClients,
          includeQuotes: _includeQuotes,
          includeUsers: _includeUsers,
          includeSpareParts: _includeSpareParts,
          includeWarehouseData: _includeWarehouseData,
        );

        await service.downloadBackup(backup);

        // Create entry in history
        await service.createManualBackup(
          metadata: {
            'source': 'backup_management_screen',
            'type': 'custom_backup',
            'sections': backup.sections,
          },
        );

        _showSuccessMessage('Custom backup created and downloaded! Size: ${backup.sizeInMB.toStringAsFixed(2)} MB');
        ref.invalidate(backupHistoryProvider);
        ref.invalidate(backupStatsProvider);
      } catch (e) {
        setState(() {
          _lastBackupError = 'Failed to create custom backup: $e';
        });
        rethrow;
      } finally {
        setState(() => _isCreatingBackup = false);
      }
    });
  }

  Future<void> _exportDatabaseToExcel() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Exporting database to Excel...'),
            ],
          ),
        ),
      );

      // Fetch all products from Firebase
      final snapshot = await FirebaseDatabase.instance.ref('products').get();

      if (!snapshot.exists) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products found in database')),
        );
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final products = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        if (value is Map) {
          final product = Map<String, dynamic>.from(value);
          product['id'] = key.toString();
          products.add(product);
        }
      });

      // Create Excel file
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Products'];

      // Define headers in the exact format expected by Excel upload
      final headers = [
        'SKU',
        'Description',
        'Category',
        'Subcategory',
        'Product Type',
        'Price',
        'Voltage',
        'Amperage',
        'Phase',
        'Frequency',
        'Plug Type',
        'Dimensions',
        'Dimensions (Metric)',
        'Weight',
        'Weight (Metric)',
        'Temperature Range',
        'Temperature Range (Metric)',
        'Refrigerant',
        'Compressor',
        'Capacity',
        'Doors',
        'Shelves',
        'Features',
        'Certifications',
        // Warehouse columns
        '999', 'CA', 'CA1', 'CA2', 'CA3', 'CA4',
        'COCZ', 'COPZ', 'INT', 'MEE', 'PU', 'SI',
        'XCA', 'XPU', 'XZRE', 'ZRE',
      ];

      // Add header row
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = excel_lib.TextCellValue(headers[i]);
      }

      // Add data rows
      for (int rowIndex = 0; rowIndex < products.length; rowIndex++) {
        final product = products[rowIndex];
        final dataRow = rowIndex + 1;

        // Helper to get warehouse stock value
        int getWarehouseStock(String warehouseCode) {
          if (product['warehouseStock'] != null && product['warehouseStock'] is Map) {
            final warehouseStock = product['warehouseStock'] as Map;
            if (warehouseStock[warehouseCode] != null && warehouseStock[warehouseCode] is Map) {
              final stockData = warehouseStock[warehouseCode] as Map;
              final available = stockData['available'] ?? 0;
              final reserved = stockData['reserved'] ?? 0;
              return available - reserved;
            }
          }
          return 0;
        }

        final rowData = [
          product['sku']?.toString() ?? '',
          product['description']?.toString() ?? '',
          product['category']?.toString() ?? '',
          product['subcategory']?.toString() ?? '',
          product['productType']?.toString() ?? product['product_type']?.toString() ?? '',
          product['price']?.toString() ?? '',
          product['voltage']?.toString() ?? '',
          product['amperage']?.toString() ?? '',
          product['phase']?.toString() ?? '',
          product['frequency']?.toString() ?? '',
          product['plugType']?.toString() ?? product['plug_type']?.toString() ?? '',
          product['dimensions']?.toString() ?? '',
          product['dimensionsMetric']?.toString() ?? product['dimensions_metric']?.toString() ?? '',
          product['weight']?.toString() ?? '',
          product['weightMetric']?.toString() ?? product['weight_metric']?.toString() ?? '',
          product['temperatureRange']?.toString() ?? product['temperature_range']?.toString() ?? '',
          product['temperatureRangeMetric']?.toString() ?? product['temperature_range_metric']?.toString() ?? '',
          product['refrigerant']?.toString() ?? '',
          product['compressor']?.toString() ?? '',
          product['capacity']?.toString() ?? '',
          product['doors']?.toString() ?? '',
          product['shelves']?.toString() ?? '',
          product['features']?.toString() ?? '',
          product['certifications']?.toString() ?? '',
          // Warehouse stock
          getWarehouseStock('999').toString(),
          getWarehouseStock('CA').toString(),
          getWarehouseStock('CA1').toString(),
          getWarehouseStock('CA2').toString(),
          getWarehouseStock('CA3').toString(),
          getWarehouseStock('CA4').toString(),
          getWarehouseStock('COCZ').toString(),
          getWarehouseStock('COPZ').toString(),
          getWarehouseStock('INT').toString(),
          getWarehouseStock('MEE').toString(),
          getWarehouseStock('PU').toString(),
          getWarehouseStock('SI').toString(),
          getWarehouseStock('XCA').toString(),
          getWarehouseStock('XPU').toString(),
          getWarehouseStock('XZRE').toString(),
          getWarehouseStock('ZRE').toString(),
        ];

        for (int i = 0; i < rowData.length; i++) {
          sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataRow))
              .value = excel_lib.TextCellValue(rowData[i]);
        }
      }

      // Encode to bytes
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      // Download file
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final filename = 'database_export_$timestamp.xlsx';

      DownloadHelper.downloadFile(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database exported successfully! ${products.length} products exported to $filename'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      AppLogger.info('Database exported to Excel', data: {
        'filename': filename,
        'products_count': products.length,
        'user': FirebaseAuth.instance.currentUser?.email,
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export database: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      AppLogger.error('Failed to export database to Excel', error: e, category: LogCategory.database);
    }
  }

  Future<void> _selectAndRestoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          await _restoreFromBytes(file.bytes!, file.name);
        } else {
          _showErrorMessage('Unable to read selected file');
        }
      }
    } catch (e) {
      _showErrorMessage('Failed to select backup file: $e');
    }
  }

  Future<void> _restoreFromBytes(Uint8List bytes, String filename) async {
    // Show confirmation dialog
    final confirmed = await _showRestoreConfirmationDialog(filename);
    if (!confirmed) return;

    await _executeWithRetry(() async {
      setState(() {
        _isRestoringBackup = true;
        _lastBackupError = null;
      });

      try {
        final jsonContent = utf8.decode(bytes);
        final service = ref.read(backupServiceProvider);
        final result = await service.restoreFromBackup(jsonContent);

        if (result.success) {
          _showSuccessMessage(
            'Backup restored successfully! '
            '${result.itemsRestored} items restored from ${result.sectionsRestored.length} sections.'
          );
          ref.invalidate(backupHistoryProvider);
          ref.invalidate(backupStatsProvider);
        } else {
          throw Exception('Restore failed with ${result.errors.length} errors: ${result.errors.join(', ')}');
        }
      } catch (e) {
        setState(() {
          _lastBackupError = 'Failed to restore backup: $e';
        });
        rethrow;
      } finally {
        setState(() => _isRestoringBackup = false);
      }
    });
  }

  Future<void> _downloadBackup(BackupEntry entry) async {
    try {
      _showLoadingDialog('Preparing backup download...');

      final service = ref.read(backupServiceProvider);
      final backup = await service.generateBackup();
      await service.downloadBackup(backup);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSuccessMessage('Backup downloaded successfully (${backup.sizeInMB.toStringAsFixed(2)} MB)');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorMessage('Failed to download backup: $e');
      }
    }
  }

  Future<void> _retryBackup(BackupEntry entry) async {
    // Recreate the backup
    await _createQuickBackup();
  }

  Future<void> _retryLastOperation() async {
    if (_retryCount >= maxRetries) {
      _showErrorMessage('Maximum retry attempts reached. Please try again later.');
      return;
    }

    setState(() {
      _retryCount++;
    });

    // Determine what operation to retry based on current state
    if (_isCreatingBackup) {
      await _createQuickBackup();
    } else if (_isRestoringBackup) {
      // For restore, we need the user to select the file again
      await _selectAndRestoreBackup();
    }
  }

  Future<void> _executeWithRetry(Future<void> Function() operation) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await operation();
        return; // Success, exit retry loop
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow; // Last attempt failed, propagate error
        }

        // Wait before retry with exponential backoff
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        setState(() {
          _retryCount = attempt + 1;
        });

        AppLogger.warning('Operation failed, retrying... (attempt ${attempt + 1}/$maxRetries)', error: e);
      }
    }
  }

  // Dialog and Notification Methods
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<bool> _showRestoreConfirmationDialog(String filename) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to restore from "$filename"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This operation will overwrite existing data. '
                    'Make sure you have a current backup before proceeding.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // Utility Methods
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(2)} MB';
  }

  Color _getStatusColor(BackupStatus status) {
    switch (status) {
      case BackupStatus.completed:
        return Colors.green;
      case BackupStatus.running:
        return Colors.orange;
      case BackupStatus.failed:
        return Colors.red;
      case BackupStatus.pending:
        return Colors.blue;
      case BackupStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(BackupStatus status) {
    switch (status) {
      case BackupStatus.completed:
        return Icons.check_circle;
      case BackupStatus.running:
        return Icons.sync;
      case BackupStatus.failed:
        return Icons.error;
      case BackupStatus.pending:
        return Icons.schedule;
      case BackupStatus.cancelled:
        return Icons.cancel;
    }
  }
}