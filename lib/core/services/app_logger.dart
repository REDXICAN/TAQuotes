// lib/core/services/app_logger.dart
// Bridge file for backward compatibility with SecureAppLogger
import 'secure_app_logger.dart';
export 'secure_app_logger.dart' show LogCategory;

// AppLogger class that delegates to SecureAppLogger
class AppLogger {
  static void info(String message, {dynamic data, dynamic error, dynamic stackTrace, LogCategory? category}) {
    SecureAppLogger.info(message, data: data, error: error, stackTrace: stackTrace, category: category ?? LogCategory.general);
  }
  
  static void error(String message, {dynamic data, dynamic error, dynamic stackTrace, LogCategory? category}) {
    SecureAppLogger.error(message, data: data, error: error, stackTrace: stackTrace, category: category ?? LogCategory.error);
  }
  
  static void warning(String message, {dynamic data, dynamic error, dynamic stackTrace, LogCategory? category}) {
    SecureAppLogger.warning(message, data: data, error: error, stackTrace: stackTrace, category: category ?? LogCategory.general);
  }
  
  static void debug(String message, {dynamic data, dynamic error, dynamic stackTrace, LogCategory? category}) {
    SecureAppLogger.debug(message, data: data, error: error, stackTrace: stackTrace, category: category ?? LogCategory.general);
  }

  static void critical(String message, {dynamic data, dynamic error, dynamic stackTrace, LogCategory? category}) {
    SecureAppLogger.error(message, data: data, error: error, stackTrace: stackTrace, category: category ?? LogCategory.error);
  }

  // Add missing timer methods for backward compatibility
  static Stopwatch startTimer() => Stopwatch()..start();

  static void logTimer(String message, Stopwatch stopwatch) {
    stopwatch.stop();
    info('$message (${stopwatch.elapsedMilliseconds}ms)', category: LogCategory.performance);
  }

  static void stopTimer(Stopwatch stopwatch, String message, {LogCategory? category}) {
    stopwatch.stop();
    info('$message (${stopwatch.elapsedMilliseconds}ms)', category: category ?? LogCategory.performance);
  }
}