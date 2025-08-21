// lib/core/services/secure_app_logger.dart
// Secure logging service that sanitizes sensitive data

import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Categories for logging
enum LogCategory {
  auth,
  database,
  ui,
  network,
  business,
  performance,
  security,
  sync,
  offline,
  excel,
  cart,
  quote,
  client,
  product,
  email,
  error,
  general,
}

/// Secure App Logger with data sanitization
class SecureAppLogger {
  static late Logger _logger;
  static bool _initialized = false;
  static final Set<String> _sensitiveKeys = {
    'password',
    'token',
    'api_key',
    'apikey',
    'secret',
    'credential',
    'auth',
    'authorization',
    'cookie',
    'session',
    'credit_card',
    'creditcard',
    'card_number',
    'cardnumber',
    'cvv',
    'ssn',
    'social_security',
    'pin',
    'private_key',
    'privatekey',
    'app_password',
    'EMAIL_APP_PASSWORD',
    'ADMIN_PASSWORD',
  };

  static final RegExp _emailRegex = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  );

  static final RegExp _phoneRegex = RegExp(
    r'\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b',
  );

  static final RegExp _creditCardRegex = RegExp(
    r'\b(?:\d{4}[-\s]?){3}\d{4}\b',
  );

  static final RegExp _ipRegex = RegExp(
    r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
  );

  /// Initialize the logger
  static void init({
    bool enableFirebaseLogging = true,
    bool enableCrashlyticsLogging = true,
    Level logLevel = Level.debug,
  }) {
    if (_initialized) return;

    final outputs = <LogOutput>[];

    // Console output for debug builds
    if (kDebugMode) {
      outputs.add(ConsoleOutput());
    }

    // Firebase logging for production
    if (!kDebugMode && enableFirebaseLogging) {
      outputs.add(SecureFirebaseLogOutput());
    }

    _logger = Logger(
      filter: ProductionFilter(),
      printer: SecureLogPrinter(),
      output: MultiOutput(outputs),
      level: logLevel,
    );

    _initialized = true;

    // Log initialization
    info('Secure logger initialized', category: LogCategory.general);
  }

  /// Sanitize sensitive data from any input
  static dynamic sanitizeData(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      return _sanitizeString(data);
    } else if (data is Map) {
      return _sanitizeMap(data);
    } else if (data is List) {
      return data.map((item) => sanitizeData(item)).toList();
    } else if (data is Error || data is Exception) {
      return _sanitizeError(data);
    } else {
      return data;
    }
  }

  /// Sanitize string data
  static String _sanitizeString(String input) {
    String sanitized = input;

    // Replace emails with masked version
    sanitized = sanitized.replaceAllMapped(_emailRegex, (match) {
      final email = match.group(0)!;
      final parts = email.split('@');
      if (parts.length == 2) {
        final localPart = parts[0];
        final domain = parts[1];
        final maskedLocal = localPart.length > 2
            ? '${localPart.substring(0, 2)}***'
            : '***';
        return '$maskedLocal@$domain';
      }
      return '***@***.***';
    });

    // Replace phone numbers
    sanitized = sanitized.replaceAll(_phoneRegex, '***-***-****');

    // Replace credit card numbers
    sanitized = sanitized.replaceAll(_creditCardRegex, '****-****-****-****');

    // Replace IP addresses (but keep local IPs for debugging)
    sanitized = sanitized.replaceAllMapped(_ipRegex, (match) {
      final ip = match.group(0)!;
      if (ip.startsWith('192.168.') || 
          ip.startsWith('10.') || 
          ip.startsWith('127.') ||
          ip.startsWith('172.')) {
        return ip; // Keep local IPs
      }
      return '***.***.***.***';
    });

    // Remove potential passwords in URLs
    final urlPattern = RegExp(r'(https?://[^:]+:)([^@]+)(@)');
    sanitized = sanitized.replaceAllMapped(urlPattern, (match) {
      return '${match.group(1)}***${match.group(3)}';
    });

    return sanitized;
  }

  /// Sanitize map data (like JSON objects)
  static Map<String, dynamic> _sanitizeMap(Map data) {
    final sanitized = <String, dynamic>{};
    
    data.forEach((key, value) {
      final keyLower = key.toString().toLowerCase();
      
      // Check if key contains sensitive words
      bool isSensitive = _sensitiveKeys.any((sensitive) => 
        keyLower.contains(sensitive));
      
      if (isSensitive) {
        // Mask sensitive values
        if (value != null) {
          if (value is String && value.isNotEmpty) {
            sanitized[key] = '***REDACTED***';
          } else if (value is num) {
            sanitized[key] = 0;
          } else if (value is bool) {
            sanitized[key] = false;
          } else {
            sanitized[key] = '***REDACTED***';
          }
        } else {
          sanitized[key] = null;
        }
      } else {
        // Recursively sanitize non-sensitive values
        sanitized[key] = sanitizeData(value);
      }
    });
    
    return sanitized;
  }

  /// Sanitize error objects
  static String _sanitizeError(dynamic error) {
    String errorString = error.toString();
    
    // Remove file paths that might contain usernames
    errorString = errorString.replaceAll(RegExp(r'C:\\Users\\[^\\]+\\'), 'C:\\Users\\***\\');
    errorString = errorString.replaceAll(RegExp(r'/Users/[^/]+/'), '/Users/***/');
    errorString = errorString.replaceAll(RegExp(r'/home/[^/]+/'), '/home/***/');
    
    // Apply string sanitization
    return _sanitizeString(errorString);
  }

  // Logging methods

  static void debug(
    String message, {
    dynamic data,
    dynamic error,
    dynamic stackTrace,
    LogCategory category = LogCategory.general,
  }) {
    if (!_initialized) init();
    
    final sanitizedData = sanitizeData(data ?? error);
    final sanitizedMessage = _sanitizeString(message);
    
    _logger.d(
      '[${category.name.toUpperCase()}] $sanitizedMessage',
      error: sanitizedData,
      stackTrace: stackTrace,
    );
  }

  static void info(
    String message, {
    dynamic data,
    dynamic error,
    dynamic stackTrace,
    LogCategory category = LogCategory.general,
  }) {
    if (!_initialized) init();
    
    final sanitizedData = sanitizeData(data ?? error);
    final sanitizedMessage = _sanitizeString(message);
    
    _logger.i(
      '[${category.name.toUpperCase()}] $sanitizedMessage',
      error: sanitizedData,
      stackTrace: stackTrace,
    );
  }

  static void warning(
    String message, {
    dynamic data,
    dynamic error,
    dynamic stackTrace,
    LogCategory category = LogCategory.general,
  }) {
    if (!_initialized) init();
    
    final sanitizedData = sanitizeData(data ?? error);
    final sanitizedMessage = _sanitizeString(message);
    
    _logger.w(
      '[${category.name.toUpperCase()}] $sanitizedMessage',
      error: sanitizedData,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    LogCategory category = LogCategory.error,
    Map<String, dynamic>? data,
  }) {
    if (!_initialized) init();
    
    final sanitizedError = sanitizeData(error);
    final sanitizedData = sanitizeData(data);
    final sanitizedMessage = _sanitizeString(message);
    
    _logger.e(
      '[${category.name.toUpperCase()}] $sanitizedMessage',
      error: sanitizedError,
      stackTrace: stackTrace,
    );

    // Send to Crashlytics (already sanitized)
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        sanitizedError ?? sanitizedMessage,
        stackTrace,
        reason: sanitizedMessage,
        information: [
          'category: ${category.name}',
          if (sanitizedData != null) 'data: ${sanitizedData.toString()}',
        ],
      );
    }
  }

  static void fatal(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    LogCategory category = LogCategory.error,
  }) {
    if (!_initialized) init();
    
    final sanitizedError = sanitizeData(error);
    final sanitizedMessage = _sanitizeString(message);
    
    _logger.f(
      '[${category.name.toUpperCase()}] $sanitizedMessage',
      error: sanitizedError,
      stackTrace: stackTrace,
    );

    // Send fatal errors to Crashlytics
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        sanitizedError ?? sanitizedMessage,
        stackTrace,
        reason: 'FATAL: $sanitizedMessage',
        fatal: true,
      );
    }
  }

  /// Log performance metrics (already sanitized)
  static void performance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) {
    if (!_initialized) init();
    
    final sanitizedMetadata = sanitizeData(metadata);
    
    info(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      data: sanitizedMetadata,
      category: LogCategory.performance,
    );
  }

  /// Log security events
  static void security(
    String event, {
    Map<String, dynamic>? details,
  }) {
    if (!_initialized) init();
    
    // Extra careful with security logs
    final sanitizedDetails = sanitizeData(details);
    
    warning(
      'Security Event: $event',
      data: sanitizedDetails,
      category: LogCategory.security,
    );

    // Send security events to Firebase
    if (!kDebugMode) {
      FirebaseDatabase.instance.ref('security_logs').push().set({
        'event': event,
        'timestamp': ServerValue.timestamp,
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'details': sanitizedDetails,
      }).catchError((e) {
        // Silently fail
      });
    }
  }
}

