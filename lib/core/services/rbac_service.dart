// lib/core/services/rbac_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_role.dart';
import '../auth/models/rbac_permissions.dart';
import 'app_logger.dart';
import '../utils/safe_type_converter.dart';

class RBACService {
  static final RBACService _instance = RBACService._internal();
  factory RBACService() => _instance;
  RBACService._internal();

  // Cache for user roles to avoid repeated database calls
  static final Map<String, UserRole> _roleCache = {};

  /// Get the role for a specific user
  static Future<UserRole> getUserRole(String userId) async {
    try {
      // Check cache first
      if (_roleCache.containsKey(userId)) {
        return _roleCache[userId]!;
      }

      // Get user profile from database
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('users/$userId').once();

      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final userData = SafeTypeConverter.toMap(snapshot.snapshot.value);
        final roleString = userData['role'] as String? ?? 'distributor';
        final role = UserRole.fromString(roleString);

        // Cache the result
        _roleCache[userId] = role;
        return role;
      }

      // Default role if user not found
      return UserRole.distributor;
    } catch (e) {
      AppLogger.error('Error getting user role for $userId', error: e);
      return UserRole.distributor;
    }
  }

  /// Get the role for the current authenticated user
  static Future<UserRole> getCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return UserRole.distributor;
    }

    // Get user role from database - no email-based bypasses

    return await getUserRole(user.uid);
  }

  /// Check if current user has specific permission (string-based for backward compatibility)
  static Future<bool> hasPermission(String permission) async {
    final role = await getCurrentUserRole();

    switch (permission) {
      case 'manage_users':
        return role.canManageUsers;
      case 'manage_products':
        return role.canManageProducts;
      case 'create_quotes':
        return role.canCreateQuotes;
      case 'view_all_quotes':
        return role.canViewAllQuotes;
      case 'edit_pricing':
        return role.canEditPricing;
      case 'access_admin':
        return role.canAccessAdmin;
      case 'access_performance_dashboard':
        return role.canAccessPerformanceDashboard;
      case 'access_user_info_dashboard':
        return role.canAccessUserInfoDashboard;
      case 'access_stock_dashboard':
        return role.canAccessStockDashboard;
      case 'manage_backups':
        return role.canManageBackups;
      case 'export_data':
        return role.canExportData;
      case 'import_products':
        return role.canImportProducts;
      case 'modify_user_roles':
        return role.canModifyUserRoles;
      case 'view_error_monitoring':
        return role.canViewErrorMonitoring;
      case 'populate_demo_data':
        return role.canPopulateDemoData;
      default:
        AppLogger.warning('Unknown permission requested: $permission');
        return false;
    }
  }

  /// Check if current user has specific permission using Permission enum
  static Future<bool> hasPermissionEnum(Permission permission) async {
    final role = await getCurrentUserRole();
    return RolePermissions.hasPermission(role, permission);
  }

  /// Check if user has specific permission using Permission enum
  static Future<bool> userHasPermission(String userId, Permission permission) async {
    final role = await getUserRole(userId);
    return RolePermissions.hasPermission(role, permission);
  }

  /// Get all permissions for current user
  static Future<Set<Permission>> getCurrentUserPermissions() async {
    final role = await getCurrentUserRole();
    return RolePermissions.getPermissionsForRole(role);
  }

  /// Check if current user has role or higher
  static Future<bool> hasRoleOrHigher(UserRole requiredRole) async {
    final role = await getCurrentUserRole();
    return role.hasPrivilegeLevel(requiredRole);
  }

  /// Check if user can manage another user
  static Future<bool> canManageUser(String managerUserId, String targetUserId) async {
    final managerRole = await getUserRole(managerUserId);
    final targetRole = await getUserRole(targetUserId);
    return RoleHierarchy.canManageUser(managerRole, targetRole);
  }

  /// Get roles that current user can assign to others
  static Future<List<UserRole>> getAssignableRoles() async {
    final role = await getCurrentUserRole();
    return RoleHierarchy.getAssignableRoles(role);
  }

  /// Check if current user is SuperAdmin
  static Future<bool> isSuperAdmin() async {
    final role = await getCurrentUserRole();
    return role.isSuperAdmin;
  }

  /// Check if current user is Admin or above
  static Future<bool> isAdminOrAbove() async {
    final role = await getCurrentUserRole();
    return role.isAdminOrAbove;
  }

  /// Update user role in database with validation
  static Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('Unauthorized attempt to modify user role - no current user');
        return false;
      }

      // Check if admin has permission to assign roles
      final adminRole = await getCurrentUserRole();
      if (!adminRole.canModifyUserRoles) {
        AppLogger.warning(
          'Unauthorized attempt to modify user role by ${currentUser.email}',
          category: LogCategory.security,
        );
        return false;
      }

      // Check if admin can assign this specific role
      final assignableRoles = RoleHierarchy.getAssignableRoles(adminRole);
      if (!assignableRoles.contains(newRole)) {
        AppLogger.warning(
          'User ${currentUser.email} attempted to assign role ${newRole.value} which is not assignable',
          category: LogCategory.security,
        );
        return false;
      }

      final database = FirebaseDatabase.instance;
      await database.ref('users/$userId').update({
        'role': newRole.value,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUser.uid,
      });

      // Clear cache for this user
      _roleCache.remove(userId);

      // Log the role change
      AppLogger.info(
        'Role updated: User $userId role changed to ${newRole.value} by ${currentUser.uid}',
        category: LogCategory.auth,
      );

      return true;
    } catch (e) {
      AppLogger.error('Error updating user role for $userId', error: e);
      return false;
    }
  }

  /// Validate role assignment request
  static Future<RoleValidationResult> validateRoleAssignment(
    String adminUserId,
    String targetUserId,
    UserRole newRole,
  ) async {
    try {
      // Check admin permissions
      final adminRole = await getUserRole(adminUserId);
      if (!adminRole.canModifyUserRoles) {
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
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('users/$targetUserId').once();
      if (!snapshot.snapshot.exists) {
        return RoleValidationResult.error('Target user not found');
      }

      return RoleValidationResult.success('Role assignment is valid');
    } catch (e) {
      AppLogger.error('Error validating role assignment', error: e, category: LogCategory.auth);
      return RoleValidationResult.error('An error occurred while validating the role assignment');
    }
  }

  /// Audit log for permission checks
  static void logPermissionCheck(
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


  /// Clear role cache (useful for testing or when user logs out)
  static void clearCache() {
    _roleCache.clear();
  }

  /// Ensure super admin role exists for the current user
  static Future<void> ensureSuperAdminRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.warning('No authenticated user found for super admin role setup');
        return;
      }

      // Check if user is already super admin
      final currentRole = await getUserRole(user.uid);
      if (currentRole == UserRole.superAdmin) {
        AppLogger.debug('User ${user.uid} already has super admin role');
        return;
      }

      // Update user role to super admin
      final database = FirebaseDatabase.instance;
      await database.ref('users/${user.uid}').update({
        'role': UserRole.superAdmin.value,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': 'system',
      });

      // Clear cache to force refresh
      _roleCache.remove(user.uid);

      AppLogger.info(
        'Super admin role ensured for user ${user.uid}',
        category: LogCategory.auth,
      );
    } catch (e) {
      AppLogger.error('Error ensuring super admin role', error: e, category: LogCategory.auth);
    }
  }

  /// Clear cache for specific user
  static void clearUserCache(String userId) {
    _roleCache.remove(userId);
  }

  /// Get cached role if available (synchronous)
  static UserRole? getCachedRole(String userId) {
    return _roleCache[userId];
  }

  /// Pre-load and cache user role
  static Future<void> preloadUserRole(String userId) async {
    await getUserRole(userId);
  }

  /// Get role statistics for admin dashboard
  static Future<Map<String, int>> getRoleStatistics() async {
    try {
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('users').once();

      final Map<String, int> stats = {
        'Super Admin': 0,
        'Admin': 0,
        'Sales': 0,
        'Distributor': 0,
      };

      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final usersData = SafeTypeConverter.toMap(snapshot.snapshot.value);

        for (final userData in usersData.values) {
          if (userData is Map) {
            final userMap = SafeTypeConverter.toMap(userData);
            final roleString = userMap['role'] as String? ?? 'distributor';
            final role = UserRole.fromString(roleString);

            switch (role) {
              case UserRole.superAdmin:
                stats['Super Admin'] = (stats['Super Admin'] ?? 0) + 1;
                break;
              case UserRole.admin:
                stats['Admin'] = (stats['Admin'] ?? 0) + 1;
                break;
              case UserRole.sales:
                stats['Sales'] = (stats['Sales'] ?? 0) + 1;
                break;
              case UserRole.distributor:
                stats['Distributor'] = (stats['Distributor'] ?? 0) + 1;
                break;
            }
          }
        }
      }

      return stats;
    } catch (e) {
      AppLogger.error('Error getting role statistics', error: e, category: LogCategory.auth);
      return {
        'Super Admin': 0,
        'Admin': 0,
        'Sales': 0,
        'Distributor': 0,
      };
    }
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