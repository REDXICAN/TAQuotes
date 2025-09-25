// lib/core/services/rate_limiter_service.dart
// Rate limiting service to prevent brute force attacks and API abuse

import 'dart:async';
import 'app_logger.dart';

class RateLimiterService {
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  // Store attempt records for different operations
  final Map<String, List<DateTime>> _attemptRecords = {};
  
  // Store blocked identifiers
  final Map<String, DateTime> _blockedUntil = {};
  
  // Configuration for different operations
  final Map<RateLimitType, RateLimitConfig> _configs = {
    RateLimitType.login: RateLimitConfig(
      maxAttempts: 5,
      windowDuration: const Duration(minutes: 15),
      blockDuration: const Duration(hours: 1),
    ),
    RateLimitType.passwordReset: RateLimitConfig(
      maxAttempts: 3,
      windowDuration: const Duration(hours: 1),
      blockDuration: const Duration(hours: 24),
    ),
    RateLimitType.emailSend: RateLimitConfig(
      maxAttempts: 20,
      windowDuration: const Duration(minutes: 1),
      blockDuration: const Duration(minutes: 30),
    ),
    RateLimitType.apiCall: RateLimitConfig(
      maxAttempts: 100,
      windowDuration: const Duration(minutes: 1),
      blockDuration: const Duration(minutes: 5),
    ),
    RateLimitType.registration: RateLimitConfig(
      maxAttempts: 3,
      windowDuration: const Duration(hours: 1),
      blockDuration: const Duration(hours: 24),
    ),
    RateLimitType.quoteCreation: RateLimitConfig(
      maxAttempts: 50,
      windowDuration: const Duration(hours: 1),
      blockDuration: const Duration(minutes: 30),
    ),
  };

  /// Check if an action is allowed based on rate limiting rules
  RateLimitResult checkRateLimit({
    required String identifier, // Could be email, IP, user ID, etc.
    required RateLimitType type,
    String? secondaryIdentifier, // For additional tracking (e.g., IP + email)
  }) {
    final config = _configs[type]!;
    final key = _generateKey(identifier, type, secondaryIdentifier);
    final now = DateTime.now();

    // Check if identifier is blocked
    if (_blockedUntil.containsKey(key)) {
      final blockEndTime = _blockedUntil[key]!;
      if (now.isBefore(blockEndTime)) {
        final remainingTime = blockEndTime.difference(now);
        return RateLimitResult(
          allowed: false,
          remainingAttempts: 0,
          blockedFor: remainingTime,
          message: 'Too many attempts. Please try again in ${_formatDuration(remainingTime)}.',
        );
      } else {
        // Block has expired, remove it
        _blockedUntil.remove(key);
        _attemptRecords.remove(key);
      }
    }

    // Initialize or get attempt records
    _attemptRecords[key] ??= [];
    final attempts = _attemptRecords[key]!;

    // Remove old attempts outside the window
    attempts.removeWhere((attempt) => 
      now.difference(attempt) > config.windowDuration);

    // Check if limit exceeded
    if (attempts.length >= config.maxAttempts) {
      // Block the identifier
      _blockedUntil[key] = now.add(config.blockDuration);
      
      // Log potential attack
      _logRateLimitViolation(identifier, type);
      
      return RateLimitResult(
        allowed: false,
        remainingAttempts: 0,
        blockedFor: config.blockDuration,
        message: 'Rate limit exceeded. Blocked for ${_formatDuration(config.blockDuration)}.',
      );
    }

    // Record this attempt
    attempts.add(now);
    
    final remainingAttempts = config.maxAttempts - attempts.length;
    
    return RateLimitResult(
      allowed: true,
      remainingAttempts: remainingAttempts,
      message: remainingAttempts <= 2 
        ? 'Warning: $remainingAttempts attempts remaining'
        : null,
    );
  }

  /// Record a successful action (optionally reset the counter)
  void recordSuccess({
    required String identifier,
    required RateLimitType type,
    String? secondaryIdentifier,
    bool resetCounter = true,
  }) {
    if (resetCounter) {
      final key = _generateKey(identifier, type, secondaryIdentifier);
      _attemptRecords.remove(key);
      _blockedUntil.remove(key);
    }
  }

  /// Manually block an identifier
  void blockIdentifier({
    required String identifier,
    required RateLimitType type,
    Duration? customDuration,
    String? secondaryIdentifier,
  }) {
    final config = _configs[type]!;
    final key = _generateKey(identifier, type, secondaryIdentifier);
    final duration = customDuration ?? config.blockDuration;
    
    _blockedUntil[key] = DateTime.now().add(duration);
  }

  /// Unblock an identifier
  void unblockIdentifier({
    required String identifier,
    required RateLimitType type,
    String? secondaryIdentifier,
  }) {
    final key = _generateKey(identifier, type, secondaryIdentifier);
    _blockedUntil.remove(key);
    _attemptRecords.remove(key);
  }

