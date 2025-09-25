// lib/core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

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

  // Password reset (returns AuthResult)
  Future<AuthResult> resetPassword(String email) async {
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
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);

        // Create user profile in Realtime Database
        await _createUserProfile(
          uid: credential.user!.uid,
          email: email,
          name: name,
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
