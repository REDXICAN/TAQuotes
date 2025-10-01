# OneDrive Excel Import - Deployment Guide

Complete guide for deploying the OneDrive Excel import Cloud Functions to Firebase.

## Prerequisites

Before deploying, ensure you have:

- [x] Completed Microsoft Graph API setup (see `MICROSOFT_GRAPH_SETUP.md`)
- [x] Configured environment variables (see `ENVIRONMENT_SETUP.md`)
- [x] Node.js 20 installed
- [x] Firebase CLI installed
- [x] Firebase project created (taquotes)
- [x] Admin access to Firebase project

## Pre-Deployment Checklist

### 1. Verify Dependencies

```bash
cd "c:\Users\andre\Desktop\-- Flutter App\functions"

# Check package.json has required packages
cat package.json | grep -E "(axios|xlsx)"

# If not present, install them
npm install axios@^1.6.0 xlsx@^0.18.5 --save
```

### 2. Verify Environment Variables

**For Local Testing:**
```bash
# Check .env file exists
ls -la .env

# Verify contents (don't expose secrets!)
cat .env | grep -E "MICROSOFT_|ONEDRIVE_"
```

**For Production:**
```bash
# Check Firebase config
firebase functions:config:get

# Should show:
# {
#   "microsoft": {
#     "tenant_id": "...",
#     "client_id": "...",
#     "client_secret": "..."
#   },
#   "onedrive": {
#     "share_link": "..."
#   }
# }
```

### 3. Security Check

```bash
# Verify no secrets in Git
git diff --cached | grep -E "(client_secret|CLIENT_SECRET|password)"

# Should return nothing

# Check .gitignore includes .env
cat .gitignore | grep ".env"
```

## Installation Steps

### Step 1: Install Dependencies

```bash
cd "c:\Users\andre\Desktop\-- Flutter App\functions"

# Install Node.js dependencies
npm install

# Verify installation
npm list axios xlsx
```

Expected output:
```
functions@1.0.0
├── axios@1.6.0
└── xlsx@0.18.5
```

### Step 2: Configure Environment Variables

#### For Production Deployment:

```bash
# Navigate to project root
cd "c:\Users\andre\Desktop\-- Flutter App"

# Set Microsoft credentials
firebase functions:config:set \
  microsoft.tenant_id="YOUR_TENANT_ID" \
  microsoft.client_id="YOUR_CLIENT_ID" \
  microsoft.client_secret="YOUR_CLIENT_SECRET"

# Set OneDrive share link
firebase functions:config:set \
  onedrive.share_link="https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default"

# Verify configuration
firebase functions:config:get
```

### Step 3: Test Locally (Optional but Recommended)

```bash
# Start Firebase emulators
firebase emulators:start --only functions

# In another terminal, test the function
# First, get your Firebase ID token from your app

# Test manual trigger
curl -X POST http://localhost:5001/taquotes/us-central1/triggerOneDriveImport \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

Expected response:
```json
{
  "success": true,
  "message": "OneDrive import completed successfully",
  "recordsImported": 42,
  "timestamp": "2025-10-01T14:30:00.000Z"
}
```

### Step 4: Deploy to Production

```bash
cd "c:\Users\andre\Desktop\-- Flutter App"

# Deploy only the functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:scheduledOneDriveImport,functions:triggerOneDriveImport,functions:getImportLogs
```

Deployment typically takes 2-5 minutes.

Expected output:
```
✔  Deploy complete!

Functions:
  scheduledOneDriveImport(us-central1)
  triggerOneDriveImport(us-central1)
  getImportLogs(us-central1)
```

### Step 5: Verify Deployment

```bash
# List deployed functions
firebase functions:list

# Check function URLs
firebase functions:list | grep OneDrive
```

You should see:
```
scheduledOneDriveImport (Scheduled: every 30 minutes)
triggerOneDriveImport (HTTP Trigger)
getImportLogs (Callable)
```

### Step 6: Enable Cloud Scheduler

The scheduled function requires Cloud Scheduler to be enabled:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (taquotes)
3. Navigate to **Functions** tab
4. Find `scheduledOneDriveImport`
5. Verify it shows: **Scheduled: every 30 minutes**

If you see an error about Cloud Scheduler:

```bash
# Enable Cloud Scheduler API
gcloud services enable cloudscheduler.googleapis.com

# Redeploy
firebase deploy --only functions:scheduledOneDriveImport
```

### Step 7: Test Production Deployment

#### Test Manual Trigger:

```bash
# Get your function URL
firebase functions:list | grep triggerOneDriveImport

# Example URL:
# https://us-central1-taquotes.cloudfunctions.net/triggerOneDriveImport

