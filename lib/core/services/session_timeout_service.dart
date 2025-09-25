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
  static const Duration _timeoutDuration = Duration(minutes: 30);
  bool _isActive = false;

  /// Start monitoring user activity for session timeout
  void startMonitoring() {
    if (_isActive) return;

    _isActive = true;
    _resetTimer();

    AppLogger.info(
      'Session timeout monitoring started (30 minute timeout)',
      category: LogCategory.security,
    );
  }

  /// Stop monitoring (e.g., when user logs out manually)
  void stopMonitoring() {
    _isActive = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    AppLogger.debug(
      'Session timeout monitoring stopped',
      category: LogCategory.security,
    );
  }

  /// Reset the inactivity timer on user interaction
  void resetTimer() {
    if (!_isActive) return;
    _resetTimer();
  }

  /// Internal method to reset the timer
  void _resetTimer() {
    _inactivityTimer?.cancel();

    _inactivityTimer = Timer(_timeoutDuration, () {
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