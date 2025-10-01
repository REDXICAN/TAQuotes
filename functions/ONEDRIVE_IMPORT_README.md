# OneDrive Excel Import - Cloud Function

Automatically import shipment tracking data from Microsoft OneDrive Excel file to Firebase Realtime Database every 30 minutes.

## Overview

This Firebase Cloud Function solution provides:

1. **Automatic scheduled imports** - Runs every 30 minutes
2. **Manual trigger option** - Admin can trigger imports on-demand
3. **Microsoft Graph API integration** - Securely accesses OneDrive files
4. **Excel parsing** - Supports .xlsx format with automatic header detection
5. **Firebase integration** - Imports data to `/tracking` node in Realtime Database
6. **Error handling** - Email alerts and detailed logging
7. **Import history** - Tracks all imports in `/import_logs`
8. **Security** - Admin-only access with Firebase Authentication

## Features

### 1. Scheduled Import (`scheduledOneDriveImport`)

- **Frequency**: Every 30 minutes
- **Timezone**: America/Mexico_City
- **Process**:
  1. Authenticate with Microsoft Graph API
  2. Download Excel file from OneDrive
  3. Parse Excel data (automatic header detection)
  4. Import to Firebase Realtime Database
  5. Log import result
  6. Send email alert on failure

### 2. Manual Trigger (`triggerOneDriveImport`)

- **Access**: Admin/SuperAdmin users only
- **Authentication**: Firebase ID token required
- **Use cases**:
  - Test imports before schedule runs
  - Force immediate import after Excel update
  - Troubleshoot import issues

### 3. Import Logs (`getImportLogs`)

- **Access**: Admin/SuperAdmin users only
- **Returns**: Last 50 imports by default
- **Data includes**:
  - Timestamp
  - Records count
  - Status (success/failed)
  - Error message (if failed)

## Architecture

```
┌─────────────────┐
│  OneDrive Excel │
│   (Tracking)    │
└────────┬────────┘
         │
         │ Microsoft Graph API
         │ (OAuth 2.0)
         ▼
┌─────────────────────────┐
│  Cloud Function         │
│  scheduledOneDriveImport│
│  (Every 30 minutes)     │
└────────┬────────────────┘
         │
         │ Parse & Transform
         │
         ▼
┌─────────────────────┐
│  Firebase Realtime  │
│  Database           │
│  /tracking          │
│  /import_logs       │
└─────────────────────┘
         │
         ▼
┌─────────────────┐
│  Flutter App    │
│  (Display Data) │
└─────────────────┘
```

## Excel File Format

### Expected Structure

The Excel file should have:
- **First row**: Column headers
- **Subsequent rows**: Data records
- **Supported formats**: .xlsx, .xls

### Example Excel Structure

| Tracking Number | Status | Ship Date | Customer Name | Customer Email | ... |
|----------------|--------|-----------|---------------|----------------|-----|
| TRK001 | In Transit | 2025-10-01 | John Doe | john@example.com | ... |
| TRK002 | Delivered | 2025-09-30 | Jane Smith | jane@example.com | ... |

### Column Mapping

Headers are automatically converted to lowercase with underscores:
- "Tracking Number" → `tracking_number`
- "Ship Date" → `ship_date`
- "Customer Name" → `customer_name`

## Database Structure

### `/tracking` Node

```json
{
  "tracking": {
    "TRK001": {
      "tracking_number": "TRK001",
      "status": "In Transit",
      "ship_date": "2025-10-01",
      "customer_name": "John Doe",
      "customer_email": "john@example.com",
      "imported_at": 1696176600000,
      "last_updated": 1696176600000
    },
    "TRK002": {
      "tracking_number": "TRK002",
      "status": "Delivered",
      "ship_date": "2025-09-30",
      "customer_name": "Jane Smith",
      "customer_email": "jane@example.com",
      "imported_at": 1696176600000,
      "last_updated": 1696176600000
    }
  }
}
```

### `/import_logs` Node

```json
{
  "import_logs": {
    "-NXxxx": {
      "type": "onedrive_excel_import",
      "records_count": 42,
      "timestamp": 1696176600000,
      "status": "success"
    },
    "-NXyyy": {
      "type": "onedrive_excel_import",
      "timestamp": 1696174800000,
      "status": "failed",
      "error": "Failed to download Excel file from OneDrive"
    }
  }
}
```

## Setup Instructions

### Quick Start

