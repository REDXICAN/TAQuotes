// lib/core/auth/providers/rbac_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_role.dart';
import '../../config/env_config.dart';
import '../models/rbac_permissions.dart';
import '../services/rbac_service.dart';
import '../../../core/models/models.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';

/// Provider for the RBAC service
final rbacServiceProvider = Provider<RbacService>((ref) {
  return RbacService();
});

/// Provider for current user's role
final currentUserRoleProvider = FutureProvider<UserRole>((ref) async {
  final userProfile = await ref.watch(currentUserProfileProvider.future);

  if (userProfile == null) {
    return UserRole.distributor; // Default role for unauthenticated users
  }

  return UserRole.fromString(userProfile.role);
});

/// Provider for current user's permissions
final currentUserPermissionsProvider = FutureProvider<Set<Permission>>((ref) async {
  final userRole = await ref.watch(currentUserRoleProvider.future);
  return RolePermissions.getPermissionsForRole(userRole);
});

/// Provider for checking if current user has a specific permission
final hasPermissionProvider = FutureProvider.family<bool, Permission>((ref, permission) async {
  final permissions = await ref.watch(currentUserPermissionsProvider.future);
  return permissions.contains(permission);
});

/// Provider for checking if current user has a specific role or higher
final hasRoleProvider = FutureProvider.family<bool, UserRole>((ref, requiredRole) async {
  final userRole = await ref.watch(currentUserRoleProvider.future);
  return userRole.hasPrivilegeLevel(requiredRole);
});

/// Provider for checking if current user is Super Admin
final isSuperAdminProvider = FutureProvider<bool>((ref) async {
  final userRole = await ref.watch(currentUserRoleProvider.future);
  return userRole.isSuperAdmin;
});

/// Provider for checking if current user is Admin or higher
final isAdminProvider = FutureProvider<bool>((ref) async {
  final userRole = await ref.watch(currentUserRoleProvider.future);
  return userRole.isAdmin;
});

/// Provider for checking if current user is Sales or higher
final isSalesProvider = FutureProvider<bool>((ref) async {
  final userRole = await ref.watch(currentUserRoleProvider.future);
  return userRole.isSales;
});

/// Provider for RBAC helper methods
final rbacHelperProvider = Provider<RbacHelper>((ref) {
  return RbacHelper(ref);
});

/// RBAC Helper class for complex permission checking
class RbacHelper {
  final Ref _ref;

  RbacHelper(this._ref);

  /// Check if current user can access admin panel
  Future<bool> canAccessAdminPanel() async {
    return await _ref.read(hasPermissionProvider(Permission.accessAdminPanel).future);
  }

  /// Check if current user can manage users
  Future<bool> canManageUsers() async {
    final viewUsers = await _ref.read(hasPermissionProvider(Permission.viewUsers).future);
    final editUsers = await _ref.read(hasPermissionProvider(Permission.editUsers).future);
    return viewUsers || editUsers;
  }

  /// Check if current user can manage all clients (not just own)
  Future<bool> canManageAllClients() async {
    return await _ref.read(hasPermissionProvider(Permission.viewAllClients).future);
  }

  /// Check if current user can manage all quotes (not just own)
  Future<bool> canManageAllQuotes() async {
    return await _ref.read(hasPermissionProvider(Permission.viewAllQuotes).future);
  }

  /// Check if current user can manage products
  Future<bool> canManageProducts() async {
    final canEdit = await _ref.read(hasPermissionProvider(Permission.editProducts).future);
    final canImport = await _ref.read(hasPermissionProvider(Permission.importProducts).future);
    return canEdit || canImport;
  }

  /// Check if current user can manage system settings
  Future<bool> canManageSystem() async {
    final canBackup = await _ref.read(hasPermissionProvider(Permission.backupSystem).future);
    final canManageDB = await _ref.read(hasPermissionProvider(Permission.manageDatabase).future);
    return canBackup || canManageDB;
  }

  /// Check if current user can view system dashboards
  Future<bool> canViewDashboards() async {
    final canViewPerformance = await _ref.read(hasPermissionProvider(Permission.viewPerformanceDashboard).future);
    final canViewStock = await _ref.read(hasPermissionProvider(Permission.viewStockDashboard).future);
    return canViewPerformance || canViewStock;
  }

