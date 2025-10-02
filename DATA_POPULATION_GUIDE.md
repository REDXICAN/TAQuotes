# Data Population Guide - TurboAir Quotes

## Overview
This guide explains how to populate demo data, warehouse stock, and other test data in your TurboAir Quotes application.

---

## 🎯 Quick Start - What You Asked To Populate Earlier

### **1. Populate Demo Data (Users, Clients, Quotes)**

**Location**: Admin Panel → Settings Tab → Demo Data Section

**Steps**:
1. Log in as admin (andres@turboairmexico.com)
2. Navigate to **Admin Panel** (admin icon in sidebar)
3. Click the **Settings** tab (gear icon)
4. Scroll to **"Demo Data Management"** section
5. Click **"Populate Demo Data"** button
6. Confirm in dialog
7. Wait for completion (creates 10 users, 30 clients, 100 quotes)

**What Gets Created**:
```
✅ 10 Demo Users (with Firebase Authentication)
   - Emails: demouser1@turboair.com through demouser10@turboair.com
   - Password: DemoPass123!
   - Roles: Mix of sales, distributors, and admins

✅ 30 Demo Clients (3 per user)
   - Company names from real restaurant chains
   - Complete contact information
   - Addresses across different states

✅ 100 Demo Quotes (10 per user)
   - Random products from catalog
   - Realistic pricing ($5,000 - $50,000 range)
   - Various statuses: draft, pending, accepted, rejected
   - Date range: Past 90 days
```

**Code Location**: `lib/features/admin/presentation/widgets/comprehensive_data_populator.dart`

---

### **2. Populate Warehouse Stock**

You have **THREE OPTIONS** for populating warehouse stock:

#### **Option A: Automatic Stock Generation (Recommended for Testing)**

**File**: `lib/scripts/generate_warehouse_stock.dart`

Create this script:
```dart
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';

Future<void> generateWarehouseStock() async {
  final database = FirebaseDatabase.instance;
  final productsRef = database.ref('products');

  // Get all products
  final snapshot = await productsRef.get();
  if (!snapshot.exists) {
    print('No products found');
    return;
  }

  final products = snapshot.value as Map<dynamic, dynamic>;
  final warehouses = ['KR', 'VN', 'CN', 'TX', 'CUN', 'CDMX'];
  final random = Random();

  int count = 0;
  for (var entry in products.entries) {
    final productId = entry.key;

    // Generate stock for 2-4 random warehouses per product
    final numWarehouses = 2 + random.nextInt(3);
    final selectedWarehouses = warehouses..shuffle();

    final warehouseStock = <String, Map<String, int>>{};

    for (int i = 0; i < numWarehouses; i++) {
      final warehouse = selectedWarehouses[i];
      final available = random.nextInt(100) + 10; // 10-110 units
      final reserved = random.nextInt(available ~/ 2); // 0-50% reserved

      warehouseStock[warehouse] = {
        'available': available,
        'reserved': reserved,
      };
    }

    // Update product with warehouse stock
    await productsRef.child(productId).update({
      'warehouseStock': warehouseStock,
    });

    count++;
    if (count % 50 == 0) {
      print('Updated $count products...');
    }
  }

  print('✅ Stock generation complete! Updated $count products.');
}
```

**Run it**:
```bash
dart lib/scripts/generate_warehouse_stock.dart
```

---

#### **Option B: Import from Excel Spreadsheet**

**Steps**:
1. Create Excel file: `warehouse_stock.xlsx`
2. Format with columns:

| SKU | Warehouse | Available | Reserved |
|-----|-----------|-----------|----------|
| PRO-12R-N | KR | 45 | 5 |
| PRO-12R-N | VN | 30 | 0 |
| PRO-26R-N | TX | 25 | 10 |

3. Navigate to: **Catalog → Products** screen
4. Click **Import** button (cloud upload icon)
5. Select your `warehouse_stock.xlsx` file
6. Choose import mode: **"Update existing products"**
7. Review preview
8. Click **"Import"**

**Code handles Excel import**: `lib/features/products/widgets/excel_preview_dialog.dart`

---

#### **Option C: Manual Firebase Console Entry**

