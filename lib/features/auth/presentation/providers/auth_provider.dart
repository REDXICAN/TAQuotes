// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/realtime_database_service.dart';
import '../../../../core/services/hybrid_database_service.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/services/product_cache_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/rbac_service.dart';
import '../../../../core/models/models.dart';
import '../../../../core/models/user_role.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Realtime Database Service Provider
final databaseServiceProvider = Provider<RealtimeDatabaseService>((ref) {
  return RealtimeDatabaseService();
});

// Project-related providers
final allProjectsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getProjects();
});

final projectsByClientProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, clientId) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getProjects(clientId: clientId);
});

final quotesByProjectProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getQuotesByProject(projectId);
});

// Hybrid Database Service Provider (for Firestore + Realtime)
final hybridDatabaseProvider = Provider<HybridDatabaseService>((ref) {
  return HybridDatabaseService();
});

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

// Current User Profile Provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final dbService = ref.watch(databaseServiceProvider);
  final profileData = await dbService.getUserProfile(user.uid);

  if (profileData == null) return null;

  return UserProfile.fromJson(profileData);
});

// Cart Item Count Provider
final cartItemCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(0);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getCartItems().map((items) => items.length);
});

// Auto-refreshing Total Clients Provider
final totalClientsProvider = StreamProvider.autoDispose<int>((ref) async* {
  final dbService = ref.watch(databaseServiceProvider);

  // Initial load
  yield await dbService.getTotalClients();

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await dbService.getTotalClients();
    } catch (e) {
      // Continue with previous data on error
      yield 0;
    }
  }
});

// Auto-refreshing Total Quotes Provider
final totalQuotesProvider = StreamProvider.autoDispose<int>((ref) async* {
  final dbService = ref.watch(databaseServiceProvider);

  // Initial load
  yield await dbService.getTotalQuotes();

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await dbService.getTotalQuotes();
    } catch (e) {
      // Continue with previous data on error
      yield 0;
    }
  }
});

// Auto-refreshing Total Products Provider
final totalProductsProvider = StreamProvider.autoDispose<int>((ref) async* {
  final dbService = ref.watch(databaseServiceProvider);

  // Initial load
  yield await dbService.getTotalProducts();

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await dbService.getTotalProducts();
    } catch (e) {
      // Continue with previous data on error
      yield 0;
    }
  }
});

// Recent Quotes Provider
final recentQuotesProvider = StreamProvider.autoDispose<List<Quote>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getQuotes().map((quotesList) {
    // Convert to Quote models and limit to 10
    final quotes =
        quotesList.map((json) => Quote.fromJson(json)).take(10).toList();
    return quotes;
  });
});

// Legacy Pending User Approvals Provider (deprecated - use one from user_approvals_widget.dart)
final legacyPendingUserApprovalsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getPendingUserApprovals();
});

// Theme Mode Provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark); // Default to dark mode for Apple styling

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggleDarkMode(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

// Sign In Method Provider
final signInProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);

  return (String email, String password) async {
    try {
      final user = await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        // Check user role for approval bypass
        final isSuperAdmin = await RBACService.isSuperAdmin();

        if (!isSuperAdmin) {
          // Check if user account is approved
          final dbService = ref.watch(databaseServiceProvider);
          final userProfile = await dbService.getUserProfile(user.uid);

          if (userProfile != null) {
            final status = userProfile['status'] ?? 'active';
            final role = userProfile['role'] ?? '';

            // Block access for pending users
            if (status == 'pending_approval' || role == 'pending') {
              await authService.signOut(); // Sign them out immediately
              return 'Your account is pending approval. You will receive an email once approved.';
            }
          }
        }
      }

      // Cache all products after successful login
      try {
        AppLogger.info('Caching products after login', category: LogCategory.auth);
        await ProductCacheService.instance.cacheAllProducts();
      } catch (e) {
        AppLogger.error('Failed to cache products after login', error: e, category: LogCategory.auth);
        // Don't fail login if caching fails
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      AppLogger.warning(
        'Firebase authentication error: ${e.code}',
        category: LogCategory.auth,
        error: e,
      );

      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'wrong-password':
          return 'Wrong password provided';
        case 'invalid-email':
          return 'Invalid email address';
        case 'user-disabled':
          return 'This user has been disabled';
        case 'too-many-requests':
          return 'Too many failed login attempts. Please try again later or reset your password';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection';
        case 'invalid-credential':
          return 'Invalid email or password';
        default:
          return e.message ?? 'An error occurred during sign in';
      }
    } catch (e) {
      AppLogger.error(
        'Unexpected error during sign in',
        category: LogCategory.auth,
        error: e,
      );
      return 'An unexpected error occurred: $e';
    }
  };
});

