// Deferred loading for admin features to reduce initial bundle size
import 'package:flutter/material.dart';

// Import admin screens with deferred loading
import '../../features/admin/presentation/screens/admin_panel_screen.dart' deferred as admin_panel;
import '../../features/admin/presentation/screens/performance_dashboard_screen.dart' deferred as perf_dashboard;
import '../../features/admin/presentation/screens/user_info_dashboard_screen.dart' deferred as user_dashboard;
import '../../features/admin/presentation/screens/user_details_screen.dart' deferred as user_details;
import '../../features/admin/presentation/screens/user_detail_screen.dart' deferred as user_detail;
import '../../features/admin/presentation/screens/error_monitoring_dashboard_optimized.dart' deferred as error_dashboard;
import '../../features/admin/presentation/screens/database_management_v2_screen.dart' deferred as db_management;
import '../../features/admin/presentation/screens/monitoring_dashboard_v2_screen.dart' deferred as monitoring;
import '../../features/settings/presentation/screens/backup_management_screen.dart' deferred as backup_mgmt;

class DeferredAdminLoader {
  static bool _adminLoaded = false;
  static bool _isLoading = false;

  static Future<void> loadAdminFeatures() async {
    if (_adminLoaded || _isLoading) return;

    _isLoading = true;
    try {
      await Future.wait([
        admin_panel.loadLibrary(),
        perf_dashboard.loadLibrary(),
        user_dashboard.loadLibrary(),
        user_details.loadLibrary(),
        user_detail.loadLibrary(),
        error_dashboard.loadLibrary(),
        db_management.loadLibrary(),
        monitoring.loadLibrary(),
        backup_mgmt.loadLibrary(),
      ]);
      _adminLoaded = true;
    } finally {
      _isLoading = false;
    }
  }

  static Widget buildAdminPanel() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading Admin Panel...');
    }
    return admin_panel.AdminPanelScreen();
  }

  static Widget buildPerformanceDashboard() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading Performance Dashboard...');
    }
    return perf_dashboard.PerformanceDashboardScreen();
  }

  static Widget buildUserInfoDashboard() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading User Dashboard...');
    }
    return user_dashboard.UserInfoDashboardScreen();
  }

  static Widget buildUserDetailsScreen() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading User Details...');
    }
    // Pass empty parameters as they'll be set by the route
    return user_details.UserDetailsScreen(
      userId: '',
      userEmail: '',
      userName: '',
    );
  }

  static Widget buildUserDetailScreen(String userId) {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading User Detail...');
    }
    // Pass empty parameters as they'll be set by the route
    return user_detail.UserDetailScreen(
      userId: userId,
      userEmail: '',
      displayName: '',
      currentRole: '',
    );
  }

  static Widget buildErrorMonitoring() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading Error Monitoring...');
    }
    return error_dashboard.OptimizedErrorMonitoringDashboard();
  }

  static Widget buildDatabaseManagement() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading Database Management...');
    }
    return db_management.DatabaseManagementV2Screen();
  }

  static Widget buildMonitoringDashboard() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading Monitoring Dashboard...');
    }
    return monitoring.MonitoringDashboardV2Screen();
  }

  static Widget buildBackupManagement() {
    if (!_adminLoaded) {
      return _buildLoadingScreen('Loading Backup Management...');
    }
    return backup_mgmt.BackupManagementScreen();
  }

  static Widget _buildLoadingScreen(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 8),
            const Text(
              'Loading admin features for the first time...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper widget that handles deferred loading
class DeferredAdminScreen extends StatefulWidget {
  final Widget Function() builder;
  final String screenName;

  const DeferredAdminScreen({
    super.key,
    required this.builder,
    required this.screenName,
  });

  @override
  State<DeferredAdminScreen> createState() => _DeferredAdminScreenState();
}

class _DeferredAdminScreenState extends State<DeferredAdminScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdminFeatures();
  }

  Future<void> _loadAdminFeatures() async {
    try {
      await DeferredAdminLoader.loadAdminFeatures();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error loading ${widget.screenName}'),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadAdminFeatures();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading ${widget.screenName}...'),
              const SizedBox(height: 8),
              const Text(
                'This may take a moment on first load',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return widget.builder();
  }
}