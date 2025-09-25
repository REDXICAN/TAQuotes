// lib/core/widgets/session_timeout_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_timeout_service.dart';

/// Widget that wraps the app and monitors user interactions for session timeout
class SessionTimeoutWrapper extends StatefulWidget {
  final Widget child;

  const SessionTimeoutWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends State<SessionTimeoutWrapper> {
  final SessionTimeoutService _sessionService = SessionTimeoutService();

  @override
  void initState() {
    super.initState();
    _initializeSessionMonitoring();
  }

  void _initializeSessionMonitoring() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // User is logged in, start monitoring
        _sessionService.startMonitoring();
      } else {
        // User is logged out, stop monitoring
        _sessionService.stopMonitoring();
      }
    });
  }

  void _handleUserInteraction() {
    // Reset the session timeout on any user interaction
    _sessionService.resetTimer();
  }

  @override
  void dispose() {
    _sessionService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the child with gesture detection to track user interactions
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleUserInteraction,
      onPanUpdate: (_) => _handleUserInteraction(),
      onScaleUpdate: (_) => _handleUserInteraction(),
      child: MouseRegion(
        onHover: (_) => _handleUserInteraction(),
        child: Listener(
          onPointerMove: (_) => _handleUserInteraction(),
          onPointerDown: (_) => _handleUserInteraction(),
          child: widget.child,
        ),
      ),
    );
  }
}