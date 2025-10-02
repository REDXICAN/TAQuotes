// lib/core/services/logging_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import '../models/models.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

enum LogCategory {
  auth,
  database,
  ui,
  network,
  business,
  performance,
  security,
  general,
}

class LogEntry {
  final String id;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final DateTime timestamp;
  final String? userId;
  final String? userEmail;
  final Map<String, dynamic>? metadata;
  final String? stackTrace;
  final String? deviceInfo;
  final String? appVersion;
  final String environment;

  LogEntry({
    required this.id,
    required this.level,
    required this.category,
    required this.message,
    required this.timestamp,
    this.userId,
    this.userEmail,
    this.metadata,
    this.stackTrace,
    this.deviceInfo,
    this.appVersion,
    required this.environment,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'level': level.name,
    'category': category.name,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
    'userEmail': userEmail,
    'metadata': metadata,
    'stackTrace': stackTrace,
    'deviceInfo': deviceInfo,
    'appVersion': appVersion,
    'environment': environment,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    id: json['id'],
    level: LogLevel.values.firstWhere((e) => e.name == json['level']),
    category: LogCategory.values.firstWhere((e) => e.name == json['category']),
    message: json['message'],
    timestamp: safeParseDateTimeWithFallback(json['timestamp']),
    userId: json['userId'],
    userEmail: json['userEmail'],
    metadata: json['metadata'],
    stackTrace: json['stackTrace'],
    deviceInfo: json['deviceInfo'],
    appVersion: json['appVersion'],
    environment: json['environment'],
  );
}

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final List<LogEntry> _localLogs = [];
  final int _maxLocalLogs = 100;
  
  String? _deviceInfo;
  String? _appVersion;
  String _environment = 'development';
  bool _isInitialized = false;
  bool _enableRemoteLogging = true;
  bool _enableConsoleLogging = true;
  LogLevel _minLogLevel = LogLevel.debug;

  // Webhooks for external logging services
  String? _discordWebhookUrl;
  String? _slackWebhookUrl;
  String? _vercelLogDrainUrl;

