import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'app_logger.dart';
import '../utils/safe_type_converter.dart';

enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

enum ErrorCategory {
  authentication,
  database,
  network,
  ui,
  businessLogic,
  performance,
  security,
  unknown,
}

class ErrorReport {
  final String id;
  final String message;
  final String? stackTrace;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final DateTime timestamp;
  final String? userId;
  final String? userEmail;
  final Map<String, dynamic> context;
  final String? screen;
  final String? action;
  final bool resolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final Map<String, dynamic>? metadata;

  // Convenience getter for resolved status
  bool get isResolved => resolved;

  ErrorReport({
    required this.id,
    required this.message,
    this.stackTrace,
    required this.severity,
    required this.category,
    required this.timestamp,
    this.userId,
    this.userEmail,
    this.context = const {},
    this.screen,
    this.action,
    this.resolved = false,
    this.resolvedBy,
    this.resolvedAt,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'stackTrace': stackTrace,
      'severity': severity.toString().split('.').last,
      'category': category.toString().split('.').last,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'timestampIso': timestamp.toIso8601String(),
      'userId': userId,
      'userEmail': userEmail,
      'context': context,
      'screen': screen,
      'action': action,
      'resolved': resolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      'resolvedAtIso': resolvedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ErrorReport.fromMap(Map<String, dynamic> map) {
    return ErrorReport(
      id: map['id'] ?? '',
      message: map['message'] ?? '',
      stackTrace: map['stackTrace'],
      severity: ErrorSeverity.values.firstWhere(
        (e) => e.toString().split('.').last == map['severity'],
        orElse: () => ErrorSeverity.low,
      ),
      category: ErrorCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => ErrorCategory.unknown,
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      userId: map['userId'],
      userEmail: map['userEmail'],
      context: map['context'] != null
          ? SafeTypeConverter.toMap(map['context'])
          : {},
      screen: map['screen'],
      action: map['action'],
      resolved: map['resolved'] ?? false,
      resolvedBy: map['resolvedBy'],
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['resolvedAt'])
          : null,
      metadata: map['metadata'] != null
          ? SafeTypeConverter.toMap(map['metadata'])
          : null,
    );
  }
}

class ErrorStatistics {
  final int totalErrors;
  final int criticalErrors;
  final int highErrors;
  final int mediumErrors;
  final int lowErrors;
  final Map<String, int> errorsByCategory;
  final Map<String, int> errorsByScreen;
  final List<String> topErrorMessages;
  final double errorRate; // Errors per hour
  final int unresolvedErrors;

  ErrorStatistics({
    required this.totalErrors,
    required this.criticalErrors,
    required this.highErrors,
    required this.mediumErrors,
    required this.lowErrors,
    required this.errorsByCategory,
    required this.errorsByScreen,
    required this.topErrorMessages,
    required this.errorRate,
    required this.unresolvedErrors,
  });
}

class ErrorMonitoringService {
  static final ErrorMonitoringService _instance = ErrorMonitoringService._internal();
  factory ErrorMonitoringService() => _instance;
  ErrorMonitoringService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory cache for recent errors
  final List<ErrorReport> _recentErrors = [];
  static const int _maxCachedErrors = 100;

  // Error rate limiting
  final Map<String, DateTime> _lastErrorTime = {};
  static const Duration _errorThrottleDuration = Duration(seconds: 5);

  // Listeners
  final _errorStreamController = StreamController<ErrorReport>.broadcast();
  Stream<ErrorReport> get errorStream => _errorStreamController.stream;

  String? get userId => _auth.currentUser?.uid;
  String? get userEmail => _auth.currentUser?.email;

  // Initialize error monitoring
  Future<void> initialize() async {
    try {
      // Set up Flutter error handler
      FlutterError.onError = (FlutterErrorDetails details) {
        captureFlutterError(details);
      };

      // Set up zone error handler for async errors
      runZonedGuarded(() {
        // App runs here
      }, (error, stack) {
        captureError(
          error: error,
          stackTrace: stack,
          category: ErrorCategory.unknown,
        );
      });

      AppLogger.info('Error monitoring service initialized', category: LogCategory.system);
    } catch (e) {
      AppLogger.error('Failed to initialize error monitoring', error: e, category: LogCategory.system);
    }
  }

