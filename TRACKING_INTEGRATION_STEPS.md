# Shipment Tracking - Quick Integration Steps

## Overview
This document provides step-by-step instructions to integrate the new shipment tracking system into your TAQuotes application.

## Prerequisites
- All tracking files have been created
- Firebase project is active
- Admin access to Firebase Console

## Integration Steps

### Step 1: Firebase Database Rules (5 minutes)

1. Open Firebase Console: https://console.firebase.google.com
2. Select project: `taquotes`
3. Go to **Realtime Database** → **Rules**
4. Add this section to your existing rules:

```json
{
  "rules": {
    "tracking": {
      ".read": "auth != null",
      ".write": "auth != null && (auth.token.admin == true || auth.token.email == 'andres@turboairmexico.com')",
      "$trackingId": {
        ".validate": "newData.hasChildren(['trackingNumber', 'status', 'createdAt'])"
      }
    }
  }
}
```

5. Click **Publish**

### Step 2: Update Admin Panel (10 minutes)

Open `lib/features/admin/presentation/screens/admin_panel_screen.dart`

**Add import at the top:**
```dart
import '../widgets/tracking_import_widget.dart';
```

**Add to your admin panel sections (around line 400-500, in the appropriate location):**
```dart
ExpansionTile(
  leading: const Icon(Icons.local_shipping),
  title: const Text('Shipment Tracking'),
  subtitle: const Text('Import and manage tracking data from Excel'),
  children: const [
    Padding(
      padding: EdgeInsets.all(16),
      child: TrackingImportWidget(),
    ),
  ],
),
```

### Step 3: Update Routing (5 minutes)

Find your routing configuration file (usually `lib/core/router/app_router.dart` or similar).

**Option A: Simple - Keep existing quotes screen, add new route**
```dart
GoRoute(
  path: '/tracking',
  name: 'tracking',
  builder: (context, state) => const Scaffold(
    appBar: AppBar(title: Text('Shipment Tracking')),
    body: TrackingTabWidget(),
  ),
),
```

**Option B: Full Integration - Replace quotes screen**
```dart
// Change this:
GoRoute(
  path: '/quotes',
  name: 'quotes',
  builder: (context, state) => const QuotesScreen(),
),

// To this:
GoRoute(
  path: '/quotes',
  name: 'quotes',
  builder: (context, state) => const QuotesWithTrackingScreen(),
),
```

### Step 4: Update Dependencies (2 minutes)

Check `pubspec.yaml` has these dependencies (should already be present):

```yaml
dependencies:
  firebase_database: ^10.0.0  # For Realtime Database
  file_picker: ^6.0.0         # For Excel file selection
  excel: ^4.0.0               # For Excel parsing
  intl: ^0.18.0              # For date formatting
```

If any are missing, run:
```bash
flutter pub get
```

### Step 5: Test the Integration (15 minutes)

#### 5.1 Test Tracking UI
1. Run the app: `flutter run -d chrome`
2. Navigate to **Quotes** screen
3. Click on **Tracking** tab
4. Verify:
   - Empty state shows "No shipments found"
   - Statistics cards show zeros
   - Search and filter UI displays correctly

#### 5.2 Test Excel Upload
1. Navigate to **Admin Panel**
2. Find **Shipment Tracking** section
3. Click to expand
4. Create a test Excel file with these columns:
   | Tracking Number | Quote Number | Customer Name | Status | Carrier |
   |----------------|--------------|---------------|---------|---------|
   | TEST123 | Q-2025-001 | Test Customer | In Transit | FedEx |
5. Upload the file
6. Verify preview shows correctly
7. Click **Import**
8. Verify success message

#### 5.3 Test Tracking Display
1. Go back to **Quotes** → **Tracking** tab
2. Verify the test tracking appears
3. Click on the tracking card
4. Verify detailed dialog opens
5. Verify all data displays correctly

### Step 6: Deploy to Production (10 minutes)

#### 6.1 Build for Web
```bash
flutter build web --release --web-renderer html
```

#### 6.2 Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

#### 6.3 Verify Production
1. Open production URL: https://taquotes.web.app
2. Test all functionality
3. Check Firebase Console for data

## Optional: Cloud Function Auto-Sync

See `TRACKING_CLOUD_FUNCTION_SETUP.md` for detailed instructions on setting up automatic Excel syncing from OneDrive.

**Estimated setup time**: 1-2 hours
**Cost**: < $1/month

## Rollback Plan

If you need to rollback:

### Undo Admin Panel Changes
```dart
// Remove the tracking import and ExpansionTile from admin_panel_screen.dart
```

### Undo Routing Changes
```dart
// Change back from QuotesWithTrackingScreen to QuotesScreen
GoRoute(
  path: '/quotes',
  name: 'quotes',
  builder: (context, state) => const QuotesScreen(),
),
```

### Remove Firebase Rules
Remove the `"tracking"` section from Firebase Database rules.

### Redeploy
```bash
flutter build web --release --web-renderer html
firebase deploy --only hosting
```

## Troubleshooting

### Issue: "No tracking data showing"
**Solution**:
1. Check Firebase Console → Realtime Database
2. Verify `/tracking` path exists
3. Check browser console for errors
4. Verify database rules were published

### Issue: "Excel upload fails"
**Solution**:
1. Verify file is .xlsx format (not .xls)
2. Check required columns exist
3. Ensure no empty tracking numbers
4. Try with sample data first

### Issue: "Permission denied"
**Solution**:
1. Verify user is logged in
2. Check Firebase auth token has email
3. Verify database rules include your admin email
4. Clear browser cache and re-login

### Issue: "Build errors"
**Solution**:
```bash
flutter clean
flutter pub get
flutter build web --release --web-renderer html
```

## Verification Checklist

- [ ] Firebase rules published
- [ ] Admin panel shows tracking import widget
- [ ] Quotes screen has Tracking tab
- [ ] Can upload Excel file
- [ ] Tracking data displays in list
- [ ] Can click tracking for details
- [ ] Search and filters work
- [ ] Statistics cards show correct counts
- [ ] Mobile responsive design works
- [ ] Production deployment successful

## Support

If you encounter issues:

1. Check console for error messages
2. Verify Firebase Console shows data correctly
3. Review `TRACKING_SYSTEM_README.md` for detailed docs
4. Contact: andres@turboairmexico.com

## Timeline

- **Minimum**: 30 minutes (manual testing)
- **Standard**: 1 hour (full integration + testing)
- **With Cloud Function**: 2-3 hours (includes auto-sync setup)

## Next Steps

After successful integration:

1. Create sample tracking data for testing
2. Train users on Excel upload process
3. Document your specific Excel format
4. Set up Cloud Function for auto-sync (optional)
5. Monitor Firebase usage and costs
6. Gather user feedback for improvements

---

**Created**: January 2025
**Version**: 1.0.0
**Status**: Ready for Integration