  Future<void> initialize({
    String environment = 'development',
    bool enableRemoteLogging = true,
    bool enableConsoleLogging = true,
    LogLevel minLogLevel = LogLevel.debug,
    String? discordWebhookUrl,
    String? slackWebhookUrl,
    String? vercelLogDrainUrl,
  }) async {
    if (_isInitialized) return;

    _environment = environment;
    _enableRemoteLogging = enableRemoteLogging;
    _enableConsoleLogging = enableConsoleLogging;
    _minLogLevel = minLogLevel;
    _discordWebhookUrl = discordWebhookUrl;
    _slackWebhookUrl = slackWebhookUrl;
    _vercelLogDrainUrl = vercelLogDrainUrl;

    // Get device info
    await _initializeDeviceInfo();
    
    // Get app version
    await _initializeAppVersion();

    _isInitialized = true;

    log(
      level: LogLevel.info,
      category: LogCategory.general,
      message: 'Logging service initialized',
      metadata: {
        'environment': environment,
        'remoteLogging': enableRemoteLogging,
        'consoleLogging': enableConsoleLogging,
        'minLogLevel': minLogLevel.name,
      },
    );
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        _deviceInfo = 'Web: ${webInfo.browserName} on ${webInfo.platform}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        _deviceInfo = 'Android ${androidInfo.version.release} (${androidInfo.model})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        _deviceInfo = 'iOS ${iosInfo.systemVersion} (${iosInfo.model})';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfoPlugin.windowsInfo;
        _deviceInfo = 'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        _deviceInfo = 'macOS ${macInfo.majorVersion}.${macInfo.minorVersion}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        _deviceInfo = 'Linux ${linuxInfo.name} ${linuxInfo.version}';
      }
    } catch (e) {
      _deviceInfo = 'Unknown device';
    }
  }

  Future<void> _initializeAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      _appVersion = 'Unknown version';
    }
  }

  void log({
    required LogLevel level,
    required LogCategory category,
    required String message,
    Map<String, dynamic>? metadata,
    StackTrace? stackTrace,
    bool forceRemote = false,
  }) {
    // Check minimum log level
    if (level.index < _minLogLevel.index && !forceRemote) return;

    final user = FirebaseAuth.instance.currentUser;
    final logEntry = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      level: level,
      category: category,
      message: message,
      timestamp: DateTime.now(),
      userId: user?.uid,
      userEmail: user?.email,
      metadata: metadata,
      stackTrace: stackTrace?.toString(),
      deviceInfo: _deviceInfo,
      appVersion: _appVersion,
      environment: _environment,
    );

    // Add to local logs
    _addLocalLog(logEntry);

    // Console logging
    if (_enableConsoleLogging) {
      _logToConsole(logEntry);
    }

    // Remote logging
    if (_enableRemoteLogging || forceRemote) {
      _logToRemote(logEntry);
    }

    // Critical errors go to webhooks
    if (level == LogLevel.critical || level == LogLevel.error) {
      _sendToWebhooks(logEntry);
    }
  }

  void _addLocalLog(LogEntry entry) {
    _localLogs.add(entry);
    if (_localLogs.length > _maxLocalLogs) {
      _localLogs.removeAt(0);
    }
  }

  void _logToConsole(LogEntry entry) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(entry.timestamp);
    final prefix = '[${entry.level.name.toUpperCase()}][$timestamp][${entry.category.name}]';
    final color = _getConsoleColor(entry.level);
    
    if (kDebugMode) {
      debugPrint('$color$prefix ${entry.message}\x1B[0m');
      if (entry.metadata != null) {
        debugPrint('  Metadata: ${entry.metadata}');
      }
      if (entry.stackTrace != null && entry.level == LogLevel.error) {
        debugPrint('  Stack: ${entry.stackTrace}');
      }
    }
  }

  String _getConsoleColor(LogLevel level) {
    if (!kDebugMode) return '';
    
    switch (level) {
      case LogLevel.debug:
        return '\x1B[90m'; // Gray
      case LogLevel.info:
        return '\x1B[36m'; // Cyan
      case LogLevel.warning:
        return '\x1B[33m'; // Yellow
      case LogLevel.error:
        return '\x1B[31m'; // Red
      case LogLevel.critical:
        return '\x1B[35m'; // Magenta
    }
  }

  Future<void> _logToRemote(LogEntry entry) async {
    try {
      // Only log important events to Firebase to avoid quota issues
      if (entry.level.index >= LogLevel.warning.index) {
        final ref = _db.ref('logs/${entry.environment}/${entry.timestamp.millisecondsSinceEpoch}');
        await ref.set(entry.toJson());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to send log to Firebase: $e');
      }
    }
  }

  Future<void> _sendToWebhooks(LogEntry entry) async {
    // Discord webhook
    if (_discordWebhookUrl != null) {
      _sendToDiscord(entry);
    }

    // Slack webhook
    if (_slackWebhookUrl != null) {
      _sendToSlack(entry);
    }

    // Vercel Log Drain
    if (_vercelLogDrainUrl != null) {
      _sendToVercel(entry);
    }
  }

  Future<void> _sendToDiscord(LogEntry entry) async {
    // Discord webhook implementation
    // This would use http package to send formatted message
  }

  Future<void> _sendToSlack(LogEntry entry) async {
    // Slack webhook implementation
    // This would use http package to send formatted message
  }

  Future<void> _sendToVercel(LogEntry entry) async {
    // Vercel log drain implementation
    // This would use http package to send structured logs
  }

  // Convenience methods
  void debug(String message, {LogCategory category = LogCategory.general, Map<String, dynamic>? metadata}) {
    log(level: LogLevel.debug, category: category, message: message, metadata: metadata);
  }

  void info(String message, {LogCategory category = LogCategory.general, Map<String, dynamic>? metadata}) {
    log(level: LogLevel.info, category: category, message: message, metadata: metadata);
  }

  void warning(String message, {LogCategory category = LogCategory.general, Map<String, dynamic>? metadata}) {
    log(level: LogLevel.warning, category: category, message: message, metadata: metadata);
  }

  void error(String message, {LogCategory category = LogCategory.general, Map<String, dynamic>? metadata, StackTrace? stackTrace}) {
    log(level: LogLevel.error, category: category, message: message, metadata: metadata, stackTrace: stackTrace);
  }

  void critical(String message, {LogCategory category = LogCategory.general, Map<String, dynamic>? metadata, StackTrace? stackTrace}) {
    log(level: LogLevel.critical, category: category, message: message, metadata: metadata, stackTrace: stackTrace, forceRemote: true);
  }

  // Performance logging
  void logPerformance(String operation, Duration duration, {Map<String, dynamic>? metadata}) {
    log(
      level: duration.inMilliseconds > 1000 ? LogLevel.warning : LogLevel.info,
      category: LogCategory.performance,
      message: 'Operation "$operation" took ${duration.inMilliseconds}ms',
      metadata: {
        'duration_ms': duration.inMilliseconds,
        'operation': operation,
        ...?metadata,
      },
    );
  }

  // Auth event logging
  void logAuthEvent(String event, {String? userId, String? email, Map<String, dynamic>? metadata}) {
    log(
      level: LogLevel.info,
      category: LogCategory.auth,
      message: 'Auth event: $event',
      metadata: {
        'event': event,
        'userId': userId,
        'email': email,
        ...?metadata,
      },
    );
  }

  // Business event logging
  void logBusinessEvent(String event, {Map<String, dynamic>? metadata}) {
    log(
      level: LogLevel.info,
      category: LogCategory.business,
      message: 'Business event: $event',
      metadata: {
        'event': event,
        ...?metadata,
      },
    );
  }

  // Get recent logs
  List<LogEntry> getRecentLogs({LogLevel? minLevel, LogCategory? category, int? limit}) {
    var logs = List<LogEntry>.from(_localLogs);
    
    if (minLevel != null) {
      logs = logs.where((log) => log.level.index >= minLevel.index).toList();
    }
    
    if (category != null) {
      logs = logs.where((log) => log.category == category).toList();
    }
    
    if (limit != null && logs.length > limit) {
      logs = logs.sublist(logs.length - limit);
    }
    
    return logs;
  }

  // Export logs
  String exportLogsAsJson() {
    return _localLogs.map((log) => log.toJson()).toList().toString();
  }

  String exportLogsAsCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Level,Category,Message,User,Environment');
    
    for (final log in _localLogs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},'
        '${log.level.name},'
        '${log.category.name},'
        '"${log.message.replaceAll('"', '""')}",'
        '${log.userEmail ?? ""},'
        '${log.environment}'
      );
    }
    
    return buffer.toString();
  }

  // Clear logs
  void clearLocalLogs() {
    _localLogs.clear();
  }
}

// Global logger instance
final logger = LoggingService();