  /// Check if current user can assign roles to other users
  Future<bool> canAssignRoles() async {
    return await _ref.read(hasPermissionProvider(Permission.assignRoles).future);
  }

  /// Check if current user can approve user registrations
  Future<bool> canApproveUsers() async {
    return await _ref.read(hasPermissionProvider(Permission.approveUsers).future);
  }

  /// Get user's role as string for legacy compatibility
  Future<String> getUserRoleString() async {
    final userRole = await _ref.read(currentUserRoleProvider.future);
    return userRole.value;
  }

  /// Check if user can manage another user based on roles
  Future<bool> canManageUser(String targetUserEmail) async {
    final currentUserRole = await _ref.read(currentUserRoleProvider.future);

    // Get target user's role (this would need to be implemented based on your data structure)
    // For now, we'll assume this method exists in your database service
    final dbService = _ref.read(databaseServiceProvider);

    try {
      // This is a placeholder - you'd need to implement getUserByEmail in your database service
      final targetUserData = await dbService.getUserProfile(targetUserEmail);
      if (targetUserData == null) return false;

      final targetUserRole = UserRole.fromString(targetUserData['role'] ?? 'distributor');

      return RoleHierarchy.canManageUser(currentUserRole, targetUserRole);
    } catch (e) {
      return false;
    }
  }

  /// Get roles that current user can assign to others
  Future<List<UserRole>> getAssignableRoles() async {
    final userRole = await _ref.read(currentUserRoleProvider.future);
    return RoleHierarchy.getAssignableRoles(userRole);
  }
}

/// Provider for checking legacy email-based admin access (for backward compatibility)
/// This should be gradually replaced with proper RBAC checks
final isLegacyAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.email == null) return false;

  // Check both new RBAC system and legacy email check
  final isAdminByRole = await ref.read(isAdminProvider.future);
  final isLegacyAdmin = EnvConfig.isSuperAdminEmail(user!.email!);

  return isAdminByRole || isLegacyAdmin;
});

/// Provider for migration helper - combines RBAC with legacy checks
final migrationPermissionProvider = FutureProvider.family<bool, Permission>((ref, permission) async {
  final user = ref.watch(currentUserProvider);
  if (user?.email == null) return false;

  // Check new RBAC system first
  final hasRbacPermission = await ref.read(hasPermissionProvider(permission).future);

  // For admin-level permissions, also check legacy email
  if (permission == Permission.accessAdminPanel ||
      permission == Permission.manageDatabase ||
      permission == Permission.importProducts) {
    final isLegacyAdmin = EnvConfig.isSuperAdminEmail(user!.email!);
    return hasRbacPermission || isLegacyAdmin;
  }

  return hasRbacPermission;
});

/// Exception thrown when user doesn't have required permissions
class InsufficientPermissionsException implements Exception {
  final String message;
  final Permission? requiredPermission;
  final UserRole? requiredRole;

  InsufficientPermissionsException(
    this.message, {
    this.requiredPermission,
    this.requiredRole,
  });

  @override
  String toString() => 'InsufficientPermissionsException: $message';
}

/// Utility methods for permission checking in UI
class PermissionUtils {
  /// Check permission and throw exception if not allowed
  static Future<void> requirePermission(
    Ref ref,
    Permission permission, {
    String? customMessage,
  }) async {
    final hasPermission = await ref.read(hasPermissionProvider(permission).future);
    if (!hasPermission) {
      throw InsufficientPermissionsException(
        customMessage ?? 'You do not have permission to perform this action',
        requiredPermission: permission,
      );
    }
  }

  /// Check role and throw exception if not allowed
  static Future<void> requireRole(
    Ref ref,
    UserRole role, {
    String? customMessage,
  }) async {
    final hasRole = await ref.read(hasRoleProvider(role).future);
    if (!hasRole) {
      throw InsufficientPermissionsException(
        customMessage ?? 'You do not have the required role to perform this action',
        requiredRole: role,
      );
    }
  }
}