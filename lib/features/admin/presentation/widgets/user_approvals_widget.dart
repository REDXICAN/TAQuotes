import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/models/user_approval_request.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Provider for pending user approvals
final pendingUserApprovalsProvider = StreamProvider<List<UserApprovalRequest>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getPendingUserApprovals().map((requests) {
    return requests.map((req) => UserApprovalRequest.fromJson(req)).toList();
  });
});

class UserApprovalsWidget extends ConsumerWidget {
  const UserApprovalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requests = ref.watch(pendingUserApprovalsProvider);

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
                      'Pending User Approvals (${data.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const Spacer(),
                    if (data.length > 5)
                      Text(
                        'Showing first 5',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length > 5 ? 5 : data.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final request = data[index];
                  return _UserApprovalCard(request: request);
                },
              ),
              if (data.length > 5)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+ ${data.length - 5} more pending approvals',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) {
        AppLogger.error('Error loading user approvals', error: error);
        return const SizedBox.shrink();
      },
    );
  }
}

class _UserApprovalCard extends ConsumerStatefulWidget {
  final UserApprovalRequest request;

  const _UserApprovalCard({required this.request});

  @override
  ConsumerState<_UserApprovalCard> createState() => _UserApprovalCardState();
}

class _UserApprovalCardState extends ConsumerState<_UserApprovalCard> {
  bool _isProcessing = false;
  String? _rejectionReason;

  Future<void> _handleApproval() async {
    setState(() => _isProcessing = true);

    try {
      final dbService = ref.read(databaseServiceProvider);
      final currentUser = ref.read(currentUserProvider);
      final emailService = EmailService();

      await dbService.approveUserRequest(
        requestId: widget.request.id,
        approvedBy: currentUser?.email ?? 'superadmin',
      );

      // Send approval notification email to user
      await emailService.sendAdminDecisionEmail(
        userEmail: widget.request.email,
        userName: widget.request.name,
        approved: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access approved for ${widget.request.email} as ${widget.request.displayRole}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error approving user request', error: e);
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
      final emailService = EmailService();

      await dbService.rejectUserRequest(
        requestId: widget.request.id,
        rejectedBy: currentUser?.email ?? 'superadmin',
        reason: _rejectionReason,
      );

      // Send rejection notification email to user
      await emailService.sendAdminDecisionEmail(
        userEmail: widget.request.email,
        userName: widget.request.name,
        approved: false,
        rejectionReason: _rejectionReason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User request rejected for ${widget.request.email}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error rejecting user request', error: e);
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

    // Color code by role type
    final roleColor = _getRoleColor(request.requestedRole);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: roleColor.withOpacity(0.1),
        child: Icon(
          _getRoleIcon(request.requestedRole),
          color: roleColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              request.name,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: roleColor.withOpacity(0.3)),
            ),
            child: Text(
              request.displayRole,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: roleColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.email),
          if (request.company != null && request.company!.isNotEmpty)
            Text('Company: ${request.company}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                _formatTime(request.requestedAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return Colors.red.shade700;
      case 'sales':
        return Colors.blue.shade700;
      case 'distribution':
      case 'distributor':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return Icons.admin_panel_settings;
      case 'sales':
        return Icons.point_of_sale;
      case 'distribution':
      case 'distributor':
        return Icons.local_shipping;
      default:
        return Icons.person;
    }
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
  String _selectedReason = 'Other';

  final List<String> _commonReasons = [
    'Incomplete information',
    'Unauthorized role request',
    'Duplicate account',
    'Company not verified',
    'Other',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject User Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a reason for rejection:'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedReason,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _commonReasons.map((reason) {
              return DropdownMenuItem(value: reason, child: Text(reason));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedReason = value!;
              });
            },
          ),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter specific reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _selectedReason == 'Other'
                ? _controller.text.trim()
                : _selectedReason;
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