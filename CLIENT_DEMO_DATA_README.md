# Client Demo Data Implementation

## Overview

This implementation provides a complete solution for checking if the admin user (andres@turboairmexico.com) has clients in Firebase and automatically populating demo client data if none exist.

## Files Created

### 1. Core Service
- **`lib/core/services/client_demo_data_service.dart`**
  - Main service for managing demo client data
  - Contains 10 realistic TurboAir equipment company clients
  - Provides methods to populate, clear, and check client data

### 2. Utility Class
- **`lib/core/utils/admin_client_checker.dart`**
  - High-level utility for admin client management
  - Provides easy-to-use methods for checking and populating data
  - Handles authentication and error cases

### 3. Standalone Script
- **`lib/scripts/check_and_populate_admin_clients.dart`**
  - Command-line script to check and populate clients
  - Can be run independently for testing
  - Provides detailed console output

### 4. Settings Integration
- **Updated `lib/features/settings/presentation/screens/app_settings_screen.dart`**
  - Added "Client Demo Data Management" section
  - Three buttons: Check Status, Populate Demo Data, Clear Data
  - Integrated with existing admin settings UI

## Demo Client Data

The service includes 10 realistic clients for TurboAir equipment:

1. **Grand Palace Hotel Group** (Miami Beach, FL)
2. **La Cocina Mexicana Restaurant** (Cancún, Mexico)
3. **Fresh Market Distributors** (Houston, TX)
4. **Seaside Seafood Company** (Playa del Carmen, Mexico)
5. **Metro Cafeteria Services** (Dallas, TX)
6. **Tropical Ice Cream Factory** (Mérida, Mexico)
7. **Golden Gate Catering** (San Francisco, CA)
8. **Beachfront Resort & Spa** (Key Largo, FL)
9. **Mercado Central Wholesale** (Mexico City, Mexico)
10. **Campus Dining Solutions** (Austin, TX)

Each client includes:
- Company name and contact person
- Realistic email and phone number
- Complete address information
- Business notes describing their needs for commercial kitchen equipment

## Usage

### From App Settings (Recommended)
1. Log in as admin user (andres@turboairmexico.com)
2. Navigate to Admin Panel → Settings
3. Scroll down to "Client Demo Data Management" section
4. Use the buttons to:
   - **Check Status**: See if admin has existing clients
   - **Populate**: Create demo clients (can be run multiple times)
   - **Clear**: Remove all client data for admin user

### Programmatic Usage
```dart
import 'package:your_app/core/utils/admin_client_checker.dart';

// Check status and populate if needed
final result = await AdminClientChecker.checkAndSetupAdminClients();

// Force populate demo data
final result = await AdminClientChecker.forcePopulateDemoClients();

// Clear all clients
final result = await AdminClientChecker.clearAdminClients();

// Get current status
final status = await AdminClientChecker.getAdminClientStatus();
```

### Using the Service Directly
```dart
import 'package:your_app/core/services/client_demo_data_service.dart';

final demoService = ClientDemoDataService();

// Check if admin has clients
final hasClients = await demoService.hasExistingClients(adminUserId);

// Get client count
final count = await demoService.getClientCount(adminUserId);

// Populate demo data
await demoService.populateDemoClientData(adminUserId);

// Clear demo data
await demoService.clearDemoClientData(adminUserId);
```

## Firebase Structure

Clients are stored in Firebase Realtime Database at:
```
/clients/{adminUserId}/{clientId}
```

Each client document contains:
```json
{
  "id": "generated_id",
  "company": "Company Name",
  "contactName": "Contact Person",
  "email": "email@company.com",
  "phone": "+1 (555) 123-4567",
  "address": "Full Address",
  "city": "City",
  "state": "State",
  "zipCode": "12345",
  "country": "Country",
  "notes": "Business description and equipment needs",
  "created_at": timestamp,
  "updated_at": timestamp
}
```

## Security Notes

- Only the admin user (andres@turboairmexico.com) can populate/clear client data
- All operations are logged using the app's logging system
- Confirmation dialogs prevent accidental data deletion
- Firebase security rules should restrict client write access to authenticated users

## Testing

1. **Manual Testing**:
   - Log in as admin user
   - Go to Settings → Client Demo Data Management
   - Test all three buttons

2. **Script Testing**:
   - Run the standalone script while admin is logged in
   - Check console output for success/failure

3. **Database Verification**:
   - Check Firebase Console under `/clients/{adminUserId}`
   - Verify client count and data structure

## Error Handling

All operations include comprehensive error handling:
- Invalid user authentication
- Network connectivity issues
- Firebase permission errors
- Data validation problems

Errors are logged and displayed to the user through the UI.

## Integration Notes

This implementation:
- ✅ Follows existing codebase patterns
- ✅ Uses the same logging system as other services
- ✅ Integrates with existing RBAC permissions
- ✅ Follows the same UI design as other demo data sections
- ✅ Includes proper error handling and user feedback
- ✅ Works with the existing Firebase database structure

The admin user will now have realistic client data to work with when testing the application!