1. **Set up Microsoft Graph API**
   ```bash
   # See MICROSOFT_GRAPH_SETUP.md for detailed instructions
   ```

2. **Configure environment variables**
   ```bash
   cd functions
   cp .env.example .env
   # Edit .env with your credentials
   ```

3. **Install dependencies**
   ```bash
   cd functions
   npm install
   ```

4. **Deploy to Firebase**
   ```bash
   cd ..
   firebase deploy --only functions
   ```

### Detailed Setup

For complete setup instructions, see:
- `MICROSOFT_GRAPH_SETUP.md` - Microsoft Graph API configuration
- `ENVIRONMENT_SETUP.md` - Environment variables setup
- `DEPLOYMENT_GUIDE.md` - Deployment and testing

## Usage

### Testing Locally

```bash
# Start Firebase emulator
firebase emulators:start --only functions

# In another terminal, trigger import
curl -X POST http://localhost:5001/taquotes/us-central1/triggerOneDriveImport \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json"
```

### Manual Import in Production

```bash
# Get function URL
firebase functions:list | grep triggerOneDriveImport

# Trigger import (requires admin Firebase ID token)
curl -X POST https://us-central1-taquotes.cloudfunctions.net/triggerOneDriveImport \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json"
```

### View Import Logs

```bash
# Using Firebase CLI
firebase database:get /import_logs --limit-to-last 10

# Using Firebase Console
# Navigate to Realtime Database → /import_logs
```

### Monitor Scheduled Runs

```bash
# View function logs
firebase functions:log --only scheduledOneDriveImport

# Stream logs in real-time
firebase functions:log --only scheduledOneDriveImport --follow
```

## Integration with Flutter App

### Reading Tracking Data

Create a service in your Flutter app:

```dart
// lib/core/services/tracking_service.dart
import 'package:firebase_database/firebase_database.dart';

class TrackingService {
  final DatabaseReference _trackingRef =
    FirebaseDatabase.instance.ref('tracking');

  // Get all tracking records
  Stream<List<TrackingRecord>> getTrackingRecords() {
    return _trackingRef.onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final Map<dynamic, dynamic> data =
        event.snapshot.value as Map<dynamic, dynamic>;

      return data.entries.map((e) =>
        TrackingRecord.fromJson(e.value)
      ).toList();
    });
  }

  // Get specific tracking record
  Future<TrackingRecord?> getTrackingByNumber(String trackingNumber) async {
    final snapshot = await _trackingRef.child(trackingNumber).get();
    if (!snapshot.exists) return null;
    return TrackingRecord.fromJson(snapshot.value);
  }

  // Search tracking records
  Stream<List<TrackingRecord>> searchTracking(String query) {
    return getTrackingRecords().map((records) {
      return records.where((r) =>
        r.trackingNumber.toLowerCase().contains(query.toLowerCase()) ||
        r.customerName.toLowerCase().contains(query.toLowerCase()) ||
        r.customerEmail.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }
}

// Model class
class TrackingRecord {
  final String trackingNumber;
  final String status;
  final String shipDate;
  final String customerName;
  final String customerEmail;
  final int importedAt;
  final int lastUpdated;

  TrackingRecord({
    required this.trackingNumber,
    required this.status,
    required this.shipDate,
    required this.customerName,
    required this.customerEmail,
    required this.importedAt,
    required this.lastUpdated,
  });

  factory TrackingRecord.fromJson(Map<dynamic, dynamic> json) {
    return TrackingRecord(
      trackingNumber: json['tracking_number'] ?? '',
      status: json['status'] ?? '',
      shipDate: json['ship_date'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerEmail: json['customer_email'] ?? '',
      importedAt: json['imported_at'] ?? 0,
      lastUpdated: json['last_updated'] ?? 0,
    );
  }
}
```

### Display Tracking in UI

```dart
// lib/features/tracking/tracking_screen.dart
class TrackingScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingService = TrackingService();

    return Scaffold(
      appBar: AppBar(title: Text('Shipment Tracking')),
      body: StreamBuilder<List<TrackingRecord>>(
        stream: trackingService.getTrackingRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final records = snapshot.data ?? [];

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return ListTile(
                title: Text(record.trackingNumber),
                subtitle: Text('${record.customerName} - ${record.status}'),
                trailing: Text(record.shipDate),
              );
            },
          );
        },
      ),
    );
  }
}
```

### Manual Import Trigger from Flutter

