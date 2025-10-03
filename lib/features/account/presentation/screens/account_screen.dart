// lib/features/account/presentation/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/config/env_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Account Screen - Groups Profile, Settings, and Admin (conditional)
///
/// This screen implements Architecture A's "Account" navigation item,
/// consolidating all user account and app configuration options.
///
/// NN/g Compliance:
/// - Guideline #8: Groups related items logically (all account/system settings)
/// - Guideline #9: Progressive disclosure (admin only visible to admins)
/// - Guideline #7: Clear, familiar labels
/// - Guideline #11: Large touch targets (ListTile with min 56dp height)
/// - Guideline #16: Familiar settings menu pattern
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = ref.watch(currentUserProvider);
    final userProfile = userAsync.valueOrNull;

    // Check admin access using centralized config
    final authState = ref.watch(authStateProvider);
    final userEmail = authState.valueOrNull?.email;
    final isAdmin = userEmail != null && EnvConfig.isSuperAdminEmail(userEmail);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // User Avatar
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      (userProfile?.displayName ?? user?.displayName ?? 'User')
                              .isNotEmpty
                          ? (userProfile?.displayName ??
                                  user?.displayName ??
                                  'User')
                              .substring(0, 1)
                              .toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // User Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProfile?.displayName ??
                              user?.displayName ??
                              'User',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userProfile?.email ?? user?.email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Account Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),

          // Profile Option
          // NN/g Guideline #11: Minimum 56dp touch target
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline, size: 24),
              title: const Text('Profile'),
              subtitle: const Text('Manage your account information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/profile'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Settings Option
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined, size: 24),
              title: const Text('Settings'),
              subtitle: const Text('App preferences and configuration'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),

          // Admin Section (Conditional)
          // NN/g Guideline #9: Progressive disclosure - only shown to admins
          if (isAdmin) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Administration',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Card(
              color: Colors.blue.withValues(alpha: 0.05),
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 24,
                  color: Colors.blue,
                ),
                title: const Text(
                  'Admin Panel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('System administration and management'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  try {
                    // Perform logout - use Firebase Auth directly
                    final signOut = ref.read(signOutProvider);
                    await signOut();

                    // Clear any cached data
                    await FirebaseDatabase.instance.goOffline();
                    await FirebaseDatabase.instance.goOnline();

                    if (context.mounted) {
                      // Navigate to login screen
                      context.go('/auth/login');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error signing out: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // App Version Info
          Center(
            child: Text(
              'Turbo Air Quotes v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