# Get Firebase ID token from your app (admin user)
# Then test with curl:

curl -X POST https://us-central1-taquotes.cloudfunctions.net/triggerOneDriveImport \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

#### Test Scheduled Function:

The scheduled function runs automatically every 30 minutes. To trigger it manually:

```bash
# Use Cloud Scheduler
gcloud scheduler jobs run firebase-schedule-scheduledOneDriveImport-us-central1

# Or wait for next scheduled run (within 30 minutes)
```

## Monitoring and Logging

### View Function Logs

```bash
# Stream all function logs
firebase functions:log

# Filter by function name
firebase functions:log --only scheduledOneDriveImport

# Last 50 entries
firebase functions:log -n 50

# Follow logs in real-time
firebase functions:log --only scheduledOneDriveImport --follow
```

### Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **taquotes** project
3. Navigate to **Functions** → **Logs**
4. Filter by function name
5. Check for errors or success messages

### Check Import Logs in Database

The function stores import logs in Firebase Realtime Database under `/import_logs`:

```bash
# View import logs
firebase database:get /import_logs

# View last 10 imports
firebase database:get /import_logs --limit-to-last 10
```

Or in Firebase Console:
1. Navigate to **Realtime Database**
2. Browse to `/import_logs`
3. View import history with timestamps and status

### Check Imported Data

```bash
# View tracking data
firebase database:get /tracking

# View first 5 records
firebase database:get /tracking --limit-to-first 5
```

## Testing the Complete Flow

### 1. Manual Import Test

```bash
# Trigger manual import
curl -X POST https://us-central1-taquotes.cloudfunctions.net/triggerOneDriveImport \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json"
```

### 2. Check Logs

```bash
firebase functions:log --only triggerOneDriveImport -n 20
```

Look for:
- "Downloading Excel file from OneDrive..."
- "Excel file downloaded successfully, size: X bytes"
- "Parsing Excel data..."
- "Parsed X rows from Excel"
- "Importing tracking data to Firebase..."
- "Successfully imported X tracking records"

### 3. Verify Data in Database

```bash
# Check if data was imported
firebase database:get /tracking --limit-to-last 5
```

### 4. Check Import Logs

```bash
firebase database:get /import_logs --limit-to-last 1
```

Should show:
```json
{
  "-NXxxx": {
    "type": "onedrive_excel_import",
    "records_count": 42,
    "timestamp": 1696176600000,
    "status": "success"
  }
}
```

### 5. Test Error Handling

Temporarily change the OneDrive share link to an invalid URL:

```bash
firebase functions:config:set onedrive.share_link="https://invalid-url.com"
firebase deploy --only functions:scheduledOneDriveImport
```

Wait for next scheduled run (or trigger manually), then check:
1. Function logs for error messages
2. Email inbox for error alert (sent to andres@turboairmexico.com)
3. Import logs in database (should show status: "failed")

Restore correct configuration:
```bash
firebase functions:config:set onedrive.share_link="CORRECT_SHARE_LINK"
firebase deploy --only functions:scheduledOneDriveImport
```

## Scheduled Execution

### Schedule Configuration

Current schedule: **Every 30 minutes**

Located at: `America/Mexico_City` timezone

Runs at:
- :00 (e.g., 12:00, 12:30, 13:00, 13:30...)

### Modify Schedule

To change the schedule, edit `functions/index.js`:

```javascript
exports.scheduledOneDriveImport = functions.pubsub
  .schedule('every 15 minutes')  // Change this
  .timeZone('America/Mexico_City')
  .onRun(async (context) => {
    // ...
  });
```

Supported formats:
- `every 15 minutes`
- `every 1 hours`
- `every day 09:00`
- `every monday 09:00`
- Cron format: `0 */30 * * *` (every 30 minutes)

Supported timezones:
- `America/Mexico_City`
- `America/Chicago`
- `America/New_York`
- `UTC`

After changes:
```bash
firebase deploy --only functions:scheduledOneDriveImport
```

### View Next Scheduled Run

```bash
# List Cloud Scheduler jobs
gcloud scheduler jobs list --project=taquotes

# Describe specific job
gcloud scheduler jobs describe firebase-schedule-scheduledOneDriveImport-us-central1 --project=taquotes
```

## Troubleshooting

### Function Not Deploying

**Error**: `Functions prepare failed`

**Solution**:
```bash
cd functions
rm -rf node_modules package-lock.json
npm install
cd ..
firebase deploy --only functions
```

### Scheduled Function Not Running

**Error**: No logs from scheduled function

**Solution**:
1. Check Cloud Scheduler is enabled:
   ```bash
   gcloud services enable cloudscheduler.googleapis.com
   ```

