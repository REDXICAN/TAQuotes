// lib/core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_logger.dart';
import 'rate_limiter_service.dart';
import 'email_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final RateLimiterService _rateLimiter = RateLimiterService();
  final EmailService _emailService = EmailService();

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
    final cleanEmail = email.trim().toLowerCase();

    // Check rate limiting before attempting login
    final rateLimitResult = _rateLimiter.checkRateLimit(
      identifier: cleanEmail,
      type: RateLimitType.login,
    );

    if (!rateLimitResult.allowed) {
      AppLogger.warning(
        'Login rate limit exceeded for email: $cleanEmail',
        category: LogCategory.security,
        data: {
          'email': cleanEmail,
          'blockedFor': rateLimitResult.blockedFor?.inMinutes,
          'remainingAttempts': rateLimitResult.remainingAttempts,
        },
      );

      return AuthResult(
        success: false,
        error: rateLimitResult.message ?? 'Too many login attempts. Please try again later.',
      );
    }

    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      // Check if user is approved before allowing login
      if (result.user != null) {
        final approvalStatus = await _checkUserApprovalStatus(result.user!.uid);
        if (approvalStatus != null) {
          // User is not approved, sign them out and return error
          await _auth.signOut();
          return AuthResult(
            success: false,
            error: approvalStatus,
          );
        }
      }

      // Login successful - record success to reset rate limiting
      _rateLimiter.recordSuccess(
        identifier: cleanEmail,
        type: RateLimitType.login,
        resetCounter: true,
      );

      AppLogger.info('User logged in successfully', category: LogCategory.auth);
      return AuthResult(
        success: true,
        user: result.user,
      );
    } catch (e) {
      AppLogger.error('Sign in failed', error: e, category: LogCategory.auth);

      // Don't reset rate limit counter on failed login - this tracks failed attempts
      return AuthResult(
        success: false,
        error: _getReadableAuthError(e),
      );
    }
  }

  // Password reset (returns AuthResult)
  Future<AuthResult> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check rate limiting for password reset
    final rateLimitResult = _rateLimiter.checkRateLimit(
      identifier: cleanEmail,
      type: RateLimitType.passwordReset,
    );

    if (!rateLimitResult.allowed) {
      AppLogger.warning(
        'Password reset rate limit exceeded for email: $cleanEmail',
        category: LogCategory.security,
        data: {
          'email': cleanEmail,
          'blockedFor': rateLimitResult.blockedFor?.inMinutes,
          'remainingAttempts': rateLimitResult.remainingAttempts,
        },
      );

      return AuthResult(
        success: false,
        error: rateLimitResult.message ?? 'Too many password reset attempts. Please try again later.',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);

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
      // Log detailed error for debugging but show generic message to user
      AppLogger.error('Authentication error: ${error.code}',
        error: error,
        category: LogCategory.auth,
        data: {'errorCode': error.code, 'errorMessage': error.message}
      );

      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          // Use generic message to prevent user enumeration attacks
          return 'Invalid email or password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'weak-password':
          return 'Password must be at least 6 characters long';
        case 'network-request-failed':
          return 'Network error. Please check your connection';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later';
        case 'user-disabled':
          return 'This account has been disabled';
        default:
          // Don't expose internal error messages in production
          AppLogger.error('Unhandled auth error: ${error.code}',
            error: error,
            category: LogCategory.auth
          );
          return 'Authentication failed. Please try again later.';
      }
    }

    // Log the error for debugging but show generic message
    AppLogger.error('Non-Firebase auth error',
      error: error,
      category: LogCategory.auth
    );
    return 'Authentication failed. Please try again.';
  }

  // Check user approval status
  Future<String?> _checkUserApprovalStatus(String uid) async {
    try {
      final database = FirebaseDatabase.instance;
      final userProfileSnapshot = await database.ref('user_profiles/$uid').get();

      if (userProfileSnapshot.exists && userProfileSnapshot.value != null) {
        final profileData = Map<String, dynamic>.from(userProfileSnapshot.value as Map);
        final status = profileData['status'] ?? 'active';
        final role = profileData['role'] ?? '';

        // Check if user is pending approval
        if (status == 'pending_approval' || role == 'pending') {
          return 'Your account is pending approval. You will receive an email notification once your account has been reviewed and approved by our administrators.';
        }

        // Check if user is disabled
        if (status == 'disabled' || status == 'inactive') {
          return 'Your account has been disabled. Please contact support for assistance.';
        }

        // Check if user was rejected
        if (status == 'rejected') {
          return 'Your account registration was not approved. Please contact support if you believe this is an error.';
        }
      }

      return null; // User is approved
    } catch (e) {
      AppLogger.error('Error checking user approval status', error: e, category: LogCategory.auth);
      return 'Unable to verify account status. Please try again later.';
    }
  }

  // COMPATIBILITY METHODS FOR MIGRATION FROM FirebaseAuthService

  // Sign in with email and password (FirebaseAuthService compatible)
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check approval status
      if (credential.user != null) {
        final approvalStatus = await _checkUserApprovalStatus(credential.user!.uid);
        if (approvalStatus != null) {
          // User is not approved, sign them out and throw error
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-approved',
            message: approvalStatus,
          );
        }
      }

      AppLogger.info('User logged in successfully', category: LogCategory.auth);
      return credential.user;
    } catch (e) {
      AppLogger.error('Sign in failed', error: e, category: LogCategory.auth);
      rethrow;
    }
  }

  // Create user with email and password (FirebaseAuthService compatible)
  Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String? requestedRole,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);

        // Create user profile in Realtime Database with pending status
        await _createUserProfile(
          uid: credential.user!.uid,
          email: email,
          name: name,
          requestedRole: requestedRole ?? 'distributor',
        );
      }

      AppLogger.info('User registered successfully', category: LogCategory.auth);
      return credential.user;
    } catch (e) {
      AppLogger.error('Sign up failed', error: e, category: LogCategory.auth);
      rethrow;
    }
  }

  // Create user profile in Realtime Database
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String name,
    String? requestedRole,
  }) async {
    // All new registrations start as pending
    await _database.ref('user_profiles/$uid').set({
      'uid': uid,
      'email': email,
      'name': name,
      'role': 'pending',  // Changed from 'distributor' to 'pending'
      'requested_role': requestedRole ?? 'distributor',
      'status': 'pending_approval',  // Added status field
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });

    // Create approval request
    final requestId = _database.ref('user_approval_requests').push().key;
    if (requestId != null) {
      await _database.ref('user_approval_requests/$requestId').set({
        'user_id': uid,
        'email': email,
        'name': name,
        'requested_role': requestedRole ?? 'distributor',
        'status': 'pending',
        'created_at': ServerValue.timestamp,
      });

      // Send email notifications
      try {
        // Send email to admin for approval
        // Generate a simple approval token
        final approvalToken = DateTime.now().millisecondsSinceEpoch.toString();

        await _emailService.sendUserApprovalEmail(
          requestId: requestId,
          userEmail: email,
          userName: name,
          requestedRole: requestedRole ?? 'distributor',
          approvalToken: approvalToken,
        );

        // Send welcome/pending email to user
        await _emailService.sendUserPendingNotification(
          userEmail: email,
          userName: name,
          requestedRole: requestedRole ?? 'distributor',
        );

        AppLogger.info('Approval request emails sent successfully', category: LogCategory.auth);
      } catch (e) {
        AppLogger.error('Failed to send approval emails', error: e, category: LogCategory.auth);
      }
    }
  }

  // Get user profile from Realtime Database
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final snapshot = await _database.ref('user_profiles/$uid').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data['id'] = uid;
        return data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting user profile', error: e, category: LogCategory.auth);
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _database.ref('user_profiles/$uid').update({
      ...data,
      'updated_at': ServerValue.timestamp,
    });
  }

  // Send password reset email (FirebaseAuthService compatible)
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Reauthenticate user
  Future<void> reauthenticateUser({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  // Delete user
  Future<void> deleteUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Delete user profile from database
      await _database.ref('user_profiles/${user.uid}').remove();
      // Delete auth user
      await user.delete();
    }
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
