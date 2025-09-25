// lib/core/services/cloud_functions_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';
import 'app_logger.dart';
import 'rbac_service.dart';

/// Service for interacting with Firebase Cloud Functions related to user roles
class CloudFunctionsService {
  static final CloudFunctionsService _instance = CloudFunctionsService._internal();
  factory CloudFunctionsService() => _instance;
  CloudFunctionsService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Set custom role claims for a user (SuperAdmin only)
  Future<bool> setUserRole(String userId, UserRole role) async {
    try {
      // Verify current user has permission
      final canModifyRoles = await RBACService.hasPermission('modify_user_roles');
      if (!canModifyRoles) {
        AppLogger.warning('Unauthorized attempt to modify user role');
        return false;
      }

      final callable = _functions.httpsCallable('setUserRole');
      final result = await callable.call({
        'userId': userId,
        'role': role.value,
      });

      if (result.data['success'] == true) {
        AppLogger.info('Successfully set role ${role.displayName} for user $userId');

        // Clear RBAC cache for the affected user
        RBACService.clearUserCache(userId);

        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error setting user role', error: e);
      return false;
    }
  }

  /// Initialize SuperAdmin role and custom claims
  Future<bool> initializeSuperAdmin() async {
    try {
      final callable = _functions.httpsCallable('initializeSuperAdmin');
      final result = await callable.call();

      if (result.data['success'] == true) {
        AppLogger.info('SuperAdmin role initialized successfully');

        // Clear RBAC cache
        RBACService.clearCache();

        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error initializing SuperAdmin', error: e);
      return false;
    }
  }

  /// Get detailed role information for a user
  Future<UserRoleInfo?> getUserRoleInfo(String? userId) async {
    try {
      final callable = _functions.httpsCallable('getUserRole');
      final result = await callable.call({
        if (userId != null) 'userId': userId,
      });

      if (result.data['success'] == true) {
        return UserRoleInfo.fromMap(result.data);
      }

      return null;
    } catch (e) {
      AppLogger.error('Error getting user role info', error: e);
      return null;
    }
  }

  /// Sync all user roles from database to custom claims (SuperAdmin only)
  Future<RoleSyncResult?> syncUserRoles() async {
    try {
      final isSuperAdmin = await RBACService.isSuperAdmin();
      if (!isSuperAdmin) {
        AppLogger.warning('Unauthorized attempt to sync user roles');
        return null;
      }

      final callable = _functions.httpsCallable('syncUserRoles');
      final result = await callable.call();

      if (result.data['success'] == true) {
        AppLogger.info('User roles synced successfully');

        // Clear all RBAC cache after sync
        RBACService.clearCache();

        return RoleSyncResult.fromMap(result.data);
      }

      return null;
    } catch (e) {
      AppLogger.error('Error syncing user roles', error: e);
      return null;
    }
  }

  /// Force refresh of current user's custom claims
  Future<bool> refreshUserClaims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Force refresh of ID token to get updated custom claims
      await user.getIdToken(true);

      // Clear RBAC cache for current user
      RBACService.clearUserCache(user.uid);

      AppLogger.info('User claims refreshed successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error refreshing user claims', error: e);
      return false;
    }
  }

  /// Batch update multiple user roles
  Future<List<RoleUpdateResult>> batchUpdateUserRoles(
    Map<String, UserRole> userRoles,
  ) async {
    final results = <RoleUpdateResult>[];

    for (final entry in userRoles.entries) {
      final userId = entry.key;
      final role = entry.value;

      final success = await setUserRole(userId, role);
      results.add(RoleUpdateResult(
        userId: userId,
        targetRole: role,
        success: success,
        timestamp: DateTime.now(),
      ));
    }

    return results;
  }
}

/// Model for user role information returned from Cloud Function
class UserRoleInfo {
  final String userId;
  final String email;
  final UserRole role;
  final Map<String, dynamic> customClaims;
  final DateTime? lastSignInTime;
  final DateTime? creationTime;

  UserRoleInfo({
    required this.userId,
    required this.email,
    required this.role,
    required this.customClaims,
    this.lastSignInTime,
    this.creationTime,
  });

  factory UserRoleInfo.fromMap(Map<String, dynamic> data) {
    return UserRoleInfo(
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      role: UserRole.fromString(data['role'] ?? 'distributor'),
      customClaims: Map<String, dynamic>.from(data['customClaims'] ?? {}),
      lastSignInTime: data['lastSignInTime'] != null
          ? DateTime.tryParse(data['lastSignInTime'])
          : null,
      creationTime: data['creationTime'] != null
          ? DateTime.tryParse(data['creationTime'])
          : null,
    );
  }
}

/// Model for role sync operation results
class RoleSyncResult {
  final bool success;
  final String message;
  final int totalUsers;
  final int successCount;
  final int errorCount;
  final List<Map<String, dynamic>> results;

  RoleSyncResult({
    required this.success,
    required this.message,
    required this.totalUsers,
    required this.successCount,
    required this.errorCount,
    required this.results,
  });

  factory RoleSyncResult.fromMap(Map<String, dynamic> data) {
    return RoleSyncResult(
      success: data['success'] ?? false,
      message: data['message'] ?? '',
      totalUsers: data['totalUsers'] ?? 0,
      successCount: data['successCount'] ?? 0,
      errorCount: data['errorCount'] ?? 0,
      results: List<Map<String, dynamic>>.from(data['results'] ?? []),
    );
  }
}

/// Model for individual role update results
class RoleUpdateResult {
  final String userId;
  final UserRole targetRole;
  final bool success;
  final DateTime timestamp;
  final String? error;

  RoleUpdateResult({
    required this.userId,
    required this.targetRole,
    required this.success,
    required this.timestamp,
    this.error,
  });
}