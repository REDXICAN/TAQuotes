// lib/core/utils/error_handler.dart
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/logging_service.dart';

class ErrorHandler {
  static bool _isInitialized = false;

  /// Initialize error handling for the app
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Async error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleAsyncError(error, stack);
      return true;
    };

    // Initialize Crashlytics for production (not supported on web)
    if (!kDebugMode && !kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Pass uncaught errors to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    }

    _isInitialized = true;
    
    logger.info('Error handler initialized', category: LogCategory.general);
  }

  /// Handle Flutter framework errors
  static void _handleFlutterError(FlutterErrorDetails details) {
    final errorMessage = details.exception.toString();
    final stackTrace = details.stack;

    // Log the error
    logger.error(
      'Flutter Error: $errorMessage',
      category: LogCategory.ui,
      metadata: {
        'library': details.library,
        'context': details.context?.toString(),
        'silent': details.silent,
      },
      stackTrace: stackTrace,
    );

    // Send to Crashlytics in production (not supported on web)
    if (!kDebugMode && !kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }

    // Show error in debug mode
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  /// Handle async errors
  static void _handleAsyncError(Object error, StackTrace stack) {
    logger.error(
      'Async Error: ${error.toString()}',
      category: LogCategory.general,
      metadata: {
        'type': error.runtimeType.toString(),
      },
      stackTrace: stack,
    );

    // Send to Crashlytics in production (not supported on web)
    if (!kDebugMode && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack);
    }
  }

  /// Handle and log business logic errors
  static void handleBusinessError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    bool showToUser = true,
    BuildContext? context,
  }) {
    logger.error(
      message,
      category: LogCategory.business,
      metadata: {
        ...?metadata,
        if (error != null) 'error': error.toString(),
      },
      stackTrace: stackTrace,
    );

    // Show error to user if context is provided
    if (showToUser && context != null && context.mounted) {
      _showErrorToUser(context, message);
    }

    // Send to Crashlytics in production (not supported on web)
    if (!kDebugMode && !kIsWeb && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: message,
      );
    }
  }

  /// Handle network errors
  static void handleNetworkError(
    String operation,
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    BuildContext? context,
  }) {
    final message = 'Network error during $operation: ${error.toString()}';
    
    logger.error(
      message,
      category: LogCategory.network,
      metadata: {
        'operation': operation,
        'error_type': error.runtimeType.toString(),
        ...?metadata,
      },
      stackTrace: stackTrace,
    );

    if (context != null && context.mounted) {
      _showErrorToUser(
        context,
        'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Handle database errors
  static void handleDatabaseError(
    String operation,
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    BuildContext? context,
  }) {
    final message = 'Database error during $operation: ${error.toString()}';
    
    logger.error(
      message,
      category: LogCategory.database,
      metadata: {
        'operation': operation,
        'error_type': error.runtimeType.toString(),
        ...?metadata,
      },
      stackTrace: stackTrace,
    );

    if (context != null && context.mounted) {
      _showErrorToUser(
        context,
        'Unable to complete operation. Please try again.',
      );
    }

    // Send to Crashlytics (not supported on web)
    if (!kDebugMode && !kIsWeb) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Database operation failed: $operation',
      );
    }
  }

  /// Handle authentication errors
  static void handleAuthError(
    String operation,
    Object error, {
    StackTrace? stackTrace,
    BuildContext? context,
  }) {
    String userMessage = 'Authentication failed. Please try again.';
    
    // Parse Firebase Auth errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('user-not-found')) {
      userMessage = 'No user found with this email.';
    } else if (errorString.contains('wrong-password')) {
      userMessage = 'Incorrect password.';
    } else if (errorString.contains('email-already-in-use')) {
      userMessage = 'This email is already registered.';
    } else if (errorString.contains('weak-password')) {
      userMessage = 'Password is too weak.';
    } else if (errorString.contains('invalid-email')) {
      userMessage = 'Invalid email address.';
    } else if (errorString.contains('network-request-failed')) {
      userMessage = 'Network error. Please check your connection.';
    }

    logger.error(
      'Auth error during $operation: ${error.toString()}',
      category: LogCategory.auth,
      metadata: {
        'operation': operation,
        'error_type': error.runtimeType.toString(),
      },
      stackTrace: stackTrace,
    );

    if (context != null && context.mounted) {
      _showErrorToUser(context, userMessage);
    }
  }

  /// Show error message to user
  static void _showErrorToUser(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success message to user
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show info message to user
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Wrap an async operation with error handling
  static Future<T?> tryAsync<T>(
    Future<T> Function() operation, {
    required String operationName,
    BuildContext? context,
    bool showError = true,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handleBusinessError(
        'Failed to $operationName',
        error: error,
        stackTrace: stackTrace,
        metadata: metadata,
        showToUser: showError,
        context: context,
      );
      return null;
    }
  }

  /// Wrap a sync operation with error handling
  static T? trySync<T>(
    T Function() operation, {
    required String operationName,
    BuildContext? context,
    bool showError = true,
    Map<String, dynamic>? metadata,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      handleBusinessError(
        'Failed to $operationName',
        error: error,
        stackTrace: stackTrace,
        metadata: metadata,
        showToUser: showError,
        context: context,
      );
      return null;
    }
  }
}