```dart
// Trigger manual import (admin only)
Future<void> triggerManualImport() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not authenticated');

  // Get ID token
  final idToken = await user.getIdToken();

  // Call Cloud Function
  final response = await http.post(
    Uri.parse('https://us-central1-taquotes.cloudfunctions.net/triggerOneDriveImport'),
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('Import successful: ${data['recordsImported']} records');
  } else {
    throw Exception('Import failed: ${response.body}');
  }
}
```

## Security

### Access Control

1. **Manual import trigger** - Requires Firebase Authentication with admin/superAdmin claims
2. **Import logs function** - Admin/SuperAdmin only
3. **Environment variables** - Stored securely in Firebase config
4. **Microsoft credentials** - Never exposed to client

### Firebase Database Rules

Add to your `database.rules.json`:

```json
{
  "rules": {
    "tracking": {
      ".read": "auth != null",
      ".write": false
    },
    "import_logs": {
      ".read": "auth.token.admin === true || auth.token.superAdmin === true",
      ".write": false
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only database
```

## Troubleshooting

### Common Issues

#### Import Not Running
- Check Cloud Scheduler is enabled
- Verify function is deployed
- Check function logs for errors

#### Authentication Errors
- Verify Microsoft credentials are correct
- Check client secret hasn't expired
- Ensure API permissions are granted

#### File Download Errors
- Verify OneDrive share link is valid
- Check file sharing permissions
- Test link in browser

#### Parse Errors
- Verify Excel file has headers in first row
- Check file format is .xlsx
- Ensure file is not corrupted

### Debug Checklist

- [ ] Environment variables configured
- [ ] Microsoft Graph API permissions granted
- [ ] OneDrive file is accessible
- [ ] Cloud Scheduler enabled
- [ ] Function deployed successfully
- [ ] Database rules allow writes from function
- [ ] Email configuration for alerts

### Getting Help

1. Check function logs: `firebase functions:log`
2. Review import logs in database: `/import_logs`
3. Test manually: `triggerOneDriveImport` endpoint
4. Check email for failure alerts
5. Contact: andres@turboairmexico.com

## Performance

### Execution Metrics

- **Average execution time**: 5-10 seconds
- **Memory usage**: ~128-256 MB
- **Network usage**: Depends on Excel file size
- **Cost**: Within Firebase free tier for typical usage

### Optimization Tips

1. **Reduce frequency** if data doesn't change often
2. **Use smaller Excel files** for faster processing
3. **Add caching** if same data processed repeatedly
4. **Batch updates** instead of individual writes

## Monitoring

### Key Metrics to Track

1. **Import success rate**
   - Check `/import_logs` for failed imports
   - Set up alerts for consecutive failures

2. **Execution time**
   - Monitor function logs
   - Alert if execution time > 30 seconds

3. **Data freshness**
   - Track `last_updated` timestamps
   - Alert if no updates in expected timeframe

4. **Cost**
   - Monitor Cloud Functions usage
   - Set budget alerts

### Setting Up Alerts

```bash
# Create alert for function errors
gcloud alpha monitoring policies create \
  --notification-channels=EMAIL_CHANNEL_ID \
  --display-name="OneDrive Import Failures" \
  --condition-display-name="Error rate > 10%" \
  --condition-threshold-value=0.1
```

## Maintenance

### Regular Tasks

**Daily**:
- Check import logs for failures
- Verify data is being updated

**Weekly**:
- Review function logs
- Check for any errors or warnings
- Verify email alerts are working

**Monthly**:
- Update dependencies: `npm update`
- Review and optimize based on usage
- Check Microsoft credentials expiration

**Before Expiration**:
- Rotate Microsoft client secret
- Update environment variables
- Test after rotation

## Changelog

### Version 1.0.0 (October 2025)
- Initial release
- Scheduled import every 30 minutes
- Microsoft Graph API integration
- Excel parsing with automatic header detection
- Firebase Realtime Database integration
- Error handling and email alerts
- Import history logging
- Manual trigger for admins

## License

Internal use only - TurboAir Quotes application

## Support

For questions or issues:
- Email: andres@turboairmexico.com
- Documentation: See `MICROSOFT_GRAPH_SETUP.md`, `ENVIRONMENT_SETUP.md`, `DEPLOYMENT_GUIDE.md`
- Firebase Console: https://console.firebase.google.com/project/taquotes

---

**Status**: Production Ready
**Last Updated**: October 1, 2025
**Version**: 1.0.0
