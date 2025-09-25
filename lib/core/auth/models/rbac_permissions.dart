// lib/core/auth/models/rbac_permissions.dart

import '../../models/user_role.dart';

/// Defines all available permissions in the TAQuotes system
enum Permission {
  // Product Management
  viewProducts('view_products', 'View Products'),
  createProducts('create_products', 'Create Products'),
  editProducts('edit_products', 'Edit Products'),
  deleteProducts('delete_products', 'Delete Products'),
  importProducts('import_products', 'Import Products'),
  exportProducts('export_products', 'Export Products'),

  // Client Management
  viewOwnClients('view_own_clients', 'View Own Clients'),
  viewAllClients('view_all_clients', 'View All Clients'),
  createClients('create_clients', 'Create Clients'),
  editOwnClients('edit_own_clients', 'Edit Own Clients'),
  editAllClients('edit_all_clients', 'Edit All Clients'),
  deleteOwnClients('delete_own_clients', 'Delete Own Clients'),
  deleteAllClients('delete_all_clients', 'Delete All Clients'),
  exportClients('export_clients', 'Export Clients'),

  // Quote Management
  viewOwnQuotes('view_own_quotes', 'View Own Quotes'),
  viewAllQuotes('view_all_quotes', 'View All Quotes'),
  createQuotes('create_quotes', 'Create Quotes'),
  editOwnQuotes('edit_own_quotes', 'Edit Own Quotes'),
  editAllQuotes('edit_all_quotes', 'Edit All Quotes'),
  deleteOwnQuotes('delete_own_quotes', 'Delete Own Quotes'),
  deleteAllQuotes('delete_all_quotes', 'Delete All Quotes'),
  duplicateQuotes('duplicate_quotes', 'Duplicate Quotes'),
  exportQuotes('export_quotes', 'Export Quotes'),
  emailQuotes('email_quotes', 'Email Quotes'),

  // Project Management
  viewOwnProjects('view_own_projects', 'View Own Projects'),
  viewAllProjects('view_all_projects', 'View All Projects'),
  createProjects('create_projects', 'Create Projects'),
  editOwnProjects('edit_own_projects', 'Edit Own Projects'),
  editAllProjects('edit_all_projects', 'Edit All Projects'),
  deleteOwnProjects('delete_own_projects', 'Delete Own Projects'),
  deleteAllProjects('delete_all_projects', 'Delete All Projects'),

  // User Management
  viewUsers('view_users', 'View Users'),
  createUsers('create_users', 'Create Users'),
  editUsers('edit_users', 'Edit Users'),
  deleteUsers('delete_users', 'Delete Users'),
  assignRoles('assign_roles', 'Assign Roles'),
  viewUserApprovals('view_user_approvals', 'View User Approvals'),
  approveUsers('approve_users', 'Approve Users'),

  // System Administration
  accessAdminPanel('access_admin_panel', 'Access Admin Panel'),
  viewSystemMetrics('view_system_metrics', 'View System Metrics'),
  viewPerformanceDashboard('view_performance_dashboard', 'View Performance Dashboard'),
  viewStockDashboard('view_stock_dashboard', 'View Stock Dashboard'),
  manageDatabase('manage_database', 'Manage Database'),
  viewSystemLogs('view_system_logs', 'View System Logs'),
  backupSystem('backup_system', 'Backup System'),
  restoreSystem('restore_system', 'Restore System'),
  populateDemoData('populate_demo_data', 'Populate Demo Data'),

  // Warehouse Management
  viewWarehouseStock('view_warehouse_stock', 'View Warehouse Stock'),
  editWarehouseStock('edit_warehouse_stock', 'Edit Warehouse Stock'),
  manageWarehouses('manage_warehouses', 'Manage Warehouses'),

  // Pricing and Finance
  viewPricing('view_pricing', 'View Pricing'),
  editPricing('edit_pricing', 'Edit Pricing'),
  viewReports('view_reports', 'View Reports'),
  generateReports('generate_reports', 'Generate Reports'),

  // Cart and Shopping
  useShoppingCart('use_shopping_cart', 'Use Shopping Cart'),
  viewCart('view_cart', 'View Cart'),
  modifyCart('modify_cart', 'Modify Cart'),

  // Email and Communication
  sendEmails('send_emails', 'Send Emails'),
  accessEmailTemplates('access_email_templates', 'Access Email Templates'),

