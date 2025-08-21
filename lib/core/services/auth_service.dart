// lib/core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';
import 'rate_limiter_service.dart';
import 'validation_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RateLimiterService _rateLimiter = RateLimiterService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email & password with validation and rate limiting
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    // Validate email
    final emailValidation = ValidationService.validateField(
      value: email,
      fieldType: FieldType.email,
      fieldName: 'Email',
    );
    
    if (!emailValidation.isValid) {
      return AuthResult(
        success: false,
        error: emailValidation.error ?? 'Invalid email',
      );
    }

    // Validate password strength
    final passwordStrength = ValidationService.validatePassword(password);
    if (!passwordStrength.isValid) {
      return AuthResult(
        success: false,
        error: passwordStrength.message,
      );
    }

    // Check rate limit for registration
    final rateLimitCheck = _rateLimiter.checkRateLimit(
      identifier: email.toLowerCase(),
      type: RateLimitType.registration,
    );

    if (!rateLimitCheck.allowed) {
      AppLogger.warning(
        'Registration rate limit exceeded for $email',
        category: LogCategory.auth,
      );
      return AuthResult(
        success: false,
        error: rateLimitCheck.message ?? 'Too many registration attempts',
      );
    }

    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: emailValidation.sanitizedValue!,
        password: password,
      );
      
      // Record successful registration
      _rateLimiter.recordSuccess(
        identifier: email.toLowerCase(),
        type: RateLimitType.registration,
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

  // Sign in with email & password with rate limiting
  Future<AuthResult> signInWithEmail(String email, String password) async {
    // Validate email format
    if (!ValidationService.isValidEmail(email)) {
      return AuthResult(
        success: false,
        error: 'Please enter a valid email address',
      );
    }

    // Sanitize email
    final sanitizedEmail = ValidationService.sanitizeForDatabase(email.toLowerCase());

    // Check rate limit
    final rateLimitCheck = _rateLimiter.checkRateLimit(
      identifier: sanitizedEmail,
      type: RateLimitType.login,
    );

    if (!rateLimitCheck.allowed) {
      AppLogger.warning(
        'Login rate limit exceeded for email',
        category: LogCategory.auth,
      );
      return AuthResult(
        success: false,
        error: rateLimitCheck.message ?? 'Too many login attempts. Please try again later.',
        remainingAttempts: rateLimitCheck.remainingAttempts,
      );
    }

    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,
      );
      
      // Record successful login
      _rateLimiter.recordSuccess(
        identifier: sanitizedEmail,
        type: RateLimitType.login,
      );
      
      AppLogger.info('User logged in successfully', category: LogCategory.auth);
      return AuthResult(
        success: true,
        user: result.user,
        warning: rateLimitCheck.message,
      );
    } catch (e) {
      AppLogger.error('Sign in failed', error: e, category: LogCategory.auth);
      
      // Show remaining attempts if available
      final remainingMessage = rateLimitCheck.remainingAttempts > 0
        ? ' (${rateLimitCheck.remainingAttempts} attempts remaining)'
        : '';
      
      return AuthResult(
        success: false,
        error: _getReadableAuthError(e) + remainingMessage,
        remainingAttempts: rateLimitCheck.remainingAttempts,
      );
    }
  }

  // Password reset with rate limiting
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    // Validate email
    if (!ValidationService.isValidEmail(email)) {
      return AuthResult(
        success: false,
        error: 'Please enter a valid email address',
      );
    }

    final sanitizedEmail = ValidationService.sanitizeForDatabase(email.toLowerCase());

    // Check rate limit
    final rateLimitCheck = _rateLimiter.checkRateLimit(
      identifier: sanitizedEmail,
      type: RateLimitType.passwordReset,
    );

    if (!rateLimitCheck.allowed) {
      return AuthResult(
        success: false,
        error: rateLimitCheck.message ?? 'Too many password reset attempts',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: sanitizedEmail);
      
      AppLogger.info('Password reset email sent', category: LogCategory.auth);
      return AuthResult(
        success: true,
        message: 'Password reset email sent to $sanitizedEmail',
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
  final String? warning;
  final int? remainingAttempts;

  AuthResult({
    required this.success,
    this.user,
    this.error,
    this.message,
    this.warning,
    this.remainingAttempts,
  });
}
