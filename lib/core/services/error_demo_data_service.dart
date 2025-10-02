// lib/core/services/error_demo_data_service.dart
// Service to populate demo error data for testing error monitoring dashboard

import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'error_monitoring_service.dart';
import 'app_logger.dart';

class ErrorDemoDataService {
  static final ErrorDemoDataService _instance = ErrorDemoDataService._internal();
  factory ErrorDemoDataService() => _instance;
  ErrorDemoDataService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  // Auth and random kept for potential future error simulation features
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ignore: unused_field
  final Random _random = Random();

  // Sample error messages by category
  static const Map<ErrorCategory, List<String>> _sampleErrors = {
    ErrorCategory.authentication: [
      'User session expired while accessing admin panel',
      'Invalid credentials provided during login attempt',
      'Firebase authentication token refresh failed',
      'Permission denied: User lacks admin privileges',
      'Two-factor authentication verification failed',
    ],
    ErrorCategory.database: [
      'Failed to save client data to Firebase',
      'Database connection timeout during product fetch',
      'Quote data synchronization failed',
      'Firebase permission denied for user data write',
      'Database index out of bounds error',
      'Failed to delete quote record from database',
    ],
    ErrorCategory.network: [
      'API request timeout while loading products',
      'Failed to connect to Firebase services',
      'Network error during image upload',
      'Email service connection failed',
      'PDF generation service unavailable',
      'Excel export API request failed',
    ],
    ErrorCategory.ui: [
      'Widget rendering failed in quote detail screen',
      'Layout overflow in product list view',
      'Theme switching caused UI inconsistency',
      'Navigation state corruption in admin panel',
      'Image widget failed to load product thumbnail',
    ],
    ErrorCategory.businessLogic: [
      'Quote calculation error: Invalid discount amount',
      'Client validation failed: Missing required fields',
      'Product price calculation returned negative value',
      'Stock quantity validation error',
      'Currency conversion calculation failed',
    ],
    ErrorCategory.performance: [
      'Product list loading exceeded 5 second threshold',
      'Memory usage spike detected during Excel export',
      'UI freeze during large quote generation',
      'Database query performance degraded',
      'Image loading causing UI lag',
    ],
    ErrorCategory.security: [
      'Suspicious login attempt detected',
      'Rate limit exceeded for API endpoint',
      'Potential SQL injection attempt blocked',
      'Unauthorized access attempt to admin features',
      'CSRF token validation failed',
    ],
    ErrorCategory.unknown: [
      'Unexpected error occurred during operation',
      'Unknown exception caught in error handler',
      'Undefined behavior in async operation',
      'Unhandled promise rejection',
    ],
  };

  // Sample screen names
  static const List<String> _sampleScreens = [
    'ProductsScreen',
    'QuoteDetailScreen',
    'ClientsScreen',
    'CartScreen',
    'AdminPanelScreen',
    'LoginScreen',
    'PerformanceDashboard',
    'ErrorMonitoringDashboard',
    'StockDashboard',
    'UserInfoDashboard',
    'DatabaseManagementScreen',
  ];

  // Sample actions
  static const List<String> _sampleActions = [
    'load_products',
    'save_quote',
    'login_user',
    'export_excel',
    'generate_pdf',
    'send_email',
    'update_client',
    'delete_quote',
    'search_products',
    'calculate_total',
    'upload_image',
    'sync_data',
  ];

  // Sample user emails for demo
  static const List<String> _demoUsers = [
    'carlos.rodriguez@turboairmexico.com',
    'maria.gonzalez@turboairmexico.com',
    'juan.martinez@turboairmexico.com',
    'ana.lopez@turboairmexico.com',
    'pedro.sanchez@turboairmexico.com',
    'luis.hernandez@turboairmexico.com',
    'sofia.ramirez@turboairmexico.com',
    'diego.torres@turboairmexico.com',
    'isabella.flores@turboairmexico.com',
    'miguel.castro@turboairmexico.com',
  ];

