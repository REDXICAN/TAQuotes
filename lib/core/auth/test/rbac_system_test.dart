// lib/core/auth/test/rbac_system_test.dart

/// This file contains test examples and validation for the RBAC system
/// Remove or move to test/ folder in production

import '../../models/user_role.dart';
import '../models/rbac_permissions.dart';

class RbacSystemTest {
  static void runTests() {
    print('=== RBAC System Test ===');

    testRoleHierarchy();
    testPermissions();
    testRoleManagement();

    print('=== All Tests Complete ===');
  }

  static void testRoleHierarchy() {
    print('\n--- Testing Role Hierarchy ---');

    // Test role levels
    assert(UserRole.distributor.level == 0);
    assert(UserRole.sales.level == 1);
    assert(UserRole.admin.level == 2);
    assert(UserRole.superAdmin.level == 3);
    print('✓ Role levels correct');

    // Test privilege checking
    assert(UserRole.superAdmin.hasPrivilegeLevel(UserRole.admin));
    assert(UserRole.admin.hasPrivilegeLevel(UserRole.sales));
    assert(UserRole.sales.hasPrivilegeLevel(UserRole.distributor));
    assert(!UserRole.distributor.hasPrivilegeLevel(UserRole.sales));
    print('✓ Privilege levels work correctly');

    // Test role parsing
    assert(UserRole.fromString('superadmin') == UserRole.superAdmin);
    assert(UserRole.fromString('ADMIN') == UserRole.admin);
    assert(UserRole.fromString('sales_rep') == UserRole.sales);
    assert(UserRole.fromString('unknown') == UserRole.distributor);
    print('✓ Role parsing works correctly');

    // Test helper methods
    assert(UserRole.superAdmin.isSuperAdmin);
    assert(UserRole.admin.isAdminOrAbove);
    assert(UserRole.superAdmin.isAdminOrAbove);
    assert(!UserRole.sales.isAdminOrAbove);
    print('✓ Helper methods work correctly');
  }

  static void testPermissions() {
    print('\n--- Testing Permissions ---');

    // Test SuperAdmin permissions
    final superAdminPerms = RolePermissions.getPermissionsForRole(UserRole.superAdmin);
    assert(superAdminPerms.contains(Permission.manageDatabase));
    assert(superAdminPerms.contains(Permission.assignRoles));
    assert(superAdminPerms.contains(Permission.viewAllClients));
    print('✓ SuperAdmin has all permissions');

    // Test Admin permissions
    final adminPerms = RolePermissions.getPermissionsForRole(UserRole.admin);
    assert(adminPerms.contains(Permission.viewAllClients));
    assert(adminPerms.contains(Permission.editAllClients));
    assert(!adminPerms.contains(Permission.assignRoles)); // SuperAdmin only
    assert(!adminPerms.contains(Permission.manageDatabase)); // SuperAdmin only
    print('✓ Admin has correct permissions');

    // Test Sales permissions
    final salesPerms = RolePermissions.getPermissionsForRole(UserRole.sales);
    assert(salesPerms.contains(Permission.viewOwnClients));
    assert(salesPerms.contains(Permission.createQuotes));
    assert(!salesPerms.contains(Permission.viewAllClients)); // Admin+ only
    assert(!salesPerms.contains(Permission.deleteAllClients)); // Admin+ only
    print('✓ Sales has correct permissions');

    // Test Distributor permissions
    final distributorPerms = RolePermissions.getPermissionsForRole(UserRole.distributor);
    assert(distributorPerms.contains(Permission.viewProducts));
    assert(distributorPerms.contains(Permission.createQuotes));
    assert(!distributorPerms.contains(Permission.deleteOwnClients)); // Sales+ only
    assert(!distributorPerms.contains(Permission.exportClients)); // Sales+ only
    print('✓ Distributor has correct permissions');

    // Test permission checking
    assert(RolePermissions.hasPermission(UserRole.superAdmin, Permission.assignRoles));
    assert(!RolePermissions.hasPermission(UserRole.sales, Permission.assignRoles));
    print('✓ Permission checking works correctly');
  }

