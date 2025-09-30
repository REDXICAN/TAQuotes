// lib/core/services/session_timeout_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

/// Service to handle automatic session timeout after inactivity
/// Logs out user automatically after 30 minutes of inactivity
class SessionTimeoutService {
  static final SessionTimeoutService _instance = SessionTimeoutService._internal();
  factory SessionTimeoutService() => _instance;
  SessionTimeoutService._internal();

  Timer? _inactivityTimer;
  Timer? _warningTimer;
  static const Duration _timeoutDuration = Duration(minutes: 30);
  static const Duration _warningDuration = Duration(minutes: 25);
  static const Duration _adminTimeoutDuration = Duration(minutes: 15); // Shorter for admin ops
  bool _isActive = false;
  DateTime? _lastActivity;
  bool _isAdminOperation = false;
  Function()? _onWarning;
  Function()? _onTimeout;

  /// Start monitoring user activity for session timeout
  void startMonitoring({
    bool isAdminOperation = false,
    Function()? onWarning,
    Function()? onTimeout,
  }) {
    if (_isActive) return;

    _isActive = true;
    _isAdminOperation = isAdminOperation;
    _onWarning = onWarning;
    _onTimeout = onTimeout;
    _lastActivity = DateTime.now();
    _resetTimer();

    final timeout = _isAdminOperation ? _adminTimeoutDuration : _timeoutDuration;
    AppLogger.info(
      'Session timeout monitoring started (${timeout.inMinutes} minute timeout)',
      category: LogCategory.security,
      data: {'isAdminOperation': isAdminOperation},
    );
  }

  /// Stop monitoring (e.g., when user logs out manually)
  void stopMonitoring() {
    _isActive = false;
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer = null;
    _lastActivity = null;
    _isAdminOperation = false;
    _onWarning = null;
    _onTimeout = null;

    AppLogger.debug(
      'Session timeout monitoring stopped',
      category: LogCategory.security,
    );
  }

  /// Reset the inactivity timer on user interaction
  void resetTimer() {
    if (!_isActive) return;
    _lastActivity = DateTime.now();
    _resetTimer();
  }

  /// Check if session is about to expire
  bool isAboutToExpire() {
    if (!_isActive || _lastActivity == null) return false;

    final timeout = _isAdminOperation ? _adminTimeoutDuration : _timeoutDuration;
    final timeSinceActivity = DateTime.now().difference(_lastActivity!);
    final timeRemaining = timeout - timeSinceActivity;

    return timeRemaining.inMinutes <= 5;
  }

  /// Get remaining session time
  Duration? getRemainingTime() {
    if (!_isActive || _lastActivity == null) return null;

    final timeout = _isAdminOperation ? _adminTimeoutDuration : _timeoutDuration;
    final timeSinceActivity = DateTime.now().difference(_lastActivity!);
    final timeRemaining = timeout - timeSinceActivity;

    return timeRemaining.isNegative ? Duration.zero : timeRemaining;
  }

  /// Internal method to reset the timer
  void _resetTimer() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();

    final timeout = _isAdminOperation ? _adminTimeoutDuration : _timeoutDuration;
    final warning = _isAdminOperation
        ? Duration(minutes: _adminTimeoutDuration.inMinutes - 2)
        : _warningDuration;

    // Set warning timer
    _warningTimer = Timer(warning, () {
      if (_onWarning != null) {
        _onWarning!();
      } else {
        AppLogger.warning(
          'Session will expire in ${(timeout - warning).inMinutes} minutes',
          category: LogCategory.security,
        );
      }
    });

    // Set timeout timer
    _inactivityTimer = Timer(timeout, () {
      _handleTimeout();
    });
  }

  /// Handle session timeout - logout the user
  Future<void> _handleTimeout() async {
    if (!_isActive) return;

    try {
      AppLogger.warning(
        'Session timeout reached - logging out user',
        category: LogCategory.security,
      );

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Stop monitoring
      stopMonitoring();

      AppLogger.info(
        'User logged out due to inactivity',
        category: LogCategory.security,
      );
    } catch (e) {
      AppLogger.error(
        'Error during session timeout logout',
        error: e,
        category: LogCategory.security,
      );
    }
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isActive;

  /// Get remaining time before timeout (for UI display if needed)
  Duration? get remainingTime {
    // This is a simplified version - would need more complex tracking for exact time
    return _isActive ? _timeoutDuration : null;
  }
}