  // Offline Features
  useOfflineMode('use_offline_mode', 'Use Offline Mode'),
  syncData('sync_data', 'Sync Data');

  const Permission(this.value, this.displayName);

  final String value;
  final String displayName;
}

/// Role-based permission mapping
class RolePermissions {
  /// Get all permissions for a given role
  static Set<Permission> getPermissionsForRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return _superAdminPermissions;
      case UserRole.admin:
        return _adminPermissions;
      case UserRole.sales:
        return _salesPermissions;
      case UserRole.distributor:
        return _distributorPermissions;
    }
  }

  /// Super Admin permissions - full access to everything
  static final Set<Permission> _superAdminPermissions = {
    // All product permissions
    Permission.viewProducts,
    Permission.createProducts,
    Permission.editProducts,
    Permission.deleteProducts,
    Permission.importProducts,
    Permission.exportProducts,

    // All client permissions
    Permission.viewOwnClients,
    Permission.viewAllClients,
    Permission.createClients,
    Permission.editOwnClients,
    Permission.editAllClients,
    Permission.deleteOwnClients,
    Permission.deleteAllClients,
    Permission.exportClients,

    // All quote permissions
    Permission.viewOwnQuotes,
    Permission.viewAllQuotes,
    Permission.createQuotes,
    Permission.editOwnQuotes,
    Permission.editAllQuotes,
    Permission.deleteOwnQuotes,
    Permission.deleteAllQuotes,
    Permission.duplicateQuotes,
    Permission.exportQuotes,
    Permission.emailQuotes,

    // All project permissions
    Permission.viewOwnProjects,
    Permission.viewAllProjects,
    Permission.createProjects,
    Permission.editOwnProjects,
    Permission.editAllProjects,
    Permission.deleteOwnProjects,
    Permission.deleteAllProjects,

    // All user management
    Permission.viewUsers,
    Permission.createUsers,
    Permission.editUsers,
    Permission.deleteUsers,
    Permission.assignRoles,
    Permission.viewUserApprovals,
    Permission.approveUsers,

    // All system administration
    Permission.accessAdminPanel,
    Permission.viewSystemMetrics,
    Permission.viewPerformanceDashboard,
    Permission.viewStockDashboard,
    Permission.manageDatabase,
    Permission.viewSystemLogs,
    Permission.backupSystem,
    Permission.restoreSystem,
    Permission.populateDemoData,

    // All warehouse management
    Permission.viewWarehouseStock,
    Permission.editWarehouseStock,
    Permission.manageWarehouses,

    // All pricing and finance
    Permission.viewPricing,
    Permission.editPricing,
    Permission.viewReports,
    Permission.generateReports,

    // Cart and shopping
    Permission.useShoppingCart,
    Permission.viewCart,
    Permission.modifyCart,

    // Email and communication
    Permission.sendEmails,
    Permission.accessEmailTemplates,

    // Offline features
    Permission.useOfflineMode,
    Permission.syncData,
  };

  /// Admin permissions - most features except user role management
  static final Set<Permission> _adminPermissions = {
    // Product permissions (no import/delete)
    Permission.viewProducts,
    Permission.exportProducts,

    // Client permissions (all own + view all)
    Permission.viewOwnClients,
    Permission.viewAllClients,
    Permission.createClients,
    Permission.editOwnClients,
    Permission.editAllClients,
    Permission.deleteOwnClients,
    Permission.exportClients,

    // Quote permissions (all own + view all)
    Permission.viewOwnQuotes,
    Permission.viewAllQuotes,
    Permission.createQuotes,
    Permission.editOwnQuotes,
    Permission.editAllQuotes,
    Permission.deleteOwnQuotes,
    Permission.duplicateQuotes,
    Permission.exportQuotes,
    Permission.emailQuotes,

    // Project permissions (all own + view all)
    Permission.viewOwnProjects,
    Permission.viewAllProjects,
    Permission.createProjects,
    Permission.editOwnProjects,
    Permission.editAllProjects,
    Permission.deleteOwnProjects,

    // Limited user management
    Permission.viewUsers,

    // Limited system administration
    Permission.viewSystemMetrics,
    Permission.viewPerformanceDashboard,
    Permission.viewStockDashboard,
    Permission.viewSystemLogs,

    // Warehouse viewing
    Permission.viewWarehouseStock,

    // Pricing and finance
    Permission.viewPricing,
    Permission.viewReports,
    Permission.generateReports,

    // Cart and shopping
    Permission.useShoppingCart,
    Permission.viewCart,
    Permission.modifyCart,

    // Email and communication
    Permission.sendEmails,
    Permission.accessEmailTemplates,

    // Offline features
    Permission.useOfflineMode,
    Permission.syncData,
  };

  /// Sales permissions - client and quote management for own records
  static final Set<Permission> _salesPermissions = {
    // Product permissions (view only)
    Permission.viewProducts,

    // Client permissions (own only)
    Permission.viewOwnClients,
    Permission.createClients,
    Permission.editOwnClients,
    Permission.deleteOwnClients,
    Permission.exportClients,

    // Quote permissions (own only)
    Permission.viewOwnQuotes,
    Permission.createQuotes,
    Permission.editOwnQuotes,
    Permission.deleteOwnQuotes,
    Permission.duplicateQuotes,
    Permission.exportQuotes,
    Permission.emailQuotes,

    // Project permissions (own only)
    Permission.viewOwnProjects,
    Permission.createProjects,
    Permission.editOwnProjects,
    Permission.deleteOwnProjects,

    // Warehouse viewing
    Permission.viewWarehouseStock,

    // Pricing (view only)
    Permission.viewPricing,

    // Cart and shopping
    Permission.useShoppingCart,
    Permission.viewCart,
    Permission.modifyCart,

    // Email and communication
    Permission.sendEmails,

    // Offline features
    Permission.useOfflineMode,
    Permission.syncData,
  };

  /// Distributor permissions - basic product browsing and quote creation
  static final Set<Permission> _distributorPermissions = {
    // Product permissions (view only)
    Permission.viewProducts,

    // Client permissions (own only, limited)
    Permission.viewOwnClients,
    Permission.createClients,
    Permission.editOwnClients,

    // Quote permissions (own only, basic)
    Permission.viewOwnQuotes,
    Permission.createQuotes,
    Permission.editOwnQuotes,
    Permission.duplicateQuotes,
    Permission.emailQuotes,

    // Project permissions (own only, basic)
    Permission.viewOwnProjects,
    Permission.createProjects,
    Permission.editOwnProjects,

    // Warehouse viewing
    Permission.viewWarehouseStock,

    // Pricing (view only)
    Permission.viewPricing,

    // Cart and shopping
    Permission.useShoppingCart,
    Permission.viewCart,
    Permission.modifyCart,

    // Email (basic)
    Permission.sendEmails,

    // Offline features
    Permission.useOfflineMode,
    Permission.syncData,
  };

  /// Check if a role has a specific permission
  static bool hasPermission(UserRole role, Permission permission) {
    return getPermissionsForRole(role).contains(permission);
  }

  /// Get permission categories for UI organization
  static Map<String, List<Permission>> getPermissionCategories() {
    return {
      'Product Management': [
        Permission.viewProducts,
        Permission.createProducts,
        Permission.editProducts,
        Permission.deleteProducts,
        Permission.importProducts,
        Permission.exportProducts,
      ],
      'Client Management': [
        Permission.viewOwnClients,
        Permission.viewAllClients,
        Permission.createClients,
        Permission.editOwnClients,
        Permission.editAllClients,
        Permission.deleteOwnClients,
        Permission.deleteAllClients,
        Permission.exportClients,
      ],
      'Quote Management': [
        Permission.viewOwnQuotes,
        Permission.viewAllQuotes,
        Permission.createQuotes,
        Permission.editOwnQuotes,
        Permission.editAllQuotes,
        Permission.deleteOwnQuotes,
        Permission.deleteAllQuotes,
        Permission.duplicateQuotes,
        Permission.exportQuotes,
        Permission.emailQuotes,
      ],
      'User Management': [
        Permission.viewUsers,
        Permission.createUsers,
        Permission.editUsers,
        Permission.deleteUsers,
        Permission.assignRoles,
        Permission.viewUserApprovals,
        Permission.approveUsers,
      ],
      'System Administration': [
        Permission.accessAdminPanel,
        Permission.viewSystemMetrics,
        Permission.viewPerformanceDashboard,
        Permission.viewStockDashboard,
        Permission.manageDatabase,
        Permission.viewSystemLogs,
        Permission.backupSystem,
        Permission.restoreSystem,
        Permission.populateDemoData,
      ],
      'Warehouse Management': [
        Permission.viewWarehouseStock,
        Permission.editWarehouseStock,
        Permission.manageWarehouses,
      ],
    };
  }
}