  /// Generate realistic demo error data
  Future<void> populateDemoErrors({int numberOfErrors = 50}) async {
    try {
      AppLogger.info('Starting demo error data population', category: LogCategory.system);

      final errors = <ErrorReport>[];
      final now = DateTime.now();

      for (int i = 0; i < numberOfErrors; i++) {
        // Random category and corresponding error message
        final category = ErrorCategory.values[_random.nextInt(ErrorCategory.values.length)];
        final categoryMessages = _sampleErrors[category]!;
        final message = categoryMessages[_random.nextInt(categoryMessages.length)];

        // Random severity with weighted distribution
        final severity = _getRandomSeverity();

        // Random timestamp within last 30 days
        final daysAgo = _random.nextInt(30);
        final hoursAgo = _random.nextInt(24);
        final minutesAgo = _random.nextInt(60);
        final timestamp = now.subtract(Duration(
          days: daysAgo,
          hours: hoursAgo,
          minutes: minutesAgo,
        ));

        // Random screen and action
        final screen = _sampleScreens[_random.nextInt(_sampleScreens.length)];
        final action = _sampleActions[_random.nextInt(_sampleActions.length)];

        // Random user
        final userEmail = _demoUsers[_random.nextInt(_demoUsers.length)];

        // Generate fake user ID
        final userId = 'demo_user_${_random.nextInt(1000)}';

        // Random resolution status (70% unresolved for realism)
        final isResolved = _random.nextDouble() < 0.3;
        final resolvedBy = isResolved ? 'andres@turboairmexico.com' : null;
        final resolvedAt = isResolved
            ? timestamp.add(Duration(hours: _random.nextInt(48)))
            : null;

        // Generate stack trace for some errors
        final includeStackTrace = _random.nextDouble() < 0.4;
        final stackTrace = includeStackTrace ? _generateFakeStackTrace(message, screen) : null;

        // Create error ID
        final errorId = _db.ref().push().key!;

        // Create error report
        final error = ErrorReport(
          id: errorId,
          message: message,
          stackTrace: stackTrace,
          severity: severity,
          category: category,
          timestamp: timestamp,
          userId: userId,
          userEmail: userEmail,
          screen: screen,
          action: action,
          resolved: isResolved,
          resolvedBy: resolvedBy,
          resolvedAt: resolvedAt,
          context: _generateContextData(category, screen, action),
          metadata: _generateMetadata(category, severity),
        );

        errors.add(error);
      }

      // Save all errors to Firebase
      AppLogger.info('Saving ${errors.length} demo errors to Firebase', category: LogCategory.system);

      for (final error in errors) {
        await _db.ref('errors/${error.id}').set(error.toMap());

        // Also save to user-specific path
        if (error.userId != null) {
          await _db.ref('user_errors/${error.userId}/${error.id}').set({
            'errorId': error.id,
            'timestamp': error.timestamp.millisecondsSinceEpoch,
            'severity': error.severity.toString().split('.').last,
            'message': error.message,
          });
        }

        // Add critical alerts for critical errors
        if (error.severity == ErrorSeverity.critical && !error.resolved) {
          await _db.ref('critical_alerts/${error.id}').set({
            'errorId': error.id,
            'message': error.message,
            'timestamp': error.timestamp.millisecondsSinceEpoch,
            'userEmail': error.userEmail,
            'screen': error.screen,
            'action': error.action,
            'notified': false,
          });
        }
      }

      AppLogger.info('Successfully populated ${errors.length} demo errors', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to populate demo error data', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Clear all demo error data
  Future<void> clearDemoErrors() async {
    try {
      AppLogger.info('Clearing demo error data', category: LogCategory.system);

      // Clear main errors
      await _db.ref('errors').remove();

      // Clear user errors
      await _db.ref('user_errors').remove();

      // Clear critical alerts
      await _db.ref('critical_alerts').remove();

      AppLogger.info('Demo error data cleared successfully', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to clear demo error data', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Generate fake error for immediate testing
  Future<void> generateTestError({
    ErrorSeverity? severity,
    ErrorCategory? category,
    String? customMessage,
  }) async {
    try {
      final errorService = ErrorMonitoringService();

      final testSeverity = severity ?? ErrorSeverity.high;
      final testCategory = category ?? ErrorCategory.businessLogic;
      final message = customMessage ?? 'Test error generated for dashboard verification';

      await errorService.captureError(
        error: Exception(message),
        severity: testSeverity,
        category: testCategory,
        screen: 'ErrorMonitoringDashboard',
        action: 'test_error_generation',
        context: {
          'test_mode': true,
          'generated_at': DateTime.now().toIso8601String(),
          'purpose': 'dashboard_testing',
        },
      );

      AppLogger.info('Test error generated successfully', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to generate test error', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  // Private helper methods

  ErrorSeverity _getRandomSeverity() {
    // Weighted distribution: Low 40%, Medium 30%, High 20%, Critical 10%
    final random = _random.nextDouble();
    if (random < 0.4) return ErrorSeverity.low;
    if (random < 0.7) return ErrorSeverity.medium;
    if (random < 0.9) return ErrorSeverity.high;
    return ErrorSeverity.critical;
  }

  String _generateFakeStackTrace(String message, String screen) {
    return '''
Exception: $message
    at $screen.build ($screen.dart:42:15)
    at StatefulWidget.createElement (framework.dart:4569:7)
    at Element.inflateWidget (framework.dart:3617:40)
    at Element.updateChild (framework.dart:3371:18)
    at SingleChildRenderObjectElement.update (framework.dart:6043:14)
    at Element.updateChild (framework.dart:3359:15)
    at RenderObjectToWidgetElement._rebuild (binding.dart:1198:16)
    at WidgetsBinding.drawFrame (binding.dart:884:19)
    at RendererBinding._handlePersistentFrameCallback (binding.dart:320:5)
    at SchedulerBinding._invokeFrameCallback (binding.dart:1144:15)
''';
  }

  Map<String, dynamic> _generateContextData(ErrorCategory category, String screen, String action) {
    switch (category) {
      case ErrorCategory.authentication:
        return {
          'login_attempt': _random.nextInt(5) + 1,
          'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'ip_address': '192.168.1.${_random.nextInt(255)}',
        };
      case ErrorCategory.database:
        return {
          'operation': action,
          'collection': 'quotes',
          'record_id': 'rec_${_random.nextInt(1000)}',
          'retry_count': _random.nextInt(3),
        };
      case ErrorCategory.network:
        return {
          'endpoint': '/api/v1/$action',
          'status_code': [400, 404, 500, 503][_random.nextInt(4)],
          'response_time': _random.nextInt(5000) + 1000,
        };
      case ErrorCategory.performance:
        return {
          'operation_duration': _random.nextInt(8000) + 2000,
          'memory_usage': _random.nextInt(500) + 100,
          'cpu_usage': _random.nextInt(80) + 20,
        };
      default:
        return {
          'screen': screen,
          'action': action,
          'timestamp': DateTime.now().toIso8601String(),
        };
    }
  }

  Map<String, dynamic> _generateMetadata(ErrorCategory category, ErrorSeverity severity) {
    return {
      'environment': 'production',
      'app_version': '1.0.0',
      'platform': 'web',
      'severity_numeric': severity.index,
      'category_code': category.toString().split('.').last,
      'auto_generated': true,
      'demo_data': true,
    };
  }
}