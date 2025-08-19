// lib/core/services/app_logger.dart
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:http/http.dart' as http;

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

/// Custom log output that sends to multiple destinations
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

/// Firebase log output
class FirebaseLogOutput extends LogOutput {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  void output(OutputEvent event) {
    if (event.level.index >= Level.warning.index) {
      final logData = {
        'level': event.level.name,
        'message': event.lines.join('\n'),
        'timestamp': ServerValue.timestamp,
        'user': _auth.currentUser?.email,
        'uid': _auth.currentUser?.uid,
      };
      
      // Send to Firebase Realtime Database
      _db.ref('logs').push().set(logData).catchError((e) {
        // Silently fail
      });
      
      // Send critical errors to Crashlytics
      if (event.level.index >= Level.error.index) {
        FirebaseCrashlytics.instance.log(event.lines.join('\n'));
      }
    }
  }
}

/// Webhook log output for external monitoring
class WebhookLogOutput extends LogOutput {
  final String? webhookUrl;
  
  WebhookLogOutput({this.webhookUrl});
  
  @override
  void output(OutputEvent event) {
    if (webhookUrl != null && event.level.index >= Level.error.index) {
      try {
        http.post(
          Uri.parse(webhookUrl!),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'level': event.level.name,
            'message': event.lines.join('\n'),
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ).catchError((e) {
          // Silently fail - return a dummy response
          return http.Response('Error', 500);
        });
      } catch (e) {
        // Silently fail
      }
    }
  }
}

/// Custom log filter with category support
class CategoryLogFilter extends LogFilter {
  final Set<LogCategory> allowedCategories;
  final Level minimumLevel;
  
  CategoryLogFilter({
    this.allowedCategories = const {},
    this.minimumLevel = Level.debug,
  });
  
  @override
  bool shouldLog(LogEvent event) {
    // Check level first
    if (event.level.index < minimumLevel.index) {
      return false;
    }
    
    // If no category filter, allow all
    if (allowedCategories.isEmpty) {
      return true;
    }
    
    // Check if category is allowed
    if (event.error is LogCategory) {
      return allowedCategories.contains(event.error);
    }
    
    return true;
  }
}

/// Main application logger
class AppLogger {
  static Logger? _logger;
  static late DeviceInfoPlugin _deviceInfo;
  static late PackageInfo _packageInfo;
  static Map<String, dynamic>? _deviceData;
  static Map<String, dynamic>? _appData;
  static bool _isInitialized = false;
  
  /// Initialize the logger
  static Future<void> initialize({
    Level logLevel = Level.debug,
    bool enableFirebaseLogs = true,
    bool enableConsoleLogs = true,
    String? webhookUrl,
    Set<LogCategory>? allowedCategories,
  }) async {
    // Get device and app info
    _deviceInfo = DeviceInfoPlugin();
    _packageInfo = await PackageInfo.fromPlatform();
    
    // Collect device data
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceData = {
          'platform': 'Android',
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceData = {
          'platform': 'iOS',
          'model': iosInfo.model,
          'version': iosInfo.systemVersion,
          'name': iosInfo.name,
        };
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        _deviceData = {
          'platform': 'Windows',
          'computerName': windowsInfo.computerName,
          'numberOfCores': windowsInfo.numberOfCores,
          'systemMemory': windowsInfo.systemMemoryInMegabytes,
        };
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        _deviceData = {
          'platform': 'macOS',
          'model': macInfo.model,
          'kernelVersion': macInfo.kernelVersion,
          'osRelease': macInfo.osRelease,
        };
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        _deviceData = {
          'platform': 'Linux',
          'name': linuxInfo.name,
          'version': linuxInfo.version,
          'id': linuxInfo.id,
        };
      } else {
        _deviceData = {
          'platform': 'Web',
          'userAgent': 'Flutter Web',
        };
      }
    } catch (e) {
      _deviceData = {'platform': 'Unknown', 'error': e.toString()};
    }
    
    // Collect app data
    _appData = {
      'appName': _packageInfo.appName,
      'packageName': _packageInfo.packageName,
      'version': _packageInfo.version,
      'buildNumber': _packageInfo.buildNumber,
    };
    
    // Create outputs
    final outputs = <LogOutput>[];
    
    if (enableConsoleLogs) {
      outputs.add(ConsoleOutput());
    }
    
    if (enableFirebaseLogs && !kIsWeb) {
      outputs.add(FirebaseLogOutput());
    }
    
    if (webhookUrl != null) {
      outputs.add(WebhookLogOutput(webhookUrl: webhookUrl));
    }
    
    // Create logger
    _logger = Logger(
      filter: CategoryLogFilter(
        allowedCategories: allowedCategories ?? {},
        minimumLevel: kDebugMode ? Level.debug : logLevel,
      ),
      printer: PrettyPrinter(
        methodCount: kDebugMode ? 2 : 0,
        errorMethodCount: 5,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: MultiOutput(outputs),
    );
    
    _isInitialized = true;
    
    // Log initialization
    _logger?.i('Logger initialized', error: LogCategory.general);
    _logger?.d('Device Info: $_deviceData', error: LogCategory.general);
    _logger?.d('App Info: $_appData', error: LogCategory.general);
  }
  
