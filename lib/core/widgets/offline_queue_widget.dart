// lib/core/widgets/offline_status_widget.dart
import 'package:flutter/material.dart';
import '../services/offline_service.dart';

class OfflineStatusWidget extends StatefulWidget {
  final Widget child;

  const OfflineStatusWidget({
    super.key,
    required this.child,
  });

  @override
  State<OfflineStatusWidget> createState() => _OfflineStatusWidgetState();
}

class _OfflineStatusWidgetState extends State<OfflineStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        StreamBuilder<bool>(
          stream: OfflineService.staticConnectionStream,
          initialData: OfflineService.staticIsOnline,
          builder: (context, connectionSnapshot) {
            // Handle service unavailability gracefully
            if (connectionSnapshot.hasError || !OfflineService.isInitialized) {
              return const SizedBox.shrink(); // Hide if service unavailable
            }

            final isOnline = connectionSnapshot.data ?? true;

            return StreamBuilder<List<PendingOperation>>(
              stream: OfflineService.staticQueueStream,
              initialData: OfflineService.staticPendingOperations,
              builder: (context, queueSnapshot) {
                // Handle queue stream errors
                if (queueSnapshot.hasError) {
                  return const SizedBox.shrink();
                }

                final pendingOps = queueSnapshot.data ?? [];

                // Only show if offline or has pending operations
                if (isOnline && pendingOps.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _isExpanded ? null : 48,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? Colors.blue.shade800
                            : Colors.orange.shade900,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMainBar(isOnline, pendingOps.length),
                            if (_isExpanded)
                              _buildExpandedContent(isOnline, pendingOps),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMainBar(bool isOnline, int pendingCount) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Status icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Icon(
                isOnline ? Icons.sync : Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Status text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOnline ? 'Syncing pending changes...' : 'You are offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (pendingCount > 0)
                    Text(
                      '$pendingCount operation${pendingCount > 1 ? 's' : ''} pending',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // Queue indicator badge
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pendingCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Expand/collapse icon
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(
      bool isOnline, List<PendingOperation> operations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection info
          Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isOnline
                    ? 'Connected - Auto-sync enabled'
                    : 'No connection - Changes saved locally',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          if (operations.isNotEmpty) ...[
            const SizedBox(height: 12),

            // Recent operations
            Text(
              'Recent operations:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),

            // Show up to 3 recent operations
            ...operations.take(3).map((op) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      _getOperationIcon(op.operation),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getOperationDescription(op),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),

            if (operations.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${operations.length - 3} more',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ),
          ],

          // Action buttons
          const SizedBox(height: 12),
          Row(
            children: [
              if (isOnline && operations.isNotEmpty)
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        await OfflineService.syncPendingChanges();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sync failed - service unavailable'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Force Sync'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                  ),
                ),
              if (isOnline && operations.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      final cacheInfo = await OfflineService.getCacheInfo();
                      if (context.mounted) {
                        _showCacheInfo(cacheInfo);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showCacheInfo({
                          'error': 'Service unavailable',
                          'status': 'Error'
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Cache Info'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Icon _getOperationIcon(OperationType type) {
    switch (type) {
      case OperationType.create:
        return const Icon(Icons.add_circle_outline,
            color: Colors.white70, size: 14);
      case OperationType.update:
        return const Icon(Icons.edit_outlined, color: Colors.white70, size: 14);
      case OperationType.delete:
        return const Icon(Icons.delete_outline,
            color: Colors.white70, size: 14);
    }
  }

  String _getOperationDescription(PendingOperation op) {
    final action = op.operation.toString().split('.').last;
    final collection = op.collection.replaceAll('_', ' ');
    return '${action[0].toUpperCase()}${action.substring(1)} $collection';
  }

  void _showCacheInfo(Map<String, dynamic> info) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Status', info['is_online'] ? 'Online' : 'Offline'),
            _buildInfoRow(
                'Pending Operations', info['pending_operations'].toString()),
            _buildInfoRow('Last Sync', info['last_sync'] ?? 'Never'),
            _buildInfoRow(
                'Last Cleanup', info['last_cache_cleanup'] ?? 'Never'),
            _buildInfoRow(
                'Active Cache', '${info['active_cache_duration_days']} days'),
            _buildInfoRow('Reference Cache',
                '${info['reference_cache_duration_days']} days'),
          ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }
}

/// Simple connection indicator badge
class ConnectionBadge extends StatelessWidget {
  final bool showWhenOnline;

  const ConnectionBadge({
    super.key,
    this.showWhenOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineService.staticConnectionStream,
      initialData: OfflineService.staticIsOnline,
      builder: (context, snapshot) {
        // Handle service unavailability gracefully
        if (snapshot.hasError || !OfflineService.isInitialized) {
          if (!showWhenOnline) {
            return const SizedBox.shrink();
          }
          // Show a simple "Service N/A" badge
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Service N/A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        final isOnline = snapshot.data ?? true;

        if (isOnline && !showWhenOnline) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<PendingOperation>>(
          stream: OfflineService.staticQueueStream,
          builder: (context, queueSnapshot) {
            // Handle queue stream errors
            if (queueSnapshot.hasError) {
              return const SizedBox.shrink();
            }

            final pendingCount = queueSnapshot.data?.length ?? 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.orange.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pendingCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
