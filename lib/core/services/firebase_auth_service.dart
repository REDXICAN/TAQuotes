// lib/core/services/firebase_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_logger.dart';
import 'rate_limiter_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final RateLimiterService _rateLimiter = RateLimiterService();

  // Get auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
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

      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: rateLimitResult.message ?? 'Too many login attempts. Please try again later.',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      // Login successful - record success to reset rate limiting
      _rateLimiter.recordSuccess(
        identifier: cleanEmail,
        type: RateLimitType.login,
        resetCounter: true,
      );

      return credential.user;
    } catch (e) {
      // Don't reset rate limit counter on failed login - this tracks failed attempts
      rethrow;
    }
  }

  // Create user with email and password
  Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check rate limiting for registration
    final rateLimitResult = _rateLimiter.checkRateLimit(
      identifier: cleanEmail,
      type: RateLimitType.registration,
    );

    if (!rateLimitResult.allowed) {
      AppLogger.warning(
        'Registration rate limit exceeded for email: $cleanEmail',
        category: LogCategory.security,
        data: {
          'email': cleanEmail,
          'blockedFor': rateLimitResult.blockedFor?.inMinutes,
          'remainingAttempts': rateLimitResult.remainingAttempts,
        },
      );

      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: rateLimitResult.message ?? 'Too many registration attempts. Please try again later.',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);

        // Create user profile in Realtime Database
        await _createUserProfile(
          uid: credential.user!.uid,
          email: cleanEmail,
          name: name,
        );
      }

      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Create user profile in Realtime Database
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String name,
  }) async {
    await _database.ref('user_profiles/$uid').set({
      'uid': uid,
      'email': email,
      'name': name,
      'role': 'distributor',
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });
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
      // Error getting user profile
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

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
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

      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: rateLimitResult.message ?? 'Too many password reset attempts. Please try again later.',
      );
    }

    await _auth.sendPasswordResetEmail(email: cleanEmail);
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

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
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