  static void testRoleManagement() {
    print('\n--- Testing Role Management ---');

    // Test user management hierarchy
    assert(RoleHierarchy.canManageUser(UserRole.superAdmin, UserRole.admin));
    assert(RoleHierarchy.canManageUser(UserRole.admin, UserRole.sales));
    assert(!RoleHierarchy.canManageUser(UserRole.sales, UserRole.admin));
    assert(!RoleHierarchy.canManageUser(UserRole.distributor, UserRole.sales));
    print('✓ User management hierarchy works correctly');

    // Test assignable roles
    final superAdminAssignable = RoleHierarchy.getAssignableRoles(UserRole.superAdmin);
    assert(superAdminAssignable.contains(UserRole.admin));
    assert(superAdminAssignable.contains(UserRole.sales));
    assert(superAdminAssignable.contains(UserRole.distributor));
    assert(!superAdminAssignable.contains(UserRole.superAdmin));
    print('✓ SuperAdmin can assign admin, sales, and distributor roles');

    final adminAssignable = RoleHierarchy.getAssignableRoles(UserRole.admin);
    assert(!adminAssignable.contains(UserRole.admin));
    assert(adminAssignable.contains(UserRole.sales));
    assert(adminAssignable.contains(UserRole.distributor));
    print('✓ Admin can assign sales and distributor roles');

    final salesAssignable = RoleHierarchy.getAssignableRoles(UserRole.sales);
    assert(salesAssignable.isEmpty);
    print('✓ Sales cannot assign any roles');

    // Test role comparison
    final roles = [UserRole.distributor, UserRole.superAdmin, UserRole.sales, UserRole.admin];
    final highestRole = RoleHierarchy.getHighestRole(roles);
    final lowestRole = RoleHierarchy.getLowestRole(roles);
    assert(highestRole == UserRole.superAdmin);
    assert(lowestRole == UserRole.distributor);
    print('✓ Role comparison methods work correctly');
  }

  static void printRolePermissionMatrix() {
    print('\n=== Role Permission Matrix ===');

    final roles = [UserRole.distributor, UserRole.sales, UserRole.admin, UserRole.superAdmin];
    final testPermissions = [
      Permission.viewProducts,
      Permission.createClients,
      Permission.viewAllClients,
      Permission.editAllQuotes,
      Permission.accessAdminPanel,
      Permission.assignRoles,
      Permission.manageDatabase,
    ];

    // Print header
    print('Permission'.padRight(25) + 'Dist  Sales Admin Super');
    print('-' * 55);

    for (final permission in testPermissions) {
      String line = permission.displayName.padRight(25);

      for (final role in roles) {
        final hasPermission = RolePermissions.hasPermission(role, permission);
        line += (hasPermission ? 'Yes' : 'No').padRight(6);
      }

      print(line);
    }

    print('-' * 55);
    print('Legend: Dist = Distributor, Super = SuperAdmin');
  }

  static void printRoleHierarchy() {
    print('\n=== Role Hierarchy ===');

    final roles = [UserRole.superAdmin, UserRole.admin, UserRole.sales, UserRole.distributor];

    for (final role in roles) {
      print('${role.displayName} (Level ${role.level}):');
      print('  Can manage: ${RoleHierarchy.getAssignableRoles(role).map((r) => r.displayName).join(', ')}');
      print('  Permission count: ${RolePermissions.getPermissionsForRole(role).length}');
      print('');
    }
  }
}

/// Example usage and validation
void main() {
  // Run tests
  RbacSystemTest.runTests();

  // Print matrices for documentation
  RbacSystemTest.printRolePermissionMatrix();
  RbacSystemTest.printRoleHierarchy();

  // Example usage in app
  demonstrateUsage();
}

void demonstrateUsage() {
  print('\n=== Usage Examples ===');

  // Example 1: Check if user can access admin panel
  final userRole = UserRole.admin;
  final canAccessAdmin = RolePermissions.hasPermission(userRole, Permission.accessAdminPanel);
  print('Admin can access admin panel: $canAccessAdmin');

  // Example 2: Check role hierarchy
  final canManageSales = RoleHierarchy.canManageUser(UserRole.admin, UserRole.sales);
  print('Admin can manage sales users: $canManageSales');

  // Example 3: Get assignable roles
  final assignableRoles = RoleHierarchy.getAssignableRoles(UserRole.admin);
  print('Admin can assign roles: ${assignableRoles.map((r) => r.displayName).join(', ')}');

  // Example 4: Permission categories
  final categories = RolePermissions.getPermissionCategories();
  print('Permission categories: ${categories.keys.join(', ')}');
}