  // Capture Flutter framework errors
  void captureFlutterError(FlutterErrorDetails details) {
    final severity = _determineSeverity(details.exception);
    final category = _determineCategory(details.exception);

    captureError(
      error: details.exception,
      stackTrace: details.stack,
      severity: severity,
      category: category,
      context: {
        'library': details.library,
        'silent': details.silent,
        'context': details.context?.toString(),
      },
    );
  }

  // Main error capture method
  Future<void> captureError({
    required dynamic error,
    StackTrace? stackTrace,
    ErrorSeverity? severity,
    ErrorCategory? category,
    String? screen,
    String? action,
    Map<String, dynamic>? context,
  }) async {
    try {
      final errorMessage = error.toString();

      // Check for error throttling
      if (_shouldThrottle(errorMessage)) {
        return;
      }

      final errorId = _db.ref().push().key!;
      final now = DateTime.now();

      final errorReport = ErrorReport(
        id: errorId,
        message: errorMessage,
        stackTrace: stackTrace?.toString(),
        severity: severity ?? _determineSeverity(error),
        category: category ?? _determineCategory(error),
        timestamp: now,
        userId: userId,
        userEmail: userEmail,
        screen: screen,
        action: action,
        context: context ?? {},
      );

      // Add to cache
      _addToCache(errorReport);

      // Save to Firebase
      await _saveToFirebase(errorReport);

      // Emit to stream
      _errorStreamController.add(errorReport);

      // Log based on severity
      _logError(errorReport);

      // Send alert for critical errors
      if (errorReport.severity == ErrorSeverity.critical) {
        await _sendCriticalErrorAlert(errorReport);
      }

    } catch (e) {
      // Fallback logging if error monitoring fails
      AppLogger.error('Error monitoring service failed', error: e, category: LogCategory.system);
    }
  }

  // Capture exceptions with additional context
  Future<void> captureException(
    Exception exception, {
    StackTrace? stackTrace,
    String? screen,
    String? action,
    Map<String, dynamic>? context,
  }) async {
    await captureError(
      error: exception,
      stackTrace: stackTrace,
      category: ErrorCategory.businessLogic,
      screen: screen,
      action: action,
      context: context,
    );
  }

  // Capture network errors
  Future<void> captureNetworkError({
    required String url,
    required dynamic error,
    int? statusCode,
    Map<String, dynamic>? headers,
  }) async {
    await captureError(
      error: error,
      category: ErrorCategory.network,
      context: {
        'url': url,
        'statusCode': statusCode,
        'headers': headers,
      },
    );
  }

  // Capture database errors
  Future<void> captureDatabaseError({
    required String operation,
    required dynamic error,
    String? table,
    Map<String, dynamic>? data,
  }) async {
    await captureError(
      error: error,
      category: ErrorCategory.database,
      context: {
        'operation': operation,
        'table': table,
        'data': data,
      },
    );
  }

  // Capture performance issues
  Future<void> capturePerformanceIssue({
    required String metric,
    required double value,
    required double threshold,
    String? screen,
  }) async {
    await captureError(
      error: 'Performance threshold exceeded: $metric',
      severity: ErrorSeverity.medium,
      category: ErrorCategory.performance,
      screen: screen,
      context: {
        'metric': metric,
        'value': value,
        'threshold': threshold,
        'exceeded_by': value - threshold,
      },
    );
  }

  // Get error statistics
  Future<ErrorStatistics> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = _db.ref('errors');
      final snapshot = await query.get();

      if (!snapshot.exists) {
        return ErrorStatistics(
          totalErrors: 0,
          criticalErrors: 0,
          highErrors: 0,
          mediumErrors: 0,
          lowErrors: 0,
          errorsByCategory: {},
          errorsByScreen: {},
          topErrorMessages: [],
          errorRate: 0,
          unresolvedErrors: 0,
        );
      }

