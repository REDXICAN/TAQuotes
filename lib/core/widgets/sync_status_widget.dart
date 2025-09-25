// lib/core/widgets/sync_status_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/sync_provider.dart';
import '../services/sync_service.dart';
import '../services/offline_service.dart';

/// Widget to display sync status and trigger manual sync
class SyncStatusWidget extends ConsumerWidget {
  final bool showDetails;
  final bool compact;

  const SyncStatusWidget({
    Key? key,
    this.showDetails = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncProgress = ref.watch(syncProgressProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final conflicts = ref.watch(syncConflictsProvider);
    final isSyncNeeded = ref.watch(isSyncNeededProvider);

    if (compact) {
      return _buildCompactView(context, ref, theme, syncProgress, lastSyncTime, isSyncNeeded);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data Synchronization',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildSyncButton(context, ref, syncProgress.valueOrNull),
              ],
            ),
            const SizedBox(height: 16),

            // Sync progress indicator
            syncProgress.when(
              data: (progress) => _buildProgressIndicator(progress, theme),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Error: $error',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

            if (showDetails) ...[
              const SizedBox(height: 16),
              _buildSyncDetails(theme, lastSyncTime, conflicts),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AsyncValue<SyncProgress> syncProgress,
    DateTime? lastSyncTime,
    bool isSyncNeeded,
  ) {
    final status = syncProgress.valueOrNull?.status ?? SyncStatus.idle;

    return InkWell(
      onTap: () => _showSyncDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor(status, theme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor(status, theme),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getStatusIcon(status),
            const SizedBox(width: 8),
            Text(
              _getStatusText(status, lastSyncTime),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getStatusColor(status, theme),
              ),
            ),
            if (isSyncNeeded) ...[
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(SyncProgress progress, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _getStatusIcon(progress.status),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress.message,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${(progress.progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.progress,
          backgroundColor: theme.dividerColor,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getStatusColor(progress.status, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton(
    BuildContext context,
    WidgetRef ref,
    SyncProgress? currentProgress,
  ) {
    final isSyncing = currentProgress?.status == SyncStatus.syncing;

    return ElevatedButton.icon(
      onPressed: isSyncing
          ? null
          : () async {
              final triggerSync = ref.read(triggerSyncProvider);
              final result = await triggerSync();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
      icon: isSyncing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync, size: 20),
      label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
    );
  }

  Widget _buildSyncDetails(
    ThemeData theme,
    DateTime? lastSyncTime,
    List<SyncConflict> conflicts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Last Sync:',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              lastSyncTime != null
                  ? DateFormat('MMM dd, HH:mm').format(lastSyncTime)
                  : 'Never',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<int>(
          future: OfflineService.staticGetSyncQueueCount(),
          builder: (context, snapshot) {
            final queueCount = snapshot.data ?? 0;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Operations:',
                  style: theme.textTheme.bodySmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: queueCount > 0 ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    queueCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (conflicts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conflicts:',
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => _showConflictsDialog(context, conflicts),
                child: Text(
                  '${conflicts.length} conflicts',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showSyncDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Synchronization'),
        content: SyncStatusWidget(
          showDetails: true,
          compact: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConflictsDialog(BuildContext context, List<SyncConflict> conflicts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Conflicts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: conflicts.map((conflict) {
              return ListTile(
                leading: Icon(
                  Icons.warning,
                  color: Colors.orange,
                ),
                title: Text('${conflict.collection} - ${conflict.itemId}'),
                subtitle: Text(conflict.message),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return const Icon(Icons.cloud_done, size: 20, color: Colors.grey);
      case SyncStatus.syncing:
        return const Icon(Icons.sync, size: 20, color: Colors.blue);
      case SyncStatus.success:
        return const Icon(Icons.check_circle, size: 20, color: Colors.green);
      case SyncStatus.error:
        return const Icon(Icons.error, size: 20, color: Colors.red);
    }
  }

  Color _getStatusColor(SyncStatus status, ThemeData theme) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return theme.colorScheme.error;
    }
  }

  String _getStatusText(SyncStatus status, DateTime? lastSyncTime) {
    switch (status) {
      case SyncStatus.idle:
        if (lastSyncTime != null) {
          final diff = DateTime.now().difference(lastSyncTime);
          if (diff.inMinutes < 1) {
            return 'Synced just now';
          } else if (diff.inMinutes < 60) {
            return 'Synced ${diff.inMinutes}m ago';
          } else if (diff.inHours < 24) {
            return 'Synced ${diff.inHours}h ago';
          } else {
            return 'Synced ${diff.inDays}d ago';
          }
        }
        return 'Not synced';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Sync complete';
      case SyncStatus.error:
        return 'Sync failed';
    }
  }
}