// Sign Up Method Provider with Role Support
final signUpProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);
  final dbService = ref.watch(databaseServiceProvider);

  return (String email, String password, String name, String role) async {
    try {
      final user = await authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      if (user != null) {
        // ALL new users require approval - set as pending initially
        String actualRole = 'pending';
        String requestedRoleNormalized = role;

        // Normalize role names
        if (role == 'Admin' || role == 'Administrator') {
          requestedRoleNormalized = 'admin';
        } else if (role == 'Sales' || role == 'Sales Representative') {
          requestedRoleNormalized = 'sales';
        } else if (role == 'Distribution' || role == 'Distributor') {
          requestedRoleNormalized = 'distributor';
        }

        // Create user approval request for ALL new users
        final requestId = await dbService.createUserApprovalRequest(
          userId: user.uid,
          email: email,
          name: name,
          requestedRole: requestedRoleNormalized,
        );

        // Create user profile in Realtime Database with pending status
        await dbService.createUserProfile(
          uid: user.uid,
          email: email,
          name: name,
          role: 'pending', // All users start as pending
          status: 'pending_approval',
        );

        // Send approval email to superadmin
        final emailService = EmailService();
        final approvalToken = DateTime.now().millisecondsSinceEpoch.toString() + user.uid;
        await emailService.sendUserApprovalEmail(
          requestId: requestId,
          userEmail: email,
          userName: name,
          requestedRole: requestedRoleNormalized,
          approvalToken: approvalToken,
        );

        // Send notification to user about pending approval
        await emailService.sendUserPendingNotification(
          userEmail: email,
          userName: name,
          requestedRole: requestedRoleNormalized,
        );
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'The password is too weak';
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'invalid-email':
          return 'Invalid email address';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a few minutes and try again';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection';
        default:
          return e.message ?? 'An error occurred during sign up';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  };
});

