// lib/core/auth/services/rbac_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import '../models/rbac_permissions.dart';
import '../../services/realtime_database_service.dart';
import '../../services/app_logger.dart';
import '../../models/models.dart';

/// Service class for Role-Based Access Control operations
class RbacService {
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();

  /// Get user role from database
  Future<UserRole> getUserRole(String userId) async {
    try {
      final userProfile = await _databaseService.getUserProfile(userId);
      if (userProfile == null) {
        AppLogger.warning('User profile not found for ID: $userId');
        return UserRole.distributor; // Default role
      }

      final roleString = userProfile['role'] as String? ?? 'distributor';
      return UserRole.fromString(roleString);
    } catch (e) {
      AppLogger.error('Error getting user role', error: e, category: LogCategory.auth);
      return UserRole.distributor; // Default role on error
    }
  }

  /// Get user role from UserProfile object
  UserRole getUserRoleFromProfile(UserProfile profile) {
    return UserRole.fromString(profile.role);
  }

  /// Check if user has specific permission using pure RBAC
  Future<bool> hasPermission(String userId, Permission permission) async {
    try {
      final userRole = await getUserRole(userId);
      final hasPermission = RolePermissions.hasPermission(userRole, permission);

      // Log permission check for security audit
      logPermissionCheck(userId, permission, hasPermission);

      return hasPermission;
    } catch (e) {
      AppLogger.error('Error checking permission', error: e, category: LogCategory.auth);
      // Log failed permission check
      logPermissionCheck(userId, permission, false, additionalInfo: 'Error: ${e.toString()}');
      return false; // Deny access on error
    }
  }

  /// Check if user has specific role or higher
  Future<bool> hasRole(String userId, UserRole requiredRole) async {
    try {
      final userRole = await getUserRole(userId);
      return userRole.hasPrivilegeLevel(requiredRole);
    } catch (e) {
      AppLogger.error('Error checking role', error: e, category: LogCategory.auth);
      return false; // Deny access on error
    }
  }

