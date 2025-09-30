// lib/features/settings/presentation/screens/app_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/models/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart' hide currentUserRoleProvider;
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/error_demo_data_service.dart';
import '../../../../core/services/spare_parts_demo_service.dart';
import '../../../../core/services/client_demo_data_service.dart';
import '../../../../core/utils/admin_client_checker.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

// Provider for app settings
final appSettingsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseDatabase.instance
      .ref('app_settings/global')
      .onValue
      .map((event) {
    if (event.snapshot.value != null) {
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    }
    return {};
  });
});

// Provider for user preferences
final userPreferencesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value({});

  return FirebaseDatabase.instance
      .ref('app_settings/user_preferences/${user.uid}')
      .onValue
      .map((event) {
    if (event.snapshot.value != null) {
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    }
    return {};
  });
});

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  final _backupScheduleController = TextEditingController();
  final _maintenanceMessageController = TextEditingController();
  final _maxUsersController = TextEditingController();
  final _sessionTimeoutController = TextEditingController();

  bool _maintenanceMode = false;
  bool _autoBackup = true;
  bool _emailNotifications = true;
  bool _darkModeEnabled = false;
  bool _compactView = false;
  String _defaultWarehouse = '999';
  String _defaultCurrency = 'USD';
  int _itemsPerPage = 50;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // Load global settings
      final globalSnapshot = await FirebaseDatabase.instance
          .ref('app_settings/global')
          .once();

      if (globalSnapshot.snapshot.value != null) {
        final globalData = Map<String, dynamic>.from(
            globalSnapshot.snapshot.value as Map);

        setState(() {
          _maintenanceMode = globalData['maintenance_mode'] ?? false;
          _autoBackup = globalData['auto_backup'] ?? true;
          _emailNotifications = globalData['email_notifications'] ?? true;
          _backupScheduleController.text = globalData['backup_schedule'] ?? 'daily';
          _maintenanceMessageController.text = globalData['maintenance_message'] ?? '';
          _maxUsersController.text = (globalData['max_concurrent_users'] ?? 100).toString();
          _sessionTimeoutController.text = (globalData['session_timeout_minutes'] ?? 30).toString();
        });
      }

      // Load user preferences
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final userSnapshot = await FirebaseDatabase.instance
            .ref('app_settings/user_preferences/${user.uid}')
            .once();

        if (userSnapshot.snapshot.value != null) {
          final userData = Map<String, dynamic>.from(
              userSnapshot.snapshot.value as Map);

          setState(() {
            _darkModeEnabled = userData['dark_mode'] ?? false;
            _compactView = userData['compact_view'] ?? false;
            _defaultWarehouse = userData['default_warehouse'] ?? '999';
            _defaultCurrency = userData['default_currency'] ?? 'USD';
            _itemsPerPage = userData['items_per_page'] ?? 50;
          });
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load settings', error: e);
    }
  }

  Future<void> _saveGlobalSettings() async {
    setState(() => _isLoading = true);

    try {
      // Check if user has permission
      final hasPermission = await ref.read(
          hasPermissionProvider(Permission.manageDatabase).future);

      if (!hasPermission) {
        _showError('You do not have permission to modify system settings');
        return;
      }

      final updates = {
        'maintenance_mode': _maintenanceMode,
        'auto_backup': _autoBackup,
        'email_notifications': _emailNotifications,
        'backup_schedule': _backupScheduleController.text,
        'maintenance_message': _maintenanceMessageController.text,
        'max_concurrent_users': int.tryParse(_maxUsersController.text) ?? 100,
        'session_timeout_minutes': int.tryParse(_sessionTimeoutController.text) ?? 30,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': ref.read(currentUserProvider)?.uid,
      };

      await FirebaseDatabase.instance
          .ref('app_settings/global')
          .update(updates);

      AppLogger.info('Global settings updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Global settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save global settings', error: e);
      _showError('Failed to save settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserPreferences() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        _showError('You must be logged in to save preferences');
        return;
      }

      final updates = {
        'dark_mode': _darkModeEnabled,
        'compact_view': _compactView,
        'default_warehouse': _defaultWarehouse,
        'default_currency': _defaultCurrency,
        'items_per_page': _itemsPerPage,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await FirebaseDatabase.instance
          .ref('app_settings/user_preferences/${user.uid}')
          .update(updates);

      AppLogger.info('User preferences updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save user preferences', error: e);
      _showError('Failed to save preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _populateDemoErrors() async {
    setState(() => _isLoading = true);

    try {
      final demoService = ErrorDemoDataService();
      await demoService.populateDemoErrors(numberOfErrors: 50);

      _showSuccess('Successfully generated 50 demo error reports');
      AppLogger.info('Demo error data populated from settings screen', category: LogCategory.system);

    } catch (e) {
      _showError('Failed to populate demo errors: $e');
      AppLogger.error('Failed to populate demo errors from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateTestError() async {
    setState(() => _isLoading = true);

    try {
      final demoService = ErrorDemoDataService();
      await demoService.generateTestError(
        customMessage: 'Test error generated from Settings panel at ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
      );

      _showSuccess('Test error generated successfully');
      AppLogger.info('Test error generated from settings screen', category: LogCategory.system);

    } catch (e) {
      _showError('Failed to generate test error: $e');
      AppLogger.error('Failed to generate test error from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _populateSparePartsData() async {
    setState(() => _isLoading = true);

    try {
      final sparePartsService = SparePartsDemoService();
      await sparePartsService.populateSparePartsData(numberOfParts: 25);

      _showSuccess('Successfully generated 25 spare parts with stock data');
      AppLogger.info('Spare parts demo data populated from settings screen', category: LogCategory.system);

    } catch (e) {
      _showError('Failed to populate spare parts data: $e');
      AppLogger.error('Failed to populate spare parts from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addStockToSpareParts() async {
    setState(() => _isLoading = true);

    try {
      final sparePartsService = SparePartsDemoService();
      await sparePartsService.addStockToExistingSpareParts();

      _showSuccess('Successfully added stock data to existing spare parts');
      AppLogger.info('Stock added to spare parts from settings screen', category: LogCategory.system);

    } catch (e) {
      _showError('Failed to add stock to spare parts: $e');
      AppLogger.error('Failed to add stock to spare parts from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearSparePartsData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Spare Parts Data'),
        content: const Text(
          'This will permanently delete all spare parts and their stock data from the database. '
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final sparePartsService = SparePartsDemoService();
      await sparePartsService.clearSparePartsData();

      _showSuccess('Spare parts demo data cleared successfully');
      AppLogger.info('Spare parts demo data cleared from settings screen', category: LogCategory.system);

    } catch (e) {
      _showError('Failed to clear spare parts data: $e');
      AppLogger.error('Failed to clear spare parts data from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearDemoErrors() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Demo Error Data'),
        content: const Text(
          'This will permanently delete all demo error reports from the database. '
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final demoService = ErrorDemoDataService();
      await demoService.clearDemoErrors();

      _showSuccess('Demo error data cleared successfully');
      AppLogger.info('Demo error data cleared from settings screen', category: LogCategory.system);

    } catch (e) {
      _showError('Failed to clear demo errors: $e');
      AppLogger.error('Failed to clear demo errors from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Client Demo Data Methods
  Future<void> _populateClientDemoData() async {
    setState(() => _isLoading = true);

    try {
      final result = await AdminClientChecker.forcePopulateDemoClients();

      if (result['success']) {
        final clientCount = result['clientCount'] as int;
        final companies = result['companies'] as List<String>;

        _showSuccess('Demo client data populated successfully! Created $clientCount clients.');
        AppLogger.info('Client demo data populated from settings screen',
                       category: LogCategory.system,
                       data: {'clientCount': clientCount, 'companies': companies});
      } else {
        _showError('Failed to populate demo clients: ${result['message']}');
      }

    } catch (e) {
      _showError('Failed to populate demo clients: $e');
      AppLogger.error('Failed to populate demo clients from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearClientDemoData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Demo Client Data'),
        content: const Text(
          'This will permanently delete all demo client data from the database. '
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await AdminClientChecker.clearAdminClients();

      if (result['success']) {
        _showSuccess('Demo client data cleared successfully');
        AppLogger.info('Client demo data cleared from settings screen', category: LogCategory.system);
      } else {
        _showError('Failed to clear demo clients: ${result['message']}');
      }

    } catch (e) {
      _showError('Failed to clear demo clients: $e');
      AppLogger.error('Failed to clear demo clients from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkClientStatus() async {
    setState(() => _isLoading = true);

    try {
      final status = await AdminClientChecker.getAdminClientStatus();

      if (status['success']) {
        final isAdmin = status['isAdmin'] as bool;
        final hasClients = status['hasClients'] as bool? ?? false;
        final clientCount = status['clientCount'] as int? ?? 0;

        if (!isAdmin) {
          _showError('Only admin user can check client status');
          return;
        }

        if (hasClients) {
          _showSuccess('Admin user has $clientCount clients in the database');
        } else {
          _showSuccess('Admin user has no clients. You can populate demo data if needed.');
        }

      } else {
        _showError('Failed to check client status: ${status['message']}');
      }

    } catch (e) {
      _showError('Error checking client status: $e');
      AppLogger.error('Error checking client status from settings', error: e, category: LogCategory.system);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSystemPermission = ref.watch(
        hasPermissionProvider(Permission.manageDatabase));
    final isAdmin = ref.watch(isAdminProvider);
    final userRole = ref.watch(currentUserRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Settings'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Role and Permissions Info Card
            Card(
              color: Theme.of(context).primaryColor.withAlpha(25),
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
                          'Your Role & Permissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    userRole.when(
                      data: (role) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Current Role: '),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(role),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  role.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Level: ${role.level} | ${_getRoleDescription(role)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => Text('Error loading role: $e'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Global System Settings (Admin only)
            hasSystemPermission.when(
              data: (hasPermission) {
                if (!hasPermission) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'These settings affect all users',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Maintenance Mode
                            SwitchListTile(
                              title: const Text('Maintenance Mode'),
                              subtitle: const Text('Temporarily disable access for non-admin users'),
                              value: _maintenanceMode,
                              onChanged: (value) {
                                setState(() => _maintenanceMode = value);
                              },
                              secondary: Icon(
                                Icons.construction,
                                color: _maintenanceMode ? Colors.orange : null,
                              ),
                            ),

                            if (_maintenanceMode) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _maintenanceMessageController,
                                decoration: const InputDecoration(
                                  labelText: 'Maintenance Message',
                                  hintText: 'Message to show users during maintenance',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                            ],

                            const Divider(height: 24),

                            // Auto Backup
                            SwitchListTile(
                              title: const Text('Automatic Backups'),
                              subtitle: const Text('Automatically backup data on schedule'),
                              value: _autoBackup,
                              onChanged: (value) {
                                setState(() => _autoBackup = value);
                              },
                              secondary: const Icon(Icons.backup),
                            ),

                            if (_autoBackup) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _backupScheduleController.text.isEmpty
                                    ? 'daily'
                                    : _backupScheduleController.text,
                                decoration: const InputDecoration(
                                  labelText: 'Backup Schedule',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'hourly',
                                    child: Text('Every Hour'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: Text('Daily'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: Text('Weekly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('Monthly'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _backupScheduleController.text = value ?? 'daily';
                                  });
                                },
                              ),
                            ],

                            const Divider(height: 24),

                            // Email Notifications
                            SwitchListTile(
                              title: const Text('Email Notifications'),
                              subtitle: const Text('Send system emails for important events'),
                              value: _emailNotifications,
                              onChanged: (value) {
                                setState(() => _emailNotifications = value);
                              },
                              secondary: const Icon(Icons.email),
                            ),

                            const Divider(height: 24),

                            // Session Settings
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _sessionTimeoutController,
                                    decoration: const InputDecoration(
                                      labelText: 'Session Timeout (minutes)',
                                      border: OutlineInputBorder(),
                                      helperText: 'Auto-logout after inactivity',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _maxUsersController,
                                    decoration: const InputDecoration(
                                      labelText: 'Max Concurrent Users',
                                      border: OutlineInputBorder(),
                                      helperText: 'Limit simultaneous users',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveGlobalSettings,
                              icon: const Icon(Icons.save),
                              label: const Text('Save System Settings'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => const SizedBox.shrink(),
            ),

            // Error Demo Data Section (Admin only)
            hasSystemPermission.when(
              data: (hasPermission) {
                if (!hasPermission) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error Analytics Demo Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Generate sample error data for testing the error monitoring dashboard',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.bug_report, color: Colors.orange),
                              title: const Text('Generate Demo Errors'),
                              subtitle: const Text('Create 50 realistic error reports for testing'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _populateDemoErrors,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Populate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const Divider(height: 24),

                            ListTile(
                              leading: const Icon(Icons.error_outline, color: Colors.red),
                              title: const Text('Generate Test Error'),
                              subtitle: const Text('Create one test error immediately'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _generateTestError,
                                icon: const Icon(Icons.warning),
                                label: const Text('Test'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const Divider(height: 24),

                            ListTile(
                              leading: const Icon(Icons.clear_all, color: Colors.grey),
                              title: const Text('Clear Demo Data'),
                              subtitle: const Text('Remove all demo error reports'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _clearDemoErrors,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Clear'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Client Demo Data Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Client Demo Data Management',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Generate and manage demo client data for TurboAir equipment company',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),

                            ListTile(
                              leading: const Icon(Icons.people, color: Colors.blue),
                              title: const Text('Check Client Status'),
                              subtitle: const Text('Check if admin user has existing clients'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _checkClientStatus,
                                icon: const Icon(Icons.search),
                                label: const Text('Check'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const Divider(height: 24),

                            ListTile(
                              leading: const Icon(Icons.add_business, color: Colors.green),
                              title: const Text('Generate Demo Clients'),
                              subtitle: const Text('Create 10 realistic TurboAir equipment company clients'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _populateClientDemoData,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Populate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const Divider(height: 24),

                            ListTile(
                              leading: const Icon(Icons.clear_all, color: Colors.red),
                              title: const Text('Clear Client Data'),
                              subtitle: const Text('Remove all client data for admin user'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _clearClientDemoData,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Clear'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Spare Parts Management Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spare Parts Data Management',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Generate and manage spare parts demo data for testing stock management features',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),

                            ListTile(
                              leading: const Icon(Icons.settings, color: Colors.blue),
                              title: const Text('Generate Spare Parts'),
                              subtitle: const Text('Create 25 spare parts with warehouse stock data'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _populateSparePartsData,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Populate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const Divider(height: 24),

                            ListTile(
                              leading: const Icon(Icons.inventory, color: Colors.green),
                              title: const Text('Add Stock Data'),
                              subtitle: const Text('Add warehouse stock to existing spare parts'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _addStockToSpareParts,
                                icon: const Icon(Icons.add_box),
                                label: const Text('Add Stock'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const Divider(height: 24),

                            ListTile(
                              leading: const Icon(Icons.clear_all, color: Colors.red),
                              title: const Text('Clear Spare Parts'),
                              subtitle: const Text('Remove all spare parts and stock data'),
                              trailing: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _clearSparePartsData,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Clear'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),

            // User Preferences
            const Text(
              'Personal Preferences',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'These settings only affect your account',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Dark Mode
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use dark theme throughout the app'),
                      value: _darkModeEnabled,
                      onChanged: (value) {
                        setState(() => _darkModeEnabled = value);
                      },
                      secondary: Icon(
                        _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                      ),
                    ),

                    const Divider(height: 24),

                    // Compact View
                    SwitchListTile(
                      title: const Text('Compact View'),
                      subtitle: const Text('Reduce spacing for more content'),
                      value: _compactView,
                      onChanged: (value) {
                        setState(() => _compactView = value);
                      },
                      secondary: const Icon(Icons.view_compact),
                    ),

                    const Divider(height: 24),

                    // Default Warehouse
                    DropdownButtonFormField<String>(
                      value: _defaultWarehouse,
                      decoration: const InputDecoration(
                        labelText: 'Default Warehouse',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '999', child: Text('999 - Reserved (Pending Deals)')),
                        DropdownMenuItem(value: 'CA', child: Text('CA - California')),
                        DropdownMenuItem(value: 'CA1', child: Text('CA1 - California 1')),
                        DropdownMenuItem(value: 'CA2', child: Text('CA2 - California 2')),
                        DropdownMenuItem(value: 'CA3', child: Text('CA3 - California 3')),
                        DropdownMenuItem(value: 'CA4', child: Text('CA4 - California 4')),
                        DropdownMenuItem(value: 'COCZ', child: Text('COCZ - Coahuila')),
                        DropdownMenuItem(value: 'COPZ', child: Text('COPZ - Copilco')),
                        DropdownMenuItem(value: 'INT', child: Text('INT - International')),
                        DropdownMenuItem(value: 'MEE', child: Text('MEE - Mexico East')),
                        DropdownMenuItem(value: 'PU', child: Text('PU - Puebla')),
                        DropdownMenuItem(value: 'SI', child: Text('SI - Sinaloa')),
                        DropdownMenuItem(value: 'XCA', child: Text('XCA - Xcaret')),
                        DropdownMenuItem(value: 'XPU', child: Text('XPU - Xpujil')),
                        DropdownMenuItem(value: 'XZRE', child: Text('XZRE - Xochimilco')),
                        DropdownMenuItem(value: 'ZRE', child: Text('ZRE - Zacatecas')),
                      ],
                      onChanged: (value) {
                        setState(() => _defaultWarehouse = value ?? '999');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Default Currency
                    DropdownButtonFormField<String>(
                      value: _defaultCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Default Currency',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar')),
                        DropdownMenuItem(value: 'MXN', child: Text('MXN - Mexican Peso')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                        DropdownMenuItem(value: 'CAD', child: Text('CAD - Canadian Dollar')),
                      ],
                      onChanged: (value) {
                        setState(() => _defaultCurrency = value ?? 'USD');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Items Per Page
                    DropdownButtonFormField<int>(
                      value: _itemsPerPage,
                      decoration: const InputDecoration(
                        labelText: 'Items Per Page',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: (value) {
                        setState(() => _itemsPerPage = value ?? 50);
                      },
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveUserPreferences,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Preferences'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Backup Management Section (All Users)
            _buildBackupManagementSection(),
            const SizedBox(height: 24),

            // Permission Details Section
            isAdmin.when(
              data: (isAdminUser) {
                if (!isAdminUser) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permission Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Your current permissions',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildPermissionsGrid(),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsGrid() {
    final permissions = ref.watch(currentUserPermissionsProvider);

    return permissions.when(
      data: (userPermissions) {
        final categories = <String, List<Permission>>{};

        // Group permissions by category
        for (final permission in userPermissions) {
          final category = _getPermissionCategory(permission);
          categories.putIfAbsent(category, () => []).add(permission);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: categories.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((permission) {
                      return Chip(
                        label: Text(
                          _formatPermissionName(permission.value),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Theme.of(context).primaryColor.withAlpha(50),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error loading permissions: $e'),
    );
  }

  String _getPermissionCategory(Permission permission) {
    final name = permission.value;
    if (name.contains('product')) return 'Products';
    if (name.contains('client')) return 'Clients';
    if (name.contains('quote')) return 'Quotes';
    if (name.contains('project')) return 'Projects';
    if (name.contains('user') || name.contains('role')) return 'User Management';
    if (name.contains('admin') || name.contains('system')) return 'System';
    if (name.contains('warehouse')) return 'Warehouse';
    if (name.contains('backup')) return 'Backup';
    if (name.contains('email')) return 'Communication';
    return 'Other';
  }

  String _formatPermissionName(String permission) {
    return permission
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.red;
      case UserRole.admin:
        return Colors.orange;
      case UserRole.sales:
        return Colors.blue;
      case UserRole.distributor:
        return Colors.green;
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Full system access with all permissions';
      case UserRole.admin:
        return 'Administrative access with user management';
      case UserRole.sales:
        return 'Sales operations and client management';
      case UserRole.distributor:
        return 'Basic access for distribution operations';
    }
  }

  Widget _buildBackupManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'Backup and restore your data',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup, color: Colors.blue),
                  title: const Text('Backup Management'),
                  subtitle: const Text('Create, download, and restore data backups'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Secure',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.go('/settings/backup');
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 24),

                // Backup Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What gets backed up?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• Your quotes and client data (always included)',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              '• Product catalog (admins only)',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              '• User accounts and system data (superadmin only)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _backupScheduleController.dispose();
    _maintenanceMessageController.dispose();
    _maxUsersController.dispose();
    _sessionTimeoutController.dispose();
    super.dispose();
  }
}