// Handle registration emails
Future<void> _handleRegistrationEmails(String email, String name, String role, String uid, RealtimeDatabaseService dbService) async {
  try {
    // Import email service at the top of the file if not already imported
    final emailService = EmailService();
    final adminEmail = dotenv.env['ADMIN_EMAIL'] ?? '';

    if (role == 'Admin') {
      // Send approval request to superadmin
      await emailService.sendQuoteEmail(
        recipientEmail: adminEmail,
        recipientName: 'Turbo Air Admin',
        quoteNumber: 'ADMIN_APPROVAL',
        htmlContent: '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">New Admin Account Approval Required</h2>
    
    <p>Dear Admin,</p>
    
    <p>A new administrator account has been created and requires your approval:</p>
    
    <table style="width: 100%; border-collapse: collapse; margin: 20px 0; border: 1px solid #ddd;">
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Name</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$name</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Email</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$email</td>
      </tr>
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Role</td>
        <td style="padding: 12px; border: 1px solid #ddd;">Administrator</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">User ID</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$uid</td>
      </tr>
    </table>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="https://turboair-taq.web.app/admin/approve/$uid" 
         style="background-color: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
        Approve Account
      </a>
      <a href="https://turboair-taq.web.app/admin/reject/$uid" 
         style="background-color: #dc3545; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block; margin-left: 10px;">
        Reject Account
      </a>
    </div>
    
    <p style="color: #666; font-size: 12px; margin-top: 20px;">
      Please review this request carefully. Once approved, the user will have administrator privileges.
    </p>
  </div>
</body>
</html>
        ''',
        userInfo: {
          'name': 'Turbo Air System',
          'email': 'system@turboairmexico.com',
          'role': 'System',
        },
      );

      // Send pending notification to the user
      await emailService.sendQuoteEmail(
        recipientEmail: email,
        recipientName: name,
        quoteNumber: 'REGISTRATION_PENDING',
        htmlContent: '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">Account Registration Received</h2>
    
    <p>Dear $name,</p>
    
    <p>Thank you for registering for a TurboAir administrator account. Your registration has been received and is currently pending approval.</p>
    
    <div style="background-color: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107;">
      <p style="margin: 0; color: #856404;">
        <strong>⏳ Status:</strong> Your account is pending administrator approval. You will receive an email confirmation once your account has been reviewed and approved.
      </p>
    </div>
    
    <p>This process typically takes 1-2 business days. If you have any questions, please contact our support team.</p>
    
    <p>Best regards,<br>TurboAir Team</p>
  </div>
</body>
</html>
        ''',
        userInfo: {
          'name': 'Turbo Air System',
          'email': 'system@turboairmexico.com',
          'role': 'System',
        },
      );
    } else {
      // Send welcome email for Sales/Distribution users
      await emailService.sendQuoteEmail(
        recipientEmail: email,
        recipientName: name,
        quoteNumber: 'WELCOME',
        htmlContent: '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">Welcome to TurboAir!</h2>
    
    <p>Dear $name,</p>
    
    <p>Congratulations! Your TurboAir ${role.toLowerCase()} account has been successfully created and activated.</p>
    
    <div style="background-color: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #28a745;">
      <p style="margin: 0; color: #155724;">
        <strong>✅ Account Status:</strong> Active and ready to use
      </p>
    </div>
    
    <p>You can now access the TurboAir platform with the following features:</p>
    <ul>
      <li>Browse our complete product catalog</li>
      <li>Create and manage client relationships</li>
      <li>Generate professional quotes</li>
      <li>Export data in multiple formats</li>
    </ul>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="https://turboair-taq.web.app" 
         style="background-color: #0066cc; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
        Access Your Account
      </a>
    </div>
    
    <p>If you have any questions or need assistance, don't hesitate to reach out to our support team.</p>
    
    <p>Best regards,<br>TurboAir Team</p>
  </div>
</body>
</html>
        ''',
        userInfo: {
          'name': 'Turbo Air System',
          'email': 'system@turboairmexico.com',
          'role': 'System',
        },
      );
    }
  } catch (e) {
    AppLogger.error('Error sending registration emails', error: e);
    // Don't throw error as account creation should still succeed
  }
}

// Sign Out Method Provider
final signOutProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);

  return () async {
    try {
      await authService.signOut();
    } catch (e) {
      // Error signing out
    }
  };
});

// Password Reset Method Provider
final resetPasswordProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);

  return (String email) async {
    try {
      await authService.sendPasswordResetEmail(email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return e.message ?? 'An error occurred sending reset email';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  };
});

// Update Profile Method Provider
final updateProfileProvider = Provider((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final user = ref.watch(currentUserProvider);

  return (String name) async {
    try {
      if (user == null) return 'No user signed in';

      // Update in Realtime Database
      await dbService.updateUserProfile(
        user.uid,
        {'name': name},
      );

      // Update Firebase Auth display name
      await user.updateDisplayName(name);

      return null; // Success
    } catch (e) {
      return 'Failed to update profile';
    }
  };
});

// Change Password Method Provider
final changePasswordProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);
  final user = ref.watch(currentUserProvider);

  return (String currentPassword, String newPassword) async {
    try {
      if (user == null || user.email == null) {
        return 'No user signed in';
      }

      // Re-authenticate user
      await authService.reauthenticateUser(
        email: user.email!,
        password: currentPassword,
      );

      // Update password
      await authService.updatePassword(newPassword);

      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          return 'Current password is incorrect';
        case 'weak-password':
          return 'New password is too weak';
        default:
          return e.message ?? 'An error occurred changing password';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  };
});

// RBAC Providers

// Current User Role Provider
final currentUserRoleProvider = FutureProvider<UserRole>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return UserRole.distributor;
  }

  return await RBACService.getUserRole(user.uid);
});

// Permission Check Provider
final permissionProvider = FutureProvider.family<bool, String>((ref, permission) async {
  return await RBACService.hasPermission(permission);
});

// SuperAdmin Check Provider
final isSuperAdminProvider = FutureProvider<bool>((ref) async {
  return await RBACService.isSuperAdmin();
});

// Admin or Above Check Provider
final isAdminOrAboveProvider = FutureProvider<bool>((ref) async {
  return await RBACService.isAdminOrAbove();
});

// RBAC Helper Methods Provider
final rbacProvider = Provider<RBACService>((ref) {
  return RBACService();
});

// Initialize SuperAdmin role on app start
final initializeSuperAdminProvider = FutureProvider<void>((ref) async {
  await RBACService.ensureSuperAdminRole();
});