  /// Check if an identifier is currently blocked
  bool isBlocked({
    required String identifier,
    required RateLimitType type,
    String? secondaryIdentifier,
  }) {
    final key = _generateKey(identifier, type, secondaryIdentifier);
    if (!_blockedUntil.containsKey(key)) return false;
    
    final blockEndTime = _blockedUntil[key]!;
    final now = DateTime.now();
    
    if (now.isAfter(blockEndTime)) {
      _blockedUntil.remove(key);
      return false;
    }
    
    return true;
  }

  /// Get remaining block time
  Duration? getRemainingBlockTime({
    required String identifier,
    required RateLimitType type,
    String? secondaryIdentifier,
  }) {
    final key = _generateKey(identifier, type, secondaryIdentifier);
    if (!_blockedUntil.containsKey(key)) return null;
    
    final blockEndTime = _blockedUntil[key]!;
    final now = DateTime.now();
    
    if (now.isAfter(blockEndTime)) {
      _blockedUntil.remove(key);
      return null;
    }
    
    return blockEndTime.difference(now);
  }

  /// Clean up expired blocks and old attempt records
  void cleanup() {
    final now = DateTime.now();
    
    // Remove expired blocks
    _blockedUntil.removeWhere((key, blockEndTime) => 
      now.isAfter(blockEndTime));
    
    // Remove old attempt records
    _attemptRecords.forEach((key, attempts) {
      final typeStr = key.split(':')[1];
      final type = RateLimitType.values.firstWhere(
        (t) => t.toString() == typeStr,
        orElse: () => RateLimitType.apiCall,
      );
      final config = _configs[type]!;
      
      attempts.removeWhere((attempt) => 
        now.difference(attempt) > config.windowDuration);
    });
    
    // Remove empty attempt records
    _attemptRecords.removeWhere((key, attempts) => attempts.isEmpty);
  }

  /// Get statistics for monitoring
  RateLimitStats getStats() {
    cleanup(); // Clean up first
    
    return RateLimitStats(
      totalBlockedIdentifiers: _blockedUntil.length,
      totalTrackedIdentifiers: _attemptRecords.length,
      blockedByType: _getBlockedCountByType(),
      attemptsByType: _getAttemptsCountByType(),
    );
  }

  // Private helper methods

  String _generateKey(String identifier, RateLimitType type, String? secondary) {
    final key = secondary != null 
      ? '$identifier:${type.toString()}:$secondary'
      : '$identifier:${type.toString()}';
    return key;
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return '${duration.inSeconds} second${duration.inSeconds > 1 ? 's' : ''}';
    }
  }

  void _logRateLimitViolation(String identifier, RateLimitType type) {
    // Log to security monitoring service
    AppLogger.warning(
      'Rate limit violation: $identifier for ${type.toString()}',
      category: LogCategory.security,
      data: {
        'identifier': identifier,
        'limitType': type.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Map<RateLimitType, int> _getBlockedCountByType() {
    final counts = <RateLimitType, int>{};
    for (final key in _blockedUntil.keys) {
      final parts = key.split(':');
      if (parts.length >= 2) {
        final typeStr = parts[1];
        final type = RateLimitType.values.firstWhere(
          (t) => t.toString() == typeStr,
          orElse: () => RateLimitType.apiCall,
        );
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<RateLimitType, int> _getAttemptsCountByType() {
    final counts = <RateLimitType, int>{};
    for (final entry in _attemptRecords.entries) {
      final parts = entry.key.split(':');
      if (parts.length >= 2) {
        final typeStr = parts[1];
        final type = RateLimitType.values.firstWhere(
          (t) => t.toString() == typeStr,
          orElse: () => RateLimitType.apiCall,
        );
        counts[type] = (counts[type] ?? 0) + entry.value.length;
      }
    }
    return counts;
  }

  /// Reset all rate limiting data (use with caution)
  void resetAll() {
    _attemptRecords.clear();
    _blockedUntil.clear();
  }

  /// Start periodic cleanup (call this on app initialization)
  Timer? _cleanupTimer;
  
  void startPeriodicCleanup({Duration interval = const Duration(minutes: 5)}) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(interval, (_) => cleanup());
  }
  
  void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}

// Supporting classes and enums

enum RateLimitType {
  login,
  passwordReset,
  emailSend,
  apiCall,
  registration,
  quoteCreation,
}

class RateLimitConfig {
  final int maxAttempts;
  final Duration windowDuration;
  final Duration blockDuration;

  RateLimitConfig({
    required this.maxAttempts,
    required this.windowDuration,
    required this.blockDuration,
  });
}

class RateLimitResult {
  final bool allowed;
  final int remainingAttempts;
  final Duration? blockedFor;
  final String? message;

  RateLimitResult({
    required this.allowed,
    required this.remainingAttempts,
    this.blockedFor,
    this.message,
  });

  bool get isBlocked => !allowed && blockedFor != null;
  bool get isWarning => allowed && remainingAttempts <= 2;
}

class RateLimitStats {
  final int totalBlockedIdentifiers;
  final int totalTrackedIdentifiers;
  final Map<RateLimitType, int> blockedByType;
  final Map<RateLimitType, int> attemptsByType;

  RateLimitStats({
    required this.totalBlockedIdentifiers,
    required this.totalTrackedIdentifiers,
    required this.blockedByType,
    required this.attemptsByType,
  });
}