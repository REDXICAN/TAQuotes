// lib/core/models/user_role.dart

/// User roles in hierarchical order (lowest to highest privileges)
enum UserRole {
  /// Distributor role - lowest privileges
  distributor('distributor', 'Distributor', 0),

  /// Sales role - moderate privileges
  sales('sales', 'Sales', 1),

  /// Admin role - high privileges
  admin('admin', 'Admin', 2),

  /// Super Admin role - highest privileges
  superAdmin('superadmin', 'Super Admin', 3);

  const UserRole(this.value, this.displayName, this.level);

  /// The string value stored in the database
  final String value;

  /// User-friendly display name
  final String displayName;

  /// Hierarchy level (higher number = more privileges)
  final int level;

  /// Create UserRole from string value
  static UserRole fromString(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'superadmin':
      case 'super_admin':
      case 'super-admin':
        return UserRole.superAdmin;
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'sales':
      case 'sales_rep':
      case 'sales_representative':
        return UserRole.sales;
      case 'distributor':
      case 'distribution':
      default:
        return UserRole.distributor; // Default role
    }
  }

  /// Check if this role has equal or higher privileges than another role
  bool hasPrivilegeLevel(UserRole requiredRole) {
    return level >= requiredRole.level;
  }

  /// Get all roles at or below this privilege level
  List<UserRole> get subordinateRoles {
    return UserRole.values.where((role) => role.level <= level).toList();
  }

  /// Get all roles above this privilege level
  List<UserRole> get superiorRoles {
    return UserRole.values.where((role) => role.level > level).toList();
  }

  @override
  String toString() => value;

  // Permission helpers
  bool get canManageUsers => this == UserRole.superAdmin || this == UserRole.admin;
  bool get canManageProducts => this == UserRole.superAdmin || this == UserRole.admin;
  bool get canCreateQuotes => true; // All roles can create quotes
  bool get canViewAllQuotes => this == UserRole.superAdmin || this == UserRole.admin;
  bool get canEditPricing => this == UserRole.superAdmin || this == UserRole.admin || this == UserRole.sales;
  bool get canAccessAdmin => this == UserRole.superAdmin || this == UserRole.admin;

  // SuperAdmin-only permissions
  bool get canAccessPerformanceDashboard => this == UserRole.superAdmin;
  bool get canAccessUserInfoDashboard => this == UserRole.superAdmin;
  bool get canAccessStockDashboard => this == UserRole.superAdmin || this == UserRole.admin;
  bool get canManageBackups => this == UserRole.superAdmin;
  bool get canExportData => this == UserRole.superAdmin || this == UserRole.admin;
  bool get canImportProducts => this == UserRole.superAdmin || this == UserRole.admin;
  bool get canModifyUserRoles => this == UserRole.superAdmin;
  bool get canViewErrorMonitoring => this == UserRole.superAdmin;
  bool get canPopulateDemoData => this == UserRole.superAdmin;

  // Admin+ permissions
  bool get isAdminOrAbove => level >= UserRole.admin.level;
  bool get isSuperAdmin => this == UserRole.superAdmin;

  // Role check helpers (for compatibility with auth module)
  bool get isAdmin => level >= UserRole.admin.level;
  bool get isSales => level >= UserRole.sales.level;
  bool get isDistributor => this == UserRole.distributor;
}

/// Role hierarchy helper methods
class RoleHierarchy {
  /// Check if role1 has higher or equal privileges than role2
  static bool hasPermission(UserRole userRole, UserRole requiredRole) {
    return userRole.hasPrivilegeLevel(requiredRole);
  }

  /// Get the highest role from a list of roles
  static UserRole getHighestRole(List<UserRole> roles) {
    if (roles.isEmpty) return UserRole.distributor;
    return roles.reduce((a, b) => a.level > b.level ? a : b);
  }

  /// Get the lowest role from a list of roles
  static UserRole getLowestRole(List<UserRole> roles) {
    if (roles.isEmpty) return UserRole.distributor;
    return roles.reduce((a, b) => a.level < b.level ? a : b);
  }

  /// Check if a user can manage another user (higher role can manage lower roles)
  static bool canManageUser(UserRole managerRole, UserRole targetRole) {
    // Super admins can manage everyone
    if (managerRole.isSuperAdmin) return true;

    // Admins can manage sales and distributors, but not other admins
    if (managerRole.isAdminOrAbove && !targetRole.isAdminOrAbove) return true;

    // Sales cannot manage anyone
    return false;
  }

  /// Get roles that this user can assign to others
  static List<UserRole> getAssignableRoles(UserRole userRole) {
    switch (userRole) {
      case UserRole.superAdmin:
        return [UserRole.admin, UserRole.sales, UserRole.distributor];
      case UserRole.admin:
        return [UserRole.sales, UserRole.distributor];
      case UserRole.sales:
      case UserRole.distributor:
        return []; // Cannot assign roles
    }
  }
}