/// Custom log printer that formats messages
class SecureLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final time = DateTime.now().toIso8601String();
    final levelStr = event.level.name.toUpperCase();
    
    final messages = <String>[];
    messages.add('[$levelStr] $time - ${event.message}');
    
    if (event.error != null) {
      messages.add('   Error: ${event.error}');
    }
    
    if (event.stackTrace != null && kDebugMode) {
      messages.add('   Stack trace:\n${event.stackTrace}');
    }
    
    return messages;
  }
}

/// Multi-output handler
class MultiOutput extends LogOutput {
  final List<LogOutput> outputs;
  
  MultiOutput(this.outputs);
  
  @override
  void output(OutputEvent event) {
    for (final output in outputs) {
      try {
        output.output(event);
      } catch (e) {
        // Silently fail for individual outputs
      }
    }
  }
}

/// Secure Firebase log output
class SecureFirebaseLogOutput extends LogOutput {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  void output(OutputEvent event) {
    if (event.level.index >= Level.warning.index) {
      // Already sanitized messages
      final logData = {
        'level': event.level.name,
        'message': event.lines.join('\n'),
        'timestamp': ServerValue.timestamp,
        'user_id': _auth.currentUser?.uid,
        // Don't include email to prevent PII logging
      };
      
      // Send to Firebase Realtime Database
      _db.ref('app_logs').push().set(logData).catchError((e) {
        // Silently fail
      });
    }
  }
}