**Steps**:
1. Go to [Firebase Console](https://console.firebase.google.com/project/taquotes/database)
2. Navigate to: `Realtime Database → products → [product-id]`
3. Add new child: `warehouseStock`
4. Structure:
```json
{
  "warehouseStock": {
    "KR": {
      "available": 50,
      "reserved": 5
    },
    "VN": {
      "available": 30,
      "reserved": 0
    },
    "TX": {
      "available": 25,
      "reserved": 3
    }
  }
}
```

**Warehouse Codes**:
- `KR` - South Korea
- `VN` - Vietnam
- `CN` - China
- `TX` - Texas, USA
- `CUN` - Cancún, Mexico
- `CDMX` - Mexico City, Mexico

---

## 🔧 Advanced Population Options

### **3. Populate Error Monitoring Test Data**

**Purpose**: Test error tracking and resolution workflows

**Steps**:
1. Admin Panel → Error Monitoring tab
2. Bottom section: **"Demo Data Management"**
3. Click **"Generate Test Errors"** button
4. Creates 20 sample errors across different categories

**What Gets Created**:
- Authentication errors
- Database errors
- Network errors
- Validation errors
- Business logic errors

**Code**: `lib/core/services/error_demo_data_service.dart`

---

### **4. Populate Spare Parts Catalog**

**Location**: Catalog → Spare Parts tab

**Current State**: Uses demo data from `SparePartsDemoService`

**To Add Real Data**:

**Option 1 - Via Code**:
```dart
// Add to Firebase Realtime Database
final database = FirebaseDatabase.instance;
final sparePartsRef = database.ref('spare_parts');

await sparePartsRef.push().set({
  'sku': 'SP-COMP-001',
  'name': 'Compressor Unit - R404A',
  'description': 'Replacement compressor compatible with PRO series',
  'price': 450.00,
  'category': 'Compressors',
  'compatibleWith': ['PRO-12R-N', 'PRO-26R-N'],
  'stock': 15,
  'warehouse': 'TX',
  'imageUrl': 'https://...',
});
```

**Option 2 - Via Excel Import**:
Same as warehouse stock import, but with spare parts columns.

---

### **5. Populate Historical Tracking Data**

**Purpose**: Test project tracking and shipment history

**Code Location**: `lib/core/services/historical_tracking_service.dart`

**Automatic Creation**: Tracking entries are created automatically when:
- Quotes are converted to projects
- Projects are shipped
- Status updates occur

**Manual Population**:
```dart
final trackingService = HistoricalTrackingService(database);

await trackingService.recordAction(
  entityType: EntityType.project,
  entityId: 'project-123',
  action: ActionType.statusUpdate,
  userId: currentUser.uid,
  metadata: {
    'oldStatus': 'pending',
    'newStatus': 'shipped',
    'trackingNumber': 'TRACK-12345',
  },
);
```

---

## 📊 Verification - How To Check If Data Was Populated

### **1. Check Demo Users**
```bash
# Firebase Console → Authentication → Users
# Should see: demouser1@turboair.com through demouser10@turboair.com
```

### **2. Check Demo Clients**
```bash
# Firebase Console → Realtime Database → clients
# Should see 30+ clients under different user IDs
```

### **3. Check Demo Quotes**
```bash
# Firebase Console → Realtime Database → quotes
# Should see 100+ quotes under different user IDs
```

### **4. Check Warehouse Stock**
```bash
# Firebase Console → Realtime Database → products → [any-product] → warehouseStock
# Should see map with warehouse codes (KR, VN, CN, etc.)
```

### **5. Check in App**
- **Products**: Catalog → Products (should show stock badges)
- **Stock Dashboard**: Catalog → Stock tab (should show warehouse inventory)
- **Performance**: Admin Panel → Performance tab (should show user data)
- **Monitoring**: Admin Panel → Monitoring tab (should show quotes/clients)

---

## 🚨 Important Notes

### **Before Populating Production Data**:

1. **Backup First**:
```bash
firebase database:get / > backup-$(date +%Y%m%d-%H%M%S).json
```

2. **Test Mode Toggle**:
The app has a "Test Mode" that uses demo data instead of production:
- Toggle in: Admin Panel → Settings → Test Mode
- When enabled, shows orange "TEST MODE" badge
- Demo data is only shown in test mode

3. **Don't Populate Production with Fake Data**:
- Demo users have weak passwords (DemoPass123!)
- Demo clients are fictional companies
- Demo quotes have random data
- **Only use for development/testing environments**

4. **Clean Up Demo Data**:
```dart
// In Admin Panel → Settings → Demo Data
// Click "Clear Demo Data" button
// Removes all test users, clients, and quotes
```

---

## 🔑 Access Requirements

**To Populate Data, You Need**:
- ✅ SuperAdmin or Admin role
- ✅ Email: andres@turboairmexico.com (for full access)
- ✅ Firebase project: `taquotes`
- ✅ Realtime Database write permissions

**Permissions Check**:
```dart
// All population operations check permissions first
final hasPermission = await RBACService.hasPermission(
  Permission.manageTestData
);

if (!hasPermission) {
  throw Exception('Access denied');
}
```

---

## 📝 Example: Full Demo Environment Setup

**Complete setup for testing (5 minutes)**:

1. **Clear existing data** (optional):
```bash
firebase database:delete /quotes
firebase database:delete /clients
firebase database:delete /spare_parts
```

2. **Populate demo users & data**:
   - Admin Panel → Settings → "Populate Demo Data"
   - Wait ~30 seconds

3. **Populate warehouse stock**:
```bash
dart lib/scripts/generate_warehouse_stock.dart
```

4. **Populate test errors**:
   - Admin Panel → Error Monitoring → "Generate Test Errors"

5. **Verify**:
   - Check Catalog → Stock tab (should load)
   - Check Admin Panel → Monitoring (should show data)
   - Check Admin Panel → Performance (should show user metrics)

---

## 🆘 Troubleshooting

### **Issue: "Populate Demo Data" button does nothing**

**Causes**:
1. Not logged in as admin
2. Firebase rules block write access
3. Network error

**Fix**:
```bash
# Check Firebase rules
firebase database:get /.info/rules

# Should allow admin writes:
{
  "rules": {
    ".write": "auth.token.email == 'andres@turboairmexico.com' || auth.token.role == 'superadmin'"
  }
}
```

### **Issue: Stock tab still not loading**

**Causes**:
1. Products don't have warehouseStock field
2. Cached old data

**Fix**:
```bash
# Force refresh
1. Clear browser cache (Ctrl+Shift+R)
2. Or use: Admin Panel → Settings → "Clear Cache"
```

### **Issue: Excel import fails**

**Causes**:
1. File size > 10MB
2. Incorrect column names
3. Invalid SKU references

**Fix**:
- Check file format matches template
- Ensure SKUs exist in products database
- Split large files into <10MB chunks

---

## 📚 Related Documentation

- **CLAUDE.md** - Full development guide
- **README.md** - Project overview
- **Firebase Console** - https://console.firebase.google.com/project/taquotes

---

**Last Updated**: October 2, 2025
**Version**: 1.0.2