  /// Update user role (only allowed by admins and super admins)
  Future<bool> updateUserRole(
    String adminUserId,
    String targetUserId,
    UserRole newRole, {
    String? reason,
  }) async {
    try {
      // Check if admin has permission to assign roles
      final adminRole = await getUserRole(adminUserId);
      if (!RolePermissions.hasPermission(adminRole, Permission.assignRoles)) {
        AppLogger.warning(
          'User $adminUserId attempted to assign role without permission',
          category: LogCategory.security,
        );
        return false;
      }

      // Check if admin can assign this specific role
      final assignableRoles = RoleHierarchy.getAssignableRoles(adminRole);
      if (!assignableRoles.contains(newRole)) {
        AppLogger.warning(
          'User $adminUserId attempted to assign role ${newRole.value} which is not assignable',
          category: LogCategory.security,
        );
        return false;
      }

      // Update the role in database
      await _databaseService.updateUserProfile(targetUserId, {
        'role': newRole.value,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Log the role change
      AppLogger.info(
        'Role updated: User $targetUserId role changed to ${newRole.value} by $adminUserId',
        category: LogCategory.auth,
        data: {'reason': reason},
      );

      return true;
    } catch (e) {
      AppLogger.error('Error updating user role', error: e, category: LogCategory.auth);
      return false;
    }
  }

  /// Get all permissions for a role
  Set<Permission> getPermissionsForRole(UserRole role) {
    return RolePermissions.getPermissionsForRole(role);
  }

  /// Check if user can manage another user
  Future<bool> canManageUser(String managerUserId, String targetUserId) async {
    try {
      final managerRole = await getUserRole(managerUserId);
      final targetRole = await getUserRole(targetUserId);

      return RoleHierarchy.canManageUser(managerRole, targetRole);
    } catch (e) {
      AppLogger.error('Error checking user management permission', error: e, category: LogCategory.auth);
      return false;
    }
  }

  /// Get users that can be managed by the current user
  Future<List<Map<String, dynamic>>> getManagedUsers(String managerUserId) async {
    try {
      final managerRole = await getUserRole(managerUserId);
      final subordinateRoles = RoleHierarchy.getAssignableRoles(managerRole);

      // This would need to be implemented in your database service
      // For now, returning empty list as placeholder
      // You'd want something like:
      // return await _databaseService.getUsersByRoles(subordinateRoles.map((r) => r.value).toList());

      return [];
    } catch (e) {
      AppLogger.error('Error getting managed users', error: e, category: LogCategory.auth);
      return [];
    }
  }

  /// Validate role assignment request
  Future<RoleValidationResult> validateRoleAssignment(
    String adminUserId,
    String targetUserId,
    UserRole newRole,
  ) async {
    try {
      // Check admin permissions
      final adminRole = await getUserRole(adminUserId);
      if (!RolePermissions.hasPermission(adminRole, Permission.assignRoles)) {
        return RoleValidationResult.error('You do not have permission to assign roles');
      }

      // Check if admin can assign this specific role
      final assignableRoles = RoleHierarchy.getAssignableRoles(adminRole);
      if (!assignableRoles.contains(newRole)) {
        return RoleValidationResult.error(
          'You do not have permission to assign the ${newRole.displayName} role',
        );
      }

      // Check if target user exists
      final targetProfile = await _databaseService.getUserProfile(targetUserId);
      if (targetProfile == null) {
        return RoleValidationResult.error('Target user not found');
      }

      // Additional business logic checks can go here
      // For example: prevent demoting the last super admin

      return RoleValidationResult.success('Role assignment is valid');
    } catch (e) {
      AppLogger.error('Error validating role assignment', error: e, category: LogCategory.auth);
      return RoleValidationResult.error('An error occurred while validating the role assignment');
    }
  }

  /// Check if user has Firebase custom claims for the specified role
  Future<bool> hasFirebaseCustomClaim(User user, String claim, dynamic expectedValue) async {
    try {
      final idTokenResult = await user.getIdTokenResult();
      final claims = idTokenResult.claims;

      if (claims == null) {
        AppLogger.warning('No custom claims found for user ${user.uid}', category: LogCategory.auth);
        return false;
      }

      final claimValue = claims[claim];
      return claimValue == expectedValue;
    } catch (e) {
      AppLogger.error('Error checking Firebase custom claims', error: e, category: LogCategory.auth);
      return false;
    }
  }

  /// Validate user role against Firebase custom claims
  Future<bool> validateRoleWithCustomClaims(String userId, UserRole expectedRole) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != userId) {
        AppLogger.warning('User not authenticated or ID mismatch', category: LogCategory.auth);
        return false;
      }

      // Check if user has the expected role in custom claims
      final hasValidClaim = await hasFirebaseCustomClaim(user, 'role', expectedRole.value);

      if (!hasValidClaim) {
        // Fallback to database role check for users without custom claims
        final dbRole = await getUserRole(userId);
        return dbRole == expectedRole;
      }

      return hasValidClaim;
    } catch (e) {
      AppLogger.error('Error validating role with custom claims', error: e, category: LogCategory.auth);
      return false;
    }
  }

  /// Get role statistics for admin dashboard
  Future<Map<String, int>> getRoleStatistics() async {
    try {
      // This would need to be implemented in your database service
      // Placeholder implementation
      return {
        'Super Admin': 1,
        'Admin': 5,
        'Sales': 25,
        'Distributor': 100,
      };
    } catch (e) {
      AppLogger.error('Error getting role statistics', error: e, category: LogCategory.auth);
      return {};
    }
  }

  /// Audit log for permission checks
  void logPermissionCheck(
    String userId,
    Permission permission,
    bool granted, {
    String? additionalInfo,
  }) {
    AppLogger.info(
      'Permission check: User $userId, Permission ${permission.value}, Granted: $granted',
      category: LogCategory.security,
      data: {
        'userId': userId,
        'permission': permission.value,
        'granted': granted,
        'additionalInfo': additionalInfo,
      },
    );
  }

  /// Bulk role assignment (for initial setup)
  Future<Map<String, bool>> bulkAssignRoles(
    String adminUserId,
    Map<String, UserRole> userRoleMap,
  ) async {
    final results = <String, bool>{};

    for (final entry in userRoleMap.entries) {
      final success = await updateUserRole(
        adminUserId,
        entry.key,
        entry.value,
        reason: 'Bulk role assignment',
      );
      results[entry.key] = success;
    }

    return results;
  }

  /// Get permission description for UI
  String getPermissionDescription(Permission permission) {
    return permission.displayName;
  }

  /// Get role description for UI
  String getRoleDescription(UserRole role) {
    return role.displayName;
  }
}

/// Result class for role validation operations
class RoleValidationResult {
  final bool isValid;
  final String message;

  const RoleValidationResult._(this.isValid, this.message);

  factory RoleValidationResult.success(String message) {
    return RoleValidationResult._(true, message);
  }

  factory RoleValidationResult.error(String message) {
    return RoleValidationResult._(false, message);
  }
}

/// Permission check result for auditing
class PermissionCheckResult {
  final Permission permission;
  final bool granted;
  final String reason;
  final DateTime timestamp;

  PermissionCheckResult({
    required this.permission,
    required this.granted,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'permission': permission.value,
      'granted': granted,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}