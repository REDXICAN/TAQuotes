import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/services/app_logger.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/utils/price_formatter.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userEmail;
  final String displayName;
  final String currentRole;

  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.displayName,
    required this.currentRole,
  });

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _isLoading = true;
  bool _isUpdatingRole = false;
  Map<String, dynamic> _userStats = {};
  String? _selectedNewRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final database = FirebaseDatabase.instance;

      // Load user statistics
      final quotesSnapshot = await database.ref('quotes/${widget.userId}').get();
      int quotesCount = 0;
      double totalRevenue = 0;
      int acceptedQuotes = 0;

      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        quotesCount = quotesData.length;

        for (final quoteEntry in quotesData.values) {
          final quote = Map<String, dynamic>.from(quoteEntry as Map);
          final status = quote['status']?.toString().toLowerCase();

          if (status == 'accepted' || status == 'closed' || status == 'sold') {
            acceptedQuotes++;
            totalRevenue += PriceFormatter.safeToDouble(quote['total']);
          }
        }
      }

      // Load clients count
      final clientsSnapshot = await database.ref('clients/${widget.userId}').get();
      int clientsCount = 0;
      if (clientsSnapshot.exists) {
        final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);
        clientsCount = clientsData.length;
      }

      final conversionRate = quotesCount > 0 ? (acceptedQuotes / quotesCount * 100) : 0.0;

      setState(() {
        _userStats = {
          'quotesCount': quotesCount,
          'totalRevenue': totalRevenue,
          'clientsCount': clientsCount,
          'acceptedQuotes': acceptedQuotes,
          'conversionRate': conversionRate,
        };
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading user data', error: e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String newRole) async {
    // Check if user has permission to change roles
    final currentUserRole = await ref.read(currentUserRoleProvider.future);
    final targetRole = UserRole.fromString(widget.currentRole);
    final newRoleEnum = UserRole.fromString(newRole);

    // Validate permission using role hierarchy
    if (!RoleHierarchy.canManageUser(currentUserRole, targetRole)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to manage this user'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if the user can assign this new role
    final assignableRoles = RoleHierarchy.getAssignableRoles(currentUserRole);
    if (!assignableRoles.contains(newRoleEnum)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You cannot assign ${newRoleEnum.displayName} role'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isUpdatingRole = true);

    try {
      final database = FirebaseDatabase.instance;
      final updates = <String, dynamic>{
        'users/${widget.userId}/role': newRole.toLowerCase(),
        'user_profiles/${widget.userId}/role': newRole.toLowerCase(),
      };

      await database.ref().update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User role updated to ${newRoleEnum.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(); // Go back to user list
      }
    } catch (e) {
      AppLogger.error('Error updating user role', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingRole = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final numberFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.displayName),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header Card
                  _buildUserHeaderCard(theme),
                  const SizedBox(height: 24),

                  // KPI Cards
                  Text(
                    'Performance Metrics',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildKPIGrid(theme, currencyFormat, numberFormat),
                  const SizedBox(height: 32),

                  // Role Management Section (only for superadmins/admins)
                  FutureBuilder<UserRole>(
                    future: ref.read(currentUserRoleProvider.future),
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          (snapshot.data!.isSuperAdmin || snapshot.data!.isAdminOrAbove)) {
                        return _buildRoleManagementSection(theme, snapshot.data!);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUserHeaderCard(ThemeData theme) {
    final roleColor = widget.currentRole == 'superadmin'
        ? Colors.red
        : widget.currentRole == 'admin'
            ? Colors.purple
            : widget.currentRole == 'sales'
                ? Colors.blue
                : Colors.green;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: roleColor.withValues(alpha: 0.2),
              child: Text(
                widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userEmail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      UserRole.fromString(widget.currentRole).displayName,
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIGrid(ThemeData theme, NumberFormat currencyFormat, NumberFormat numberFormat) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildKPICard(
          title: 'Total Revenue',
          value: currencyFormat.format(_userStats['totalRevenue'] ?? 0),
          icon: Icons.attach_money,
          color: Colors.green,
          theme: theme,
        ),
        _buildKPICard(
          title: 'Total Quotes',
          value: numberFormat.format(_userStats['quotesCount'] ?? 0),
          icon: Icons.receipt_long,
          color: Colors.blue,
          theme: theme,
        ),
        _buildKPICard(
          title: 'Total Clients',
          value: numberFormat.format(_userStats['clientsCount'] ?? 0),
          icon: Icons.people,
          color: Colors.orange,
          theme: theme,
        ),
        _buildKPICard(
          title: 'Conversion Rate',
          value: '${(_userStats['conversionRate'] ?? 0).toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: Colors.purple,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleManagementSection(ThemeData theme, UserRole currentUserRole) {
    final assignableRoles = RoleHierarchy.getAssignableRoles(currentUserRole);
    final currentTargetRole = UserRole.fromString(widget.currentRole);

    // Check if current user can manage this target user
    if (!RoleHierarchy.canManageUser(currentUserRole, currentTargetRole)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You do not have permission to manage this user\'s role',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role Management',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Change user role:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedNewRole,
              decoration: const InputDecoration(
                labelText: 'Select New Role',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: assignableRoles.map((role) {
                return DropdownMenuItem(
                  value: role.value,
                  child: Row(
                    children: [
                      Icon(
                        _getRoleIcon(role),
                        color: _getRoleColor(role),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(role.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedNewRole = value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedNewRole == null ||
                           _selectedNewRole == widget.currentRole.toLowerCase() ||
                           _isUpdatingRole
                    ? null
                    : () => _showRoleChangeConfirmation(),
                icon: _isUpdatingRole
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isUpdatingRole ? 'Updating...' : 'Update Role'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.star;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.sales:
        return Icons.trending_up;
      case UserRole.distributor:
        return Icons.local_shipping;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.red;
      case UserRole.admin:
        return Colors.purple;
      case UserRole.sales:
        return Colors.blue;
      case UserRole.distributor:
        return Colors.green;
    }
  }

  void _showRoleChangeConfirmation() {
    final newRoleEnum = UserRole.fromString(_selectedNewRole!);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Role Change'),
        content: Text(
          'Are you sure you want to change ${widget.displayName}\'s role from '
          '${UserRole.fromString(widget.currentRole).displayName} to ${newRoleEnum.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserRole(_selectedNewRole!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