      final errors = <ErrorReport>[];
      final data = SafeTypeConverter.toMap(snapshot.value);

      for (final entry in data.entries) {
        final error = ErrorReport.fromMap(SafeTypeConverter.toMap(entry.value));

        // Apply date filters
        if (startDate != null && error.timestamp.isBefore(startDate)) continue;
        if (endDate != null && error.timestamp.isAfter(endDate)) continue;

        errors.add(error);
      }

      // Calculate statistics
      final errorsByCategory = <String, int>{};
      final errorsByScreen = <String, int>{};
      final messageCounts = <String, int>{};
      int criticalCount = 0;
      int highCount = 0;
      int mediumCount = 0;
      int lowCount = 0;
      int unresolvedCount = 0;

      for (final error in errors) {
        // Count by severity
        switch (error.severity) {
          case ErrorSeverity.critical:
            criticalCount++;
            break;
          case ErrorSeverity.high:
            highCount++;
            break;
          case ErrorSeverity.medium:
            mediumCount++;
            break;
          case ErrorSeverity.low:
            lowCount++;
            break;
        }

        // Count by category
        final categoryKey = error.category.toString().split('.').last;
        errorsByCategory[categoryKey] = (errorsByCategory[categoryKey] ?? 0) + 1;

        // Count by screen
        if (error.screen != null) {
          errorsByScreen[error.screen!] = (errorsByScreen[error.screen!] ?? 0) + 1;
        }

        // Count messages
        messageCounts[error.message] = (messageCounts[error.message] ?? 0) + 1;

        // Count unresolved
        if (!error.resolved) {
          unresolvedCount++;
        }
      }

      // Get top error messages
      final sortedMessages = messageCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topMessages = sortedMessages.take(10).map((e) => e.key).toList();

      // Calculate error rate (errors per hour)
      double errorRate = 0;
      if (errors.isNotEmpty) {
        final timeRange = errors.last.timestamp.difference(errors.first.timestamp);
        if (timeRange.inHours > 0) {
          errorRate = errors.length / timeRange.inHours;
        }
      }

