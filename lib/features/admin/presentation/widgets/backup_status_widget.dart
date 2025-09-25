import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/backup_service.dart';

// Provider for backup service
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

// Stream provider for backup entries
final backupEntriesProvider = StreamProvider<List<BackupEntry>>((ref) {
  final service = ref.watch(backupServiceProvider);
  return service.getBackupHistory(limit: 10);
});

// Auto-refreshing provider for backup statistics
final backupStatsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final service = ref.watch(backupServiceProvider);

  // Initial load
  yield await service.getBackupStats();

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await service.getBackupStats();
    } catch (e) {
      // Continue with previous data on error, don't break the stream
      // Use a default empty stats map to prevent UI breaks
      yield <String, dynamic>{
        'totalBackups': 0,
        'completedBackups': 0,
        'failedBackups': 0,
        'totalSize': 0,
      };
    }
  }
});

class BackupStatusWidget extends ConsumerStatefulWidget {
  const BackupStatusWidget({super.key});

  @override
  ConsumerState<BackupStatusWidget> createState() => _BackupStatusWidgetState();
}

class _BackupStatusWidgetState extends ConsumerState<BackupStatusWidget> {
  bool _isCreatingBackup = false;

  Future<void> _createManualBackup() async {
    setState(() {
      _isCreatingBackup = true;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.createManualBackup(
        metadata: {
          'source': 'admin_panel',
          'manual': true,
          'created_from': 'backup_status_widget',
        },
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Backup created successfully! Size: ${_formatFileSize(result.fileSize ?? 0)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the providers
          ref.invalidate(backupEntriesProvider);
          ref.invalidate(backupStatsProvider);
        }
      } else {
        throw Exception(result.error ?? 'Backup failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBackup = false;
        });
      }
    }
  }

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

  IconData _getTypeIcon(BackupType type) {
    switch (type) {
      case BackupType.manual:
        return Icons.person;
      case BackupType.scheduled:
        return Icons.schedule;
      case BackupType.emergency:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backupsAsync = ref.watch(backupEntriesProvider);
    final statsAsync = ref.watch(backupStatsProvider);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and action button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.backup,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Backup Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        ref.invalidate(backupEntriesProvider);
                        ref.invalidate(backupStatsProvider);
                      },
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 8),
                    // Create backup button
                    ElevatedButton.icon(
                      onPressed: _isCreatingBackup ? null : _createManualBackup,
                      icon: _isCreatingBackup
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add_circle),
                      label: Text(_isCreatingBackup ? 'Creating...' : 'Create Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Statistics cards
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  _buildStatCard(
                    'Total Backups',
                    stats['totalBackups']?.toString() ?? '0',
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Successful',
                    stats['completedBackups']?.toString() ?? '0',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Failed',
                    stats['failedBackups']?.toString() ?? '0',
                    Icons.error,
                    Colors.red,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Total Size',
                    _formatFileSize(stats['totalSize'] ?? 0),
                    Icons.storage,
                    Colors.purple,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error loading stats: $error'),
            ),
            const SizedBox(height: 20),

            // Backup schedule info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automatic Backup Schedule',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Backups run automatically every 12 hours',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Old backups are automatically deleted after 15 days',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent backups list
            const Text(
              'Recent Backups',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            backupsAsync.when(
              data: (backups) {
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(backup.status).withOpacity(0.2),
                          child: Icon(
                            _getTypeIcon(backup.type),
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
                                color: _getStatusColor(backup.status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(backup.status),
                                    size: 12,
                                    color: _getStatusColor(backup.status),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    backup.status.toString().split('.').last,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _getStatusColor(backup.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (backup.fileSize != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatFileSize(backup.fileSize!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
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
                            if (backup.completedAt != null)
                              Text(
                                'Completed: ${dateFormat.format(backup.completedAt!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (backup.error != null)
                              Text(
                                'Error: ${backup.error}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                        trailing: backup.downloadUrl != null
                            ? IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () async {
                                  // Download the backup
                                  try {
                                    // Show loading indicator
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    // Generate and download backup
                                    final backupService = BackupService();
                                    final backupData = await backupService.generateBackup();
                                    await backupService.downloadBackup(backupData);

                                    // Close loading dialog
                                    if (context.mounted) {
                                      Navigator.of(context).pop();

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Backup downloaded successfully (${backupData.sizeInMB} MB)'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Close loading dialog
                                    if (context.mounted) {
                                      Navigator.of(context).pop();

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to download backup: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                tooltip: 'Download Backup',
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Error loading backups: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }
}