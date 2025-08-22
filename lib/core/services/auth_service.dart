// lib/core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email & password
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      AppLogger.info('User registered successfully', category: LogCategory.auth);
      return AuthResult(
        success: true,
        user: result.user,
      );
    } catch (e) {
      AppLogger.error('Sign up failed', error: e, category: LogCategory.auth);
      return AuthResult(
        success: false,
        error: _getReadableAuthError(e),
      );
    }
  }

  // Sign in with email & password
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      AppLogger.info('User logged in successfully', category: LogCategory.auth);
      return AuthResult(
        success: true,
        user: result.user,
      );
    } catch (e) {
      AppLogger.error('Sign in failed', error: e, category: LogCategory.auth);
      
      return AuthResult(
        success: false,
        error: _getReadableAuthError(e),
      );
    }
  }

  // Password reset
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      AppLogger.info('Password reset email sent', category: LogCategory.auth);
      return AuthResult(
        success: true,
        message: 'Password reset email sent to $email',
      );
    } catch (e) {
      AppLogger.error('Password reset failed', error: e, category: LogCategory.auth);
      return AuthResult(
        success: false,
        error: _getReadableAuthError(e),
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      AppLogger.error('Sign out error', error: e, category: LogCategory.auth);
    }
  }

  // Helper method to get readable error messages
  String _getReadableAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'invalid-email':
          return 'Invalid email address';
        case 'weak-password':
          return 'Password is too weak';
        case 'network-request-failed':
          return 'Network error. Please check your connection';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later';
        case 'user-disabled':
          return 'This account has been disabled';
        default:
          return 'Authentication failed: ${error.message}';
      }
    }
    return 'Authentication failed. Please try again.';
  }
}

// Result class for auth operations
class AuthResult {
  final bool success;
  final User? user;
  final String? error;
  final String? message;

  AuthResult({
    required this.success,
    this.user,
    this.error,
    this.message,
  });
}