  /// Log debug message
  static void debug(String message, {LogCategory category = LogCategory.general, dynamic data}) {
    if (!_isInitialized) {
      print('[DEBUG] $message');
      return;
    }
    _logger?.d(_formatMessage(message, data), error: category);
  }
  
  /// Log info message
  static void info(String message, {LogCategory category = LogCategory.general, dynamic data}) {
    if (!_isInitialized) {
      print('[INFO] $message');
      return;
    }
    _logger?.i(_formatMessage(message, data), error: category);
  }
  
  /// Log warning message
  static void warning(String message, {LogCategory category = LogCategory.general, dynamic data}) {
    if (!_isInitialized) {
      print('[WARNING] $message');
      return;
    }
    _logger?.w(_formatMessage(message, data), error: category);
  }
  
  /// Log error message
  static void error(String message, {
    LogCategory category = LogCategory.error,
    dynamic error,
    StackTrace? stackTrace,
    dynamic data,
  }) {
    if (!_isInitialized) {
      print('[ERROR] $message${error != null ? ': $error' : ''}');
      if (stackTrace != null) print(stackTrace);
      return;
    }
    _logger?.e(
      _formatMessage(message, data),
      error: error ?? category,
      stackTrace: stackTrace,
    );
    
    // Send to Crashlytics for production
    if (!kDebugMode && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: message,
      );
    }
  }
  
  /// Log critical/fatal error
  static void critical(String message, {
    LogCategory category = LogCategory.error,
    dynamic error,
    StackTrace? stackTrace,
    dynamic data,
  }) {
    if (!_isInitialized) {
      print('[CRITICAL] $message${error != null ? ': $error' : ''}');
      if (stackTrace != null) print(stackTrace);
      return;
    }
    _logger?.f(
      _formatMessage(message, data),
      error: error ?? category,
      stackTrace: stackTrace,
    );
    
    // Always send to Crashlytics
    FirebaseCrashlytics.instance.recordError(
      error ?? Exception(message),
      stackTrace,
      reason: message,
      fatal: true,
    );
  }
  
  /// Log performance metrics
  static void performance(String operation, int durationMs, {Map<String, dynamic>? metrics}) {
    final data = {
      'operation': operation,
      'duration_ms': durationMs,
      ...?metrics,
    };
    if (!_isInitialized) {
      print('[PERFORMANCE] $operation took ${durationMs}ms');
      return;
    }
    _logger?.i('Performance: $operation took ${durationMs}ms, metrics: $data', error: LogCategory.performance);
    
    // Send to Firebase Performance Monitoring if needed
    if (!kDebugMode && durationMs > 1000) {
      _logger?.w('Slow operation detected: $operation (${durationMs}ms)', error: LogCategory.performance);
    }
  }
  
  /// Log network request
  static void network({
    required String method,
    required String url,
    int? statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
    dynamic response,
    int? durationMs,
  }) {
    final data = {
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'duration_ms': durationMs,
    };
    
    if (!_isInitialized) {
      print('[NETWORK] $method $url -> $statusCode');
      return;
    }
    
    if (statusCode != null && statusCode >= 400) {
      _logger?.e('Network Error: $method $url returned $statusCode, data: $data', error: LogCategory.network);
    } else {
      _logger?.d('Network: $method $url${statusCode != null ? ' ($statusCode)' : ''}, data: $data', error: LogCategory.network);
    }
  }
  
  /// Log authentication events
  static void auth(String event, {String? userId, String? email, Map<String, dynamic>? data}) {
    final logData = {
      'event': event,
      'userId': userId,
      'email': email,
      ...?data,
    };
    if (!_isInitialized) {
      print('[AUTH] $event${email != null ? ' for $email' : ''}');
      return;
    }
    _logger?.i('Auth: $event${email != null ? ' for $email' : ''}, details: $logData', error: LogCategory.auth);
  }
  
  /// Log database operations
  static void database({
    required String operation,
    required String collection,
    String? documentId,
    Map<String, dynamic>? data,
    dynamic error,
  }) {
    if (!_isInitialized) {
      print('[DATABASE] $operation on $collection${error != null ? ' - ERROR: $error' : ''}');
      return;
    }
    
    if (error != null) {
      _logger?.e('Database Error: $operation on $collection failed', error: error);
    } else {
      _logger?.d('Database: $operation on $collection${documentId != null ? '/$documentId' : ''}', error: LogCategory.database);
    }
  }
  
  /// Format message with additional data
  static String _formatMessage(String message, dynamic data) {
    if (data == null) {
      return message;
    }
    
    if (data is Map) {
      final dataStr = data.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return '$message | $dataStr';
    }
    
    return '$message | $data';
  }
  
  /// Create a stopwatch for performance logging
  static Stopwatch startTimer() {
    return Stopwatch()..start();
  }
  
  /// Log timer result
  static void logTimer(String operation, Stopwatch timer, {Map<String, dynamic>? metrics}) {
    timer.stop();
    performance(operation, timer.elapsedMilliseconds, metrics: metrics);
  }
}

/// Extension for easy logging with BuildContext
extension LoggerContext on Logger {
  void logWithContext(String message, {required bool mounted}) {
    if (!mounted) {
      w('Attempted to log after context was unmounted: $message');
      return;
    }
    i(message);
  }
}