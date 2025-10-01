# 🚀 OneDrive Automatic Sync Setup Guide

## ✅ What's Already Completed

1. **Cloud Functions Deployed** ✅
   - `scheduledOneDriveImport` - Runs every 30 minutes automatically
   - `triggerOneDriveImport` - Manual trigger via HTTP
   - `getImportLogs` - View import history

2. **Firebase Configuration** ✅
   - Functions are live at: https://us-central1-taquotes.cloudfunctions.net/
   - Scheduled job configured for every 30 minutes

3. **Excel Parsing Ready** ✅
   - Will read your tracking spreadsheet from OneDrive
   - Automatically imports to `/tracking` node in Firebase

## 🔧 What You Need to Do Now

### Step 1: Set Up Microsoft Azure App Registration

1. **Go to Azure Portal**: https://portal.azure.com
   - Sign in with your Microsoft account (the one that has access to the OneDrive file)

2. **Register a New Application**:
   - Navigate to "Azure Active Directory" → "App registrations"
   - Click "New registration"
   - Name: "TAQuotes OneDrive Sync"
   - Account types: Choose based on your OneDrive type:
     - Personal OneDrive: "Accounts in any organizational directory and personal Microsoft accounts"
     - Work/School OneDrive: "Accounts in this organizational directory only"
   - Redirect URI: Leave blank (not needed for backend service)
   - Click "Register"

3. **Copy Your Application (Client) ID**:
   - On the Overview page, copy the "Application (client) ID"
   - Save this - you'll need it in Step 2

4. **Create a Client Secret**:
   - Go to "Certificates & secrets" in the left menu
   - Click "New client secret"
   - Description: "TAQuotes OneDrive Sync"
   - Expires: Choose "24 months" (you'll need to renew before expiration)
   - Click "Add"
   - **IMPORTANT**: Copy the secret VALUE immediately (not the Secret ID)
   - You won't be able to see it again!

5. **Set API Permissions**:
   - Go to "API permissions" in the left menu
   - Click "Add a permission"
   - Choose "Microsoft Graph"
   - Choose "Application permissions" (not Delegated)
   - Search and add these permissions:
     - `Files.Read.All` - To read files from OneDrive
     - `Sites.Read.All` - To access SharePoint if needed
   - Click "Grant admin consent" (if you're the admin)

6. **Get Your Tenant ID**:
   - For personal accounts: Use `common`
   - For work/school: Go to "Overview" → Copy "Directory (tenant) ID"

### Step 2: Configure Firebase Functions

Run this PowerShell script (I've created it for you):

```powershell
cd "c:\Users\andre\Desktop\-- Flutter App\functions"
.\setup-onedrive-config.ps1
```

When prompted, enter:
- **Tenant ID**: `common` (for personal OneDrive) or your tenant ID
- **Client ID**: The Application ID you copied in Step 1.3
- **Client Secret**: The secret VALUE you copied in Step 1.4
- **Share Link**: Press Enter to use the default (your tracking spreadsheet)

### Step 3: Verify Configuration

Check that the configuration was set correctly:

```bash
firebase functions:config:get
```

You should see:
```json
{
  "microsoft": {
    "tenant_id": "...",
    "client_id": "...",
    "client_secret": "..."
  },
  "onedrive": {
    "share_link": "..."
  }
}
```

### Step 4: Redeploy Functions with New Config

```bash
firebase deploy --only functions
```

This will update the functions with your Microsoft Graph credentials.

### Step 5: Test Manual Import

Test the manual import to verify everything works:

```bash
curl -X POST https://us-central1-taquotes.cloudfunctions.net/triggerOneDriveImport \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

Or use the Admin Panel in your web app to trigger a manual import.

### Step 6: Monitor Automatic Imports

View function logs to see the automatic imports every 30 minutes:

```bash
firebase functions:log --only scheduledOneDriveImport --follow
```

## 📊 How It Works

1. **Every 30 minutes**, the Cloud Scheduler triggers `scheduledOneDriveImport`
2. The function uses Microsoft Graph API to download your Excel file from OneDrive
3. It parses the Excel data and maps columns to tracking fields
4. Data is imported to Firebase under `/tracking` node
5. Your Flutter app displays the tracking data in real-time
6. Import logs are stored under `/import_logs` for monitoring

## 🔍 Troubleshooting

### Error: "Invalid client credentials"
- Double-check your Client ID and Client Secret
- Make sure you copied the secret VALUE, not the Secret ID
- Ensure the secret hasn't expired

### Error: "Insufficient permissions"
- Make sure you granted `Files.Read.All` permission
- Click "Grant admin consent" in Azure Portal
- Wait a few minutes for permissions to propagate

### Error: "File not found"
- Verify the OneDrive share link is correct
- Ensure the file is shared properly
- Check if the file still exists at that location

### Error: "Invalid tenant"
- Use `common` for personal Microsoft accounts
- Use your actual tenant ID for work/school accounts

## 📱 Access in Your App

The tracking data is now available in your Flutter app:
1. Go to the **Quotes & Tracking** screen
2. Click on the **Tracking** tab
3. Data auto-refreshes from Firebase in real-time
4. Search, filter, and view shipment details

## 🎉 Success Indicators

You'll know everything is working when:
- ✅ Manual import returns `{ success: true }`
- ✅ Function logs show successful imports every 30 minutes
- ✅ Data appears in Firebase under `/tracking`
- ✅ Tracking tab in your app shows shipment data
- ✅ No errors in `firebase functions:log`

## 📧 Support

If you encounter issues:
1. Check the function logs: `firebase functions:log`
2. Review the error messages carefully
3. Verify all credentials and permissions
4. The system will email alerts to andres@turboairmexico.com for critical errors

---

**Next Steps After Setup:**
1. Complete Azure AD registration (10 minutes)
2. Run the PowerShell configuration script (2 minutes)
3. Redeploy functions (3 minutes)
4. Test manual import (1 minute)
5. Monitor automatic imports

The system is already deployed and waiting for your Microsoft Graph credentials to start syncing!