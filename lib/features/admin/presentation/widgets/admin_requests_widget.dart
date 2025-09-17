import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/realtime_database_service.dart';
import '../../../../core/models/admin_request.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Provider for pending admin requests
final pendingAdminRequestsProvider = StreamProvider<List<AdminRequest>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getPendingAdminRequests().map((requests) {
    return requests.map((req) => AdminRequest.fromJson(req)).toList();
  });
});

class AdminRequestsWidget extends ConsumerWidget {
  const AdminRequestsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requests = ref.watch(pendingAdminRequestsProvider);

    return requests.when(
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 4,
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notification_important, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Pending Admin Requests (${data.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final request = data[index];
                  return _AdminRequestCard(request: request);
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) {
        AppLogger.error('Error loading admin requests', error: error);
        return const SizedBox.shrink();
      },
    );
  }
}

class _AdminRequestCard extends ConsumerStatefulWidget {
  final AdminRequest request;

  const _AdminRequestCard({required this.request});

  @override
  ConsumerState<_AdminRequestCard> createState() => _AdminRequestCardState();
}

class _AdminRequestCardState extends ConsumerState<_AdminRequestCard> {
  bool _isProcessing = false;
  String? _rejectionReason;

  Future<void> _handleApproval() async {
    setState(() => _isProcessing = true);

    try {
      final dbService = ref.read(databaseServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      await dbService.approveAdminRequest(
        requestId: widget.request.id,
        approvedBy: currentUser?.email ?? 'superadmin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin access approved for ${widget.request.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error approving admin request', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRejection() async {
    // Show rejection dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectionDialog(),
    );

    if (reason == null) return;

    setState(() {
      _isProcessing = true;
      _rejectionReason = reason;
    });

    try {
      final dbService = ref.read(databaseServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      await dbService.rejectAdminRequest(
        requestId: widget.request.id,
        rejectedBy: currentUser?.email ?? 'superadmin',
        reason: _rejectionReason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin request rejected for ${widget.request.email}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error rejecting admin request', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        child: Icon(Icons.person_add, color: theme.primaryColor),
      ),
      title: Text(
        request.name,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.email),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                _formatTime(request.requestedAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.requestedRole.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: _isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle),
                  color: Colors.green,
                  tooltip: 'Approve',
                  onPressed: _handleApproval,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  color: Colors.red,
                  tooltip: 'Reject',
                  onPressed: _handleRejection,
                ),
              ],
            ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _RejectionDialog extends StatefulWidget {
  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Admin Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for rejecting this request:'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter rejection reason...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isNotEmpty) {
              Navigator.pop(context, reason);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}