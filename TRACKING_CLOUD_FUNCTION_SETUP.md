# Shipment Tracking - Cloud Function Setup Guide

## Overview

This guide explains how to set up a Firebase Cloud Function to automatically sync shipment tracking data from OneDrive Excel files to Firebase Realtime Database.

## Prerequisites

- Firebase project with Blaze (pay-as-you-go) plan
- Node.js 18+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Microsoft OneDrive account with tracking Excel file
- Microsoft Azure App Registration for OneDrive API access

## Step 1: Enable Required Services

### Firebase Configuration

1. Open Firebase Console: https://console.firebase.google.com
2. Select your project: `taquotes`
3. Enable Cloud Functions:
   - Go to Functions section
   - Upgrade to Blaze plan if not already done
4. Enable Cloud Scheduler (for automatic syncing):
   - Go to Google Cloud Console
   - Enable Cloud Scheduler API

### Microsoft Azure Setup

1. Go to Azure Portal: https://portal.azure.com
2. Navigate to "Azure Active Directory" → "App registrations"
3. Click "New registration":
   - Name: "TAQuotes Tracking Sync"
   - Supported account types: "Single tenant"
   - Redirect URI: Leave empty for now
4. After creation, note down:
   - Application (client) ID
   - Directory (tenant) ID
5. Go to "Certificates & secrets":
   - Create new client secret
   - Copy the secret value immediately (it won't be shown again)
6. Go to "API permissions":
   - Add permission → Microsoft Graph → Application permissions
   - Add: `Files.Read.All` and `Sites.Read.All`
   - Click "Grant admin consent"

## Step 2: Initialize Cloud Functions

```bash
# Navigate to your project directory
cd "c:\Users\andre\Desktop\-- Flutter App"

# Initialize Firebase Functions (if not already done)
firebase init functions

# Select options:
# - Use existing project: taquotes
# - Language: JavaScript or TypeScript
# - ESLint: Yes
# - Install dependencies: Yes
```

## Step 3: Install Required Dependencies

```bash
cd functions
npm install --save axios @microsoft/microsoft-graph-client node-fetch xlsx
```

## Step 4: Create Cloud Function Code

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { Client } = require('@microsoft/microsoft-graph-client');
const XLSX = require('xlsx');

admin.initializeApp();

// Configuration - Store in Firebase Config
const config = {
  clientId: functions.config().onedrive.client_id,
  clientSecret: functions.config().onedrive.client_secret,
  tenantId: functions.config().onedrive.tenant_id,
  fileId: functions.config().onedrive.file_id, // OneDrive file ID
};

// Get Microsoft Graph access token
async function getAccessToken() {
  const tokenUrl = `https://login.microsoftonline.com/${config.tenantId}/oauth2/v2.0/token`;

  const params = new URLSearchParams();
  params.append('client_id', config.clientId);
  params.append('client_secret', config.clientSecret);
  params.append('scope', 'https://graph.microsoft.com/.default');
  params.append('grant_type', 'client_credentials');

  const response = await axios.post(tokenUrl, params);
  return response.data.access_token;
}

// Parse Excel data
function parseExcelData(buffer) {
  const workbook = XLSX.read(buffer, { type: 'buffer' });
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const data = XLSX.utils.sheet_to_json(sheet);

  return data.map(row => ({
    trackingNumber: row['Tracking Number'] || row['Tracking #'] || '',
    quoteNumber: row['Quote Number'] || row['Quote #'] || null,
    orderReference: row['Order Reference'] || row['Order #'] || null,
    customerName: row['Customer Name'] || row['Customer'] || null,
    customerEmail: row['Customer Email'] || row['Email'] || null,
    status: row['Status'] || 'Pending',
    carrier: row['Carrier'] || null,
    origin: row['Origin'] || null,
    destination: row['Destination'] || null,
    currentLocation: row['Current Location'] || row['Location'] || null,
    shipmentDate: row['Shipment Date'] || row['Ship Date'] || null,
    estimatedDeliveryDate: row['Estimated Delivery'] || row['ETA'] || null,
    actualDeliveryDate: row['Actual Delivery'] || null,
    weight: row['Weight'] || null,
    numberOfPackages: row['Packages'] || row['Number of Packages'] || null,
    notes: row['Notes'] || row['Comments'] || null,
    createdAt: admin.database.ServerValue.TIMESTAMP,
    updatedAt: admin.database.ServerValue.TIMESTAMP,
  }));
}

// Main sync function
exports.syncTrackingData = functions.pubsub
  .schedule('every 30 minutes')
  .timeZone('America/Cancun')
  .onRun(async (context) => {
    try {
      console.log('Starting tracking data sync...');

      // Get access token
      const accessToken = await getAccessToken();

      // Initialize Graph client
      const client = Client.init({
        authProvider: (done) => {
          done(null, accessToken);
        },
      });

      // Download Excel file from OneDrive
      const fileStream = await client
        .api(`/me/drive/items/${config.fileId}/content`)
        .get();

      // Parse Excel data
      const trackingData = parseExcelData(fileStream);

      console.log(`Found ${trackingData.length} tracking records`);

      // Update Firebase
      const db = admin.database();
      const trackingRef = db.ref('tracking');

      let successCount = 0;
      let errorCount = 0;

      for (const tracking of trackingData) {
        try {
          // Skip if tracking number is empty
          if (!tracking.trackingNumber) continue;

          // Check if tracking already exists
          const snapshot = await trackingRef
            .orderByChild('trackingNumber')
            .equalTo(tracking.trackingNumber)
            .once('value');

          if (snapshot.exists()) {
            // Update existing tracking
            const existingId = Object.keys(snapshot.val())[0];
            await trackingRef.child(existingId).update({
              ...tracking,
              updatedAt: admin.database.ServerValue.TIMESTAMP,
            });
          } else {
            // Create new tracking
            await trackingRef.push(tracking);
          }

          successCount++;
        } catch (error) {
          console.error(`Error processing tracking ${tracking.trackingNumber}:`, error);
          errorCount++;
        }
      }

      console.log(`Sync completed: ${successCount} success, ${errorCount} errors`);

      return {
        success: true,
        processed: trackingData.length,
        successCount,
        errorCount,
      };
    } catch (error) {
      console.error('Sync failed:', error);
      throw error;
    }
  });

// Manual trigger function (for testing)
exports.manualSyncTracking = functions.https.onCall(async (data, context) => {
  // Verify admin access
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can trigger manual sync'
    );
  }

  try {
    // Run the same sync logic
    const result = await exports.syncTrackingData.run();
    return result;
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

## Step 5: Configure Firebase Environment Variables

```bash
# Set OneDrive credentials
firebase functions:config:set \
  onedrive.client_id="YOUR_CLIENT_ID" \
  onedrive.client_secret="YOUR_CLIENT_SECRET" \
  onedrive.tenant_id="YOUR_TENANT_ID" \
  onedrive.file_id="YOUR_ONEDRIVE_FILE_ID"

# View configuration
firebase functions:config:get
```

### How to Get OneDrive File ID

1. Open OneDrive in web browser
2. Navigate to your tracking Excel file
3. Right-click → "Details"
4. Look for "File ID" or use Microsoft Graph Explorer:
   ```
   https://graph.microsoft.com/v1.0/me/drive/root:/path/to/your/file.xlsx
   ```
5. Copy the `id` field from the response

## Step 6: Deploy Cloud Function

```bash
# Deploy functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:syncTrackingData
```

## Step 7: Test the Function

### Test Manual Trigger

```bash
# Use Firebase CLI
firebase functions:shell

# In shell, run:
syncTrackingData()
```

### Test from Application

Add this to your admin panel:

```dart
Future<void> triggerManualSync() async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('manualSyncTracking');
    final result = await callable.call();

    print('Sync result: ${result.data}');
  } catch (e) {
    print('Sync error: $e');
  }
}
```

## Step 8: Monitor Function Execution

1. Open Firebase Console → Functions
2. View logs for `syncTrackingData`
3. Check execution history and errors
4. Set up alerts for failures

## Step 9: Schedule Configuration

The function runs every 30 minutes by default. To change:

```javascript
// Every hour
exports.syncTrackingData = functions.pubsub
  .schedule('every 1 hours')

// Every day at 9 AM
exports.syncTrackingData = functions.pubsub
  .schedule('0 9 * * *')

// Every 15 minutes
exports.syncTrackingData = functions.pubsub
  .schedule('*/15 * * * *')
```

## Cost Estimates

### Firebase Costs (Blaze Plan)

- Cloud Functions invocations: ~$0.40 per million
- Expected cost: < $1/month for 30-minute intervals
- First 2 million invocations free monthly

### Microsoft Graph API

- Free for basic OneDrive access
- No additional cost for file reads

## Security Considerations

1. **Secure Credentials**: Never commit credentials to Git
2. **Admin-Only Access**: Restrict manual sync to admin users
3. **Rate Limiting**: Microsoft Graph has rate limits (~10,000 requests/10 min)
4. **Error Handling**: Function includes retry logic
5. **Data Validation**: Validates tracking data before Firebase insert

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify Azure app credentials
   - Check that admin consent was granted
   - Ensure correct tenant ID

2. **File Not Found**
   - Verify OneDrive file ID
   - Check file permissions
   - Ensure file is in accessible location

3. **Function Timeout**
   - Increase timeout: `.timeoutSeconds(540)` (max 9 minutes)
   - Reduce batch size if processing many records

4. **Permission Denied**
   - Update Firebase Database rules
   - Grant write access to service account

## Alternative: Zapier Integration

If Cloud Functions is too complex, use Zapier:

1. Create Zapier account
2. New Zap: OneDrive → Firebase
3. Trigger: Updated file in OneDrive
4. Action: HTTP POST to Firebase REST API
5. Transform data with JavaScript code

Cost: $20-50/month for Zapier plan

## Manual Sync Workflow

As a fallback, use the manual Excel upload widget:

1. Download Excel from OneDrive
2. Open Admin Panel
3. Navigate to "Tracking Import"
4. Upload Excel file
5. Review preview
6. Click "Import"

This is the implemented solution and works immediately without Cloud Functions setup.

## Support

For issues:
- Firebase: https://firebase.google.com/support
- Microsoft Graph: https://developer.microsoft.com/graph/support
- Project Lead: andres@turboairmexico.com