      return ErrorStatistics(
        totalErrors: errors.length,
        criticalErrors: criticalCount,
        highErrors: highCount,
        mediumErrors: mediumCount,
        lowErrors: lowCount,
        errorsByCategory: errorsByCategory,
        errorsByScreen: errorsByScreen,
        topErrorMessages: topMessages,
        errorRate: errorRate,
        unresolvedErrors: unresolvedCount,
      );

    } catch (e) {
      AppLogger.error('Failed to get error statistics', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  // Get recent errors from memory cache
  List<ErrorReport> getRecentErrors({int limit = 50}) {
    return _recentErrors.take(limit).toList();
  }

  // Get recent errors from Firebase with limit (optimized)
  Future<List<ErrorReport>> getRecentErrorsFromFirebase({int limit = 100}) async {
    try {
      // Fetch limited errors ordered by timestamp
      final snapshot = await _db.ref('errors')
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      final errors = <ErrorReport>[];

      if (snapshot.value != null) {
        final data = SafeTypeConverter.toMap(snapshot.value);

        for (final entry in data.entries) {
          final error = ErrorReport.fromMap(SafeTypeConverter.toMap(entry.value));
          errors.add(error);
        }
      }

      // Sort by timestamp (newest first)
      errors.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return errors;
    } catch (e) {
      AppLogger.error('Failed to fetch recent errors', error: e, category: LogCategory.system);
      return [];
    }
  }

  // Get unresolved errors only (optimized)
  Future<List<ErrorReport>> getUnresolvedErrors({int limit = 100}) async {
    try {
      // Fetch errors and filter unresolved
      final snapshot = await _db.ref('errors')
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      final errors = <ErrorReport>[];

      if (snapshot.value != null) {
        final data = SafeTypeConverter.toMap(snapshot.value);

        for (final entry in data.entries) {
          final error = ErrorReport.fromMap(SafeTypeConverter.toMap(entry.value));

          // Only add unresolved errors
          if (!error.resolved) {
            errors.add(error);
          }
        }
      }

      // Sort by timestamp (newest first)
      errors.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return errors;
    } catch (e) {
      AppLogger.error('Failed to fetch unresolved errors', error: e, category: LogCategory.system);
      return [];
    }
  }

  // Stream errors from Firebase
  Stream<List<ErrorReport>> streamErrors({
    ErrorSeverity? severity,
    ErrorCategory? category,
    bool unresolvedOnly = false,
  }) {
    Query query = _db.ref('errors').orderByChild('timestamp');

    return query.onValue.map((event) {
      final errors = <ErrorReport>[];

      if (event.snapshot.value != null) {
        final data = SafeTypeConverter.toMap(event.snapshot.value);

        for (final entry in data.entries) {
          final error = ErrorReport.fromMap(SafeTypeConverter.toMap(entry.value));

          // Apply filters
          if (severity != null && error.severity != severity) continue;
          if (category != null && error.category != category) continue;
          if (unresolvedOnly && error.resolved) continue;

          errors.add(error);
        }
      }

      // Sort by timestamp (newest first)
      errors.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return errors;
    });
  }

  // Mark error as resolved
  Future<void> markErrorResolved(String errorId) async {
    try {
      await _db.ref('errors/$errorId').update({
        'resolved': true,
        'resolvedBy': userEmail ?? userId ?? 'unknown',
        'resolvedAt': DateTime.now().millisecondsSinceEpoch,
        'resolvedAtIso': DateTime.now().toIso8601String(),
      });

      AppLogger.info('Error marked as resolved: $errorId', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to mark error as resolved', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  // Alternative method name for compatibility
  Future<void> markErrorAsResolved(String errorId) async {
    return await markErrorResolved(errorId);
  }

  // Clear all resolved errors
  Future<void> clearResolvedErrors() async {
    try {
      final snapshot = await _db.ref('errors').get();

      if (!snapshot.exists) return;

      final data = SafeTypeConverter.toMap(snapshot.value);
      final idsToDelete = <String>[];

      for (final entry in data.entries) {
        final error = ErrorReport.fromMap(SafeTypeConverter.toMap(entry.value));
        if (error.resolved) {
          idsToDelete.add(entry.key);
        }
      }

      // Delete resolved errors
      for (final id in idsToDelete) {
        await _db.ref('errors/$id').remove();
      }

      AppLogger.info('Cleared ${idsToDelete.length} resolved errors', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to clear resolved errors', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  // Clear all errors
  Future<void> clearAllErrors() async {
    try {
      await _db.ref('errors').remove();
      _recentErrors.clear();

      AppLogger.info('All errors cleared', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to clear all errors', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  // Clear old errors (cleanup)
  Future<void> clearOldErrors({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final snapshot = await _db.ref('errors').get();

      if (!snapshot.exists) return;

      final data = SafeTypeConverter.toMap(snapshot.value);
      final idsToDelete = <String>[];

      for (final entry in data.entries) {
        final error = ErrorReport.fromMap(SafeTypeConverter.toMap(entry.value));
        if (error.timestamp.isBefore(cutoffDate)) {
          idsToDelete.add(entry.key);
        }
      }

      // Delete old errors
      for (final id in idsToDelete) {
        await _db.ref('errors/$id').remove();
      }

      AppLogger.info('Cleared ${idsToDelete.length} old errors', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to clear old errors', error: e, category: LogCategory.system);
    }
  }

  // Private helper methods
  ErrorSeverity _determineSeverity(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('critical') ||
        errorString.contains('fatal') ||
        errorString.contains('crash')) {
      return ErrorSeverity.critical;
    }
    if (errorString.contains('error') ||
        errorString.contains('exception')) {
      return ErrorSeverity.high;
    }
    if (errorString.contains('warning') ||
        errorString.contains('deprecated')) {
      return ErrorSeverity.medium;
    }
    return ErrorSeverity.low;
  }

  ErrorCategory _determineCategory(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('auth') ||
        errorString.contains('login') ||
        errorString.contains('permission')) {
      return ErrorCategory.authentication;
    }
    if (errorString.contains('database') ||
        errorString.contains('firebase') ||
        errorString.contains('query')) {
      return ErrorCategory.database;
    }
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return ErrorCategory.network;
    }
    if (errorString.contains('render') ||
        errorString.contains('widget') ||
        errorString.contains('layout')) {
      return ErrorCategory.ui;
    }
    if (errorString.contains('security') ||
        errorString.contains('encryption') ||
        errorString.contains('token')) {
      return ErrorCategory.security;
    }
    if (errorString.contains('performance') ||
        errorString.contains('memory') ||
        errorString.contains('lag')) {
      return ErrorCategory.performance;
    }
    return ErrorCategory.unknown;
  }

  bool _shouldThrottle(String message) {
    final lastTime = _lastErrorTime[message];
    if (lastTime != null) {
      if (DateTime.now().difference(lastTime) < _errorThrottleDuration) {
        return true;
      }
    }
    _lastErrorTime[message] = DateTime.now();
    return false;
  }

  void _addToCache(ErrorReport error) {
    _recentErrors.insert(0, error);
    if (_recentErrors.length > _maxCachedErrors) {
      _recentErrors.removeLast();
    }
  }

  Future<void> _saveToFirebase(ErrorReport error) async {
    try {
      await _db.ref('errors/${error.id}').set(error.toMap());

      // Also save to user-specific path if user is logged in
      if (userId != null) {
        await _db.ref('user_errors/$userId/${error.id}').set({
          'errorId': error.id,
          'timestamp': error.timestamp.millisecondsSinceEpoch,
          'severity': error.severity.toString().split('.').last,
          'message': error.message,
        });
      }
    } catch (e) {
      AppLogger.error('Failed to save error to Firebase', error: e, category: LogCategory.system);
    }
  }

  void _logError(ErrorReport error) {
    switch (error.severity) {
      case ErrorSeverity.critical:
        AppLogger.critical(error.message, category: LogCategory.error);
        break;
      case ErrorSeverity.high:
        AppLogger.error(error.message, error: error.stackTrace, category: LogCategory.error);
        break;
      case ErrorSeverity.medium:
        AppLogger.warning(error.message, category: LogCategory.error);
        break;
      case ErrorSeverity.low:
        AppLogger.info(error.message, category: LogCategory.error);
        break;
    }
  }

  Future<void> _sendCriticalErrorAlert(ErrorReport error) async {
    try {
      // Store critical alert in Firebase
      await _db.ref('critical_alerts/${error.id}').set({
        'errorId': error.id,
        'message': error.message,
        'timestamp': error.timestamp.millisecondsSinceEpoch,
        'userEmail': error.userEmail,
        'screen': error.screen,
        'action': error.action,
        'notified': false,
      });

      AppLogger.critical('Critical error alert sent: ${error.message}', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to send critical error alert', error: e, category: LogCategory.system);
    }
  }

  // Export errors to JSON
  Future<String> exportErrors({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final snapshot = await _db.ref('errors').get();

      if (!snapshot.exists) {
        return json.encode({'errors': []});
      }

      final errors = <Map<String, dynamic>>[];
      final data = SafeTypeConverter.toMap(snapshot.value);

      for (final entry in data.entries) {
        final error = ErrorReport.fromMap(SafeTypeConverter.toMap(entry.value));

        // Apply date filters
        if (startDate != null && error.timestamp.isBefore(startDate)) continue;
        if (endDate != null && error.timestamp.isAfter(endDate)) continue;

        errors.add(error.toMap());
      }

      return json.encode({
        'exported_at': DateTime.now().toIso8601String(),
        'total_errors': errors.length,
        'errors': errors,
      });

    } catch (e) {
      AppLogger.error('Failed to export errors', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  void dispose() {
    _errorStreamController.close();
  }
}