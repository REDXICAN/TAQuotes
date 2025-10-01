# Environment Variables Configuration Guide

This guide explains how to configure environment variables for the OneDrive Excel import Cloud Function.

## Required Environment Variables

You need to configure the following environment variables:

### Microsoft Graph API Credentials

```bash
MICROSOFT_TENANT_ID=your-tenant-id-here
MICROSOFT_CLIENT_ID=your-client-id-here
MICROSOFT_CLIENT_SECRET=your-client-secret-here
```

### OneDrive Configuration

```bash
ONEDRIVE_SHARE_LINK=https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default
```

### Email Configuration (Already Configured)

```bash
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=your-email-app-password
```

## Configuration Methods

Firebase Cloud Functions support two methods for environment variables:

### Method 1: Local .env File (Development)

**Best for**: Local testing and emulator

1. Navigate to the `functions/` directory:
   ```bash
   cd functions/
   ```

2. Create or edit the `.env` file:
   ```bash
   # Copy from example
   cp .env.example .env

   # Or create new file
   nano .env
   ```

3. Add your environment variables:
   ```bash
   # Microsoft Graph API
   MICROSOFT_TENANT_ID=common
   MICROSOFT_CLIENT_ID=12345678-1234-1234-1234-123456789abc
   MICROSOFT_CLIENT_SECRET=abc123xyz789~secretvalue

   # OneDrive
   ONEDRIVE_SHARE_LINK=https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default

   # Email (if not already set)
   EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
   EMAIL_APP_PASSWORD=your-16-char-app-password
   ```

4. **IMPORTANT**: Make sure `.env` is in `.gitignore`:
   ```bash
   # Check if .env is ignored
   git check-ignore .env

   # If not, add it
   echo ".env" >> .gitignore
   ```

### Method 2: Firebase Environment Config (Production)

**Best for**: Deployed Cloud Functions (recommended for production)

#### Option A: Using Firebase CLI (Recommended)

Set individual variables:
```bash
# Navigate to project root
cd "c:\Users\andre\Desktop\-- Flutter App"

# Set Microsoft Graph API credentials
firebase functions:config:set microsoft.tenant_id="your-tenant-id"
firebase functions:config:set microsoft.client_id="your-client-id"
firebase functions:config:set microsoft.client_secret="your-client-secret"

# Set OneDrive share link
firebase functions:config:set onedrive.share_link="https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default"

# View current config (to verify)
firebase functions:config:get
```

#### Option B: Set All at Once

```bash
firebase functions:config:set \
  microsoft.tenant_id="your-tenant-id" \
  microsoft.client_id="your-client-id" \
  microsoft.client_secret="your-client-secret" \
  onedrive.share_link="https://onedrive.live.com/..."
```

#### View Current Configuration

```bash
# View all configuration
firebase functions:config:get

# View specific config
firebase functions:config:get microsoft
firebase functions:config:get onedrive
```

#### Update Configuration

```bash
# Update a single value
firebase functions:config:set microsoft.client_secret="new-secret-value"

# Unset a value
firebase functions:config:unset microsoft.client_secret
```

### Method 3: Google Cloud Secret Manager (Advanced)

**Best for**: Enhanced security in production

1. Enable Secret Manager API:
   ```bash
   gcloud services enable secretmanager.googleapis.com
   ```

2. Create secrets:
   ```bash
   echo -n "your-tenant-id" | gcloud secrets create microsoft-tenant-id --data-file=-
   echo -n "your-client-id" | gcloud secrets create microsoft-client-id --data-file=-
   echo -n "your-client-secret" | gcloud secrets create microsoft-client-secret --data-file=-
   ```

3. Grant access to Cloud Functions:
   ```bash
   gcloud secrets add-iam-policy-binding microsoft-tenant-id \
     --member=serviceAccount:your-project@appspot.gserviceaccount.com \
     --role=roles/secretmanager.secretAccessor
   ```

4. Update your `index.js` to use Secret Manager (optional enhancement).

## Getting Your Credentials

### Microsoft Tenant ID

For **work/school accounts**:
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to Azure Active Directory → Overview
3. Copy the **Directory (tenant) ID**

For **personal Microsoft accounts**:
- Use: `common` or `consumers`
- Example: `common`

### Microsoft Client ID & Secret

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to Azure Active Directory → App registrations
3. Select your application (TurboAir OneDrive Integration)
4. **Client ID**: Found on Overview page as "Application (client) ID"
5. **Client Secret**:
   - Go to Certificates & secrets
   - Create new client secret
   - Copy the **Value** (not the Secret ID)

### OneDrive Share Link

1. Open [OneDrive](https://onedrive.live.com)
2. Navigate to your Excel file
3. Right-click → Share → Copy link
4. Ensure sharing settings: "Anyone with the link can view"
5. Copy the full URL

The link format:
```
https://onedrive.live.com/personal/{user}/_layouts/15/Doc.aspx?sourcedoc={file-id}&action=default
```

## Example .env File

Create `functions/.env`:

```bash
# ===========================================
# ONEDRIVE EXCEL IMPORT - ENVIRONMENT VARIABLES
# ===========================================
# IMPORTANT: Never commit this file to Git!
# ===========================================

# Microsoft Graph API Credentials
# Get these from Azure Portal: https://portal.azure.com
MICROSOFT_TENANT_ID=common
MICROSOFT_CLIENT_ID=12345678-1234-1234-1234-123456789abc
MICROSOFT_CLIENT_SECRET=abc123~secretvalue789

# OneDrive File Configuration
# Get this from OneDrive share link
ONEDRIVE_SHARE_LINK=https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default

# Email Service (Already Configured)
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=abcd efgh ijkl mnop

# Optional: Initialization Token for Admin Setup
INIT_TOKEN=TAQUOTES_INIT_2024
```

## Verifying Configuration

### Local Environment (Emulator)

1. Start Firebase emulator:
   ```bash
   cd "c:\Users\andre\Desktop\-- Flutter App"
   firebase emulators:start --only functions
   ```

2. Test the function:
   ```bash
   # Using curl (Windows)
   curl -X POST http://localhost:5001/taquotes/us-central1/triggerOneDriveImport ^
     -H "Content-Type: application/json" ^
     -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
   ```

### Production Environment

1. Deploy functions:
   ```bash
   firebase deploy --only functions
   ```

2. View logs:
   ```bash
   firebase functions:log

   # Or stream logs
   firebase functions:log --only scheduledOneDriveImport
   ```

3. Check function URL:
   ```bash
   firebase functions:list
   ```

## Security Checklist

- [ ] `.env` file is in `.gitignore`
- [ ] No secrets committed to Git repository
- [ ] Firebase config set for production
- [ ] Client secret expiration date noted (rotate before expiry)
- [ ] OneDrive file has appropriate sharing permissions
- [ ] Email alerts configured for import failures
- [ ] Only admin users can trigger manual imports
- [ ] Cloud Functions have proper IAM roles

## Updating Environment Variables

### For Local Development

1. Edit `functions/.env`
2. Restart emulator:
   ```bash
   # Stop emulator (Ctrl+C)
   # Start again
   firebase emulators:start --only functions
   ```

### For Production

1. Update Firebase config:
   ```bash
   firebase functions:config:set microsoft.client_secret="new-secret"
   ```

2. Redeploy functions:
   ```bash
   firebase deploy --only functions
   ```

   **Note**: Functions automatically reload with new config after deployment.

## Troubleshooting

### "Missing Microsoft Graph API credentials"

**Problem**: Environment variables not loaded

**Solution**:
1. Check `.env` file exists in `functions/` directory
2. For production, verify Firebase config:
   ```bash
   firebase functions:config:get
   ```
3. Ensure no typos in variable names

### "Failed to authenticate with Microsoft Graph API"

**Problem**: Invalid credentials or expired secret

**Solution**:
1. Verify credentials in Azure Portal
2. Check client secret hasn't expired
3. Create new client secret if needed
4. Update environment variables

### "OneDrive share link not configured"

**Problem**: Share link not set or invalid

**Solution**:
1. Verify share link format
2. Check file is still shared
3. Test link in browser (should download file)
4. Update environment variable with correct link

### Environment variables not updating

**Problem**: Changes not reflected after deployment

**Solution**:
1. For Firebase config, redeploy after setting:
   ```bash
   firebase functions:config:set key="value"
   firebase deploy --only functions
   ```
2. For `.env` changes, restart emulator
3. Clear Node.js cache if needed:
   ```bash
   cd functions
   rm -rf node_modules
   npm install
   ```

## Next Steps

After configuring environment variables:

1. Test locally with Firebase emulator
2. Deploy to production
3. Monitor first scheduled run (every 30 minutes)
4. Check import logs in Firebase Console

See `DEPLOYMENT_GUIDE.md` for deployment instructions.

## Additional Resources

- [Firebase Environment Configuration](https://firebase.google.com/docs/functions/config-env)
- [Google Cloud Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Azure AD Application Secrets](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-configure-app-access-web-apis)