2. Verify job exists:
   ```bash
   gcloud scheduler jobs list --project=taquotes
   ```

3. Manually trigger:
   ```bash
   gcloud scheduler jobs run firebase-schedule-scheduledOneDriveImport-us-central1 --project=taquotes
   ```

### "Missing Microsoft Graph API credentials"

**Error**: Function fails with credentials error

**Solution**:
```bash
# Check Firebase config
firebase functions:config:get

# If empty, set variables
firebase functions:config:set \
  microsoft.tenant_id="..." \
  microsoft.client_id="..." \
  microsoft.client_secret="..."

# Redeploy
firebase deploy --only functions
```

### "Failed to download Excel file"

**Error**: Cannot access OneDrive file

**Solution**:
1. Verify share link is valid (test in browser)
2. Check file still exists in OneDrive
3. Ensure file is shared with "Anyone with the link"
4. Verify Microsoft Graph API permissions are granted
5. Check access token is being generated correctly

### Import Logs Show Failed Status

**Error**: Import logs show `status: "failed"`

**Solution**:
1. Check function logs for detailed error:
   ```bash
   firebase functions:log --only scheduledOneDriveImport -n 50
   ```
2. Common issues:
   - Invalid OneDrive share link
   - Excel file format issues
   - Firebase database rules blocking writes
   - Network connectivity issues

### Email Alerts Not Sent

**Error**: Not receiving failure alert emails

**Solution**:
1. Verify email configuration:
   ```bash
   firebase functions:config:get email
   ```
2. Check Gmail app password is valid
3. Test email service separately:
   ```bash
   curl -X POST https://us-central1-taquotes.cloudfunctions.net/testEmail?recipientEmail=your-email@example.com
   ```

## Updating the Function

### Update Code

1. Edit `functions/index.js`
2. Test locally with emulator
3. Deploy changes:
   ```bash
   firebase deploy --only functions
   ```

### Update Dependencies

```bash
cd functions
npm update
npm audit fix
cd ..
firebase deploy --only functions
```

### Update Environment Variables

```bash
# Update specific variable
firebase functions:config:set microsoft.client_secret="new-secret"

# Redeploy (required for changes to take effect)
firebase deploy --only functions
```

## Rollback

If deployment causes issues:

```bash
# List recent deployments
firebase functions:list

# Rollback to previous version
gcloud functions deploy FUNCTION_NAME --source=PREVIOUS_SOURCE

# Or redeploy previous code from Git
git checkout PREVIOUS_COMMIT -- functions/
firebase deploy --only functions
```

## Cost Monitoring

### Estimate Costs

- **Scheduled function**: Runs 48 times/day (every 30 minutes)
- **Execution time**: ~5-10 seconds per run
- **Memory**: 256 MB (default)
- **Networking**: Minimal (OneDrive download + Firebase writes)

**Estimated monthly cost**: $0 - $5 (within Firebase free tier)

Free tier includes:
- 2M invocations/month
- 400,000 GB-seconds
- 200,000 CPU-seconds
- 5GB network egress

### Monitor Usage

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select taquotes project
3. Navigate to **Billing** → **Reports**
4. Filter by **Cloud Functions**

Set up budget alerts:
```bash
# Create budget alert at $10
gcloud billing budgets create --billing-account=YOUR_BILLING_ACCOUNT \
  --display-name="Cloud Functions Budget" \
  --budget-amount=10USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90
```

## Next Steps

After successful deployment:

1. **Monitor first few runs**
   - Check logs every 30 minutes for first 2 hours
   - Verify data is being imported correctly
   - Watch for any errors or warnings

2. **Set up alerts**
   - Email notifications working correctly
   - Cloud monitoring alerts for failures
   - Budget alerts configured

3. **Document imported data structure**
   - Review data in `/tracking` node
   - Document field names and types
   - Create data access functions for Flutter app

4. **Integrate with Flutter app**
   - Create Dart service to read tracking data
   - Display tracking info in app UI
   - Add search and filter functionality

5. **Regular maintenance**
   - Check import logs weekly
   - Rotate Microsoft client secret before expiry
   - Update dependencies monthly
   - Review and optimize based on usage

## Support and Resources

- **Firebase Documentation**: https://firebase.google.com/docs/functions
- **Microsoft Graph API**: https://docs.microsoft.com/en-us/graph/
- **Firebase Console**: https://console.firebase.google.com/project/taquotes
- **Cloud Scheduler**: https://cloud.google.com/scheduler/docs

For issues:
1. Check function logs: `firebase functions:log`
2. Review import logs in database
3. Contact: andres@turboairmexico.com

---

**Deployment Status**: Ready for production
**Last Updated**: October 1, 2025
**Version**: 1.0.0
