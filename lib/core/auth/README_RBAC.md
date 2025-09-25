# Role-Based Access Control (RBAC) System

## Overview

The TAQuotes RBAC system provides comprehensive role-based access control with a hierarchical permission structure. It replaces email-based admin checks with a proper role and permission system.

## Architecture

### Components

1. **UserRole Enum** (`lib/core/models/user_role.dart`)
   - Defines 4 hierarchical roles: Distributor (0), Sales (1), Admin (2), SuperAdmin (3)
   - Includes level-based privilege checking

2. **Permission Enum** (`lib/core/auth/models/rbac_permissions.dart`)
   - Defines granular permissions for all system operations
   - Organized by feature categories (Products, Clients, Quotes, etc.)

3. **RolePermissions Class**
   - Maps roles to their allowed permissions
   - Provides permission checking methods

4. **RBAC Service** (`lib/core/services/rbac_service.dart`)
   - Enhanced existing service with comprehensive permission checking
   - Includes validation and audit logging

5. **RBAC Providers** (`lib/core/auth/providers/rbac_provider.dart`)
   - Riverpod providers for reactive permission checking
   - Integration with Firebase Auth

## Role Hierarchy

```
SuperAdmin (Level 3)    - Full system access
    ↓
Admin (Level 2)         - User & data management
    ↓
Sales (Level 1)         - Own clients & quotes
    ↓
Distributor (Level 0)   - Basic product access
```

## Usage Examples

### 1. Basic Permission Checking

```dart
// Using the enhanced RBAC service
final canEditProducts = await RBACService.hasPermissionEnum(Permission.editProducts);

// Using Riverpod providers
final hasPermission = await ref.read(hasPermissionProvider(Permission.createClients).future);
```

### 2. Role-Based UI Components

```dart
Consumer(
  builder: (context, ref, child) {
    final canAccessAdmin = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return canAccessAdmin.when(
      data: (hasAccess) => hasAccess
        ? AdminButton()
        : SizedBox.shrink(),
      loading: () => CircularProgressIndicator(),
      error: (_, __) => SizedBox.shrink(),
    );
  },
)
```

### 3. Screen Access Control

```dart
class AdminPanelScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAccess.when(
      data: (canAccess) {
        if (!canAccess) {
          return UnauthorizedScreen();
        }
        return AdminPanelContent();
      },
      loading: () => LoadingScreen(),
      error: (error, stack) => ErrorScreen(error: error),
    );
  }
}
```

### 4. Role Management

```dart
// Check if user can manage another user
final canManage = await RBACService.canManageUser(adminUserId, targetUserId);

// Get roles that current user can assign
final assignableRoles = await RBACService.getAssignableRoles();

// Update user role with validation
final success = await RBACService.updateUserRole(targetUserId, UserRole.sales);
```

## Permission Categories

### Product Management
- `viewProducts`, `createProducts`, `editProducts`, `deleteProducts`
- `importProducts`, `exportProducts`

### Client Management
- `viewOwnClients`, `viewAllClients`, `createClients`
- `editOwnClients`, `editAllClients`
- `deleteOwnClients`, `deleteAllClients`

### Quote Management
- `viewOwnQuotes`, `viewAllQuotes`, `createQuotes`
- `editOwnQuotes`, `editAllQuotes`
- `deleteOwnQuotes`, `deleteAllQuotes`
- `duplicateQuotes`, `exportQuotes`, `emailQuotes`

### User Management
- `viewUsers`, `createUsers`, `editUsers`, `deleteUsers`
- `assignRoles`, `viewUserApprovals`, `approveUsers`

### System Administration
- `accessAdminPanel`, `viewSystemMetrics`
- `viewPerformanceDashboard`, `viewStockDashboard`
- `manageDatabase`, `backupSystem`, `populateDemoData`

## Migration from Email-Based Checks

### Before (Email-based)
```dart
if (user?.email == 'andres@turboairmexico.com') {
  // Admin functionality
}
```

### After (RBAC-based)
```dart
if (await RBACService.hasPermissionEnum(Permission.accessAdminPanel)) {
  // Admin functionality
}
```

### Temporary Migration Support
The system includes legacy compatibility providers that combine RBAC with email checks:

```dart
final isAdmin = ref.watch(migrationPermissionProvider(Permission.accessAdminPanel));
```

## Role Permissions Matrix

| Permission | Distributor | Sales | Admin | SuperAdmin |
|------------|-------------|--------|-------|------------|
| View Products | ✓ | ✓ | ✓ | ✓ |
| Create Clients | ✓ | ✓ | ✓ | ✓ |
| View All Clients | ✗ | ✗ | ✓ | ✓ |
| Edit All Quotes | ✗ | ✗ | ✓ | ✓ |
| Access Admin Panel | ✗ | ✗ | ✗ | ✓ |
| Assign Roles | ✗ | ✗ | ✗ | ✓ |
| Manage Database | ✗ | ✗ | ✗ | ✓ |

## Security Features

### Audit Logging
All permission checks are logged with user ID, permission, and result:

```dart
RBACService.logPermissionCheck(userId, Permission.editProducts, granted);
```

### Role Validation
Role assignments are validated before being applied:

```dart
final validation = await RBACService.validateRoleAssignment(
  adminUserId, targetUserId, newRole
);
if (!validation.isValid) {
  throw Exception(validation.message);
}
```

### Cache Management
User roles are cached for performance but can be cleared when needed:

```dart
RBACService.clearUserCache(userId);  // Clear specific user
RBACService.clearCache();            // Clear all cached roles
```

## Testing

Run the comprehensive test suite:

```dart
// Run in development only
import 'lib/core/auth/test/rbac_system_test.dart';

void main() {
  RbacSystemTest.runTests();
  RbacSystemTest.printRolePermissionMatrix();
}
```

## Database Schema

### User Profile Structure
```json
{
  "users": {
    "userId": {
      "email": "user@example.com",
      "name": "User Name",
      "role": "sales",
      "status": "active",
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z",
      "updated_by": "adminUserId"
    }
  }
}
```

## Best Practices

1. **Use Permission-Based Checks**: Always check specific permissions rather than roles when possible
2. **Principle of Least Privilege**: Grant minimum necessary permissions
3. **Audit Everything**: Log all permission checks for security monitoring
4. **Validate Role Changes**: Use `validateRoleAssignment()` before updating roles
5. **Cache Wisely**: Clear cache when user roles change
6. **Handle Errors Gracefully**: Permission checks should fail safely (deny access)

## Integration Points

### With Firebase Auth
```dart
final user = FirebaseAuth.instance.currentUser;
final role = await RBACService.getUserRole(user!.uid);
```

### With Riverpod State Management
```dart
final currentRole = ref.watch(currentUserRoleProvider);
final permissions = ref.watch(currentUserPermissionsProvider);
```

### With Existing Code
The system maintains backward compatibility with existing email-based checks while providing a migration path to full RBAC implementation.

## Future Enhancements

1. **Dynamic Permissions**: Runtime permission configuration
2. **Permission Templates**: Pre-defined permission sets
3. **Time-Based Access**: Temporary role assignments
4. **API Integration**: REST endpoints for role management
5. **Advanced Audit**: Detailed permission usage analytics