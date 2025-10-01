# Microsoft Graph API Setup Guide for OneDrive Integration

This guide walks you through setting up Microsoft Graph API authentication to access OneDrive files programmatically.

## Prerequisites

- Microsoft account (personal or work/school account)
- OneDrive file that you want to access
- Admin access to create Azure AD applications (for work/school accounts) or Microsoft account developer access

## Setup Steps

### 1. Register an Application in Azure AD

#### For Work/School Accounts:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **New registration**
4. Fill in the details:
   - **Name**: `TurboAir OneDrive Integration`
   - **Supported account types**: Select based on your needs:
     - Single tenant (your organization only)
     - Multi-tenant (any Azure AD directory)
     - Multi-tenant + personal accounts
   - **Redirect URI**: Leave empty for now (not needed for server-to-server)
5. Click **Register**

#### For Personal Microsoft Accounts:

1. Go to [Microsoft Application Registration Portal](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. Click **New registration**
3. Follow similar steps as above

### 2. Configure API Permissions

1. In your application page, go to **API permissions**
2. Click **Add a permission**
3. Select **Microsoft Graph**
4. Choose **Application permissions** (not Delegated permissions)
5. Add the following permissions:
   - `Files.Read.All` - Read files in all site collections
   - `Sites.Read.All` - Read items in all site collections (optional, for SharePoint)
6. Click **Add permissions**
7. **Important**: Click **Grant admin consent** (requires admin privileges)
   - This allows the application to access files without user interaction

### 3. Create a Client Secret

1. In your application page, go to **Certificates & secrets**
2. Click **New client secret**
3. Add a description: `OneDrive Import Secret`
4. Select expiration period:
   - Recommended: 24 months
   - For production: Consider shorter periods and rotation
5. Click **Add**
6. **IMPORTANT**: Copy the secret value immediately - you won't be able to see it again
7. Save it securely (you'll use this as `MICROSOFT_CLIENT_SECRET`)

### 4. Get Your Application Credentials

You need three values from your application:

1. **Tenant ID** (Directory ID):
   - Go to **Overview** page of your app
   - Copy the **Directory (tenant) ID**
   - For personal accounts, use: `common` or `consumers`

2. **Application (client) ID**:
   - Same **Overview** page
   - Copy the **Application (client) ID**

3. **Client Secret**:
   - The value you copied in Step 3

### 5. Configure File Sharing Permissions

For the OneDrive file you want to access:

#### Option A: Share Link (Recommended for this implementation)

1. Open OneDrive in your browser
2. Right-click on the Excel file
3. Select **Share** → **Copy link**
4. Choose sharing settings:
   - **Anyone with the link can view**
   - No sign-in required (optional, but easier for automation)
5. Copy the share link

The link will look like:
```
https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default
```

#### Option B: Direct File Path (Alternative)

If you have the file path in OneDrive:
```
/personal/your_email_com/Documents/tracking.xlsx
```

### 6. Test Your Setup

You can test your Microsoft Graph API credentials using this curl command:

```bash
# Get access token
curl -X POST "https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id={CLIENT_ID}" \
  -d "client_secret={CLIENT_SECRET}" \
  -d "scope=https://graph.microsoft.com/.default" \
  -d "grant_type=client_credentials"
```

Replace:
- `{TENANT_ID}` with your Tenant ID
- `{CLIENT_ID}` with your Application (client) ID
- `{CLIENT_SECRET}` with your Client Secret

If successful, you'll receive a response with an `access_token`.

### 7. Verify File Access

Test file access with the access token:

```bash
# Get file metadata using share link
curl -X GET "https://graph.microsoft.com/v1.0/shares/u!{BASE64_ENCODED_SHARE_LINK}/driveItem" \
  -H "Authorization: Bearer {ACCESS_TOKEN}"
```

Where `{BASE64_ENCODED_SHARE_LINK}` is your share link encoded in base64url format.

## Security Best Practices

1. **Never commit secrets to Git**
   - Always use environment variables
   - Add `.env` to `.gitignore`

2. **Rotate secrets regularly**
   - Create new client secrets before old ones expire
   - Update environment variables accordingly

3. **Use least privilege permissions**
   - Only grant necessary permissions
   - Use `Files.Read.All` instead of `Files.ReadWrite.All` if you only need to read

4. **Monitor API usage**
   - Check Azure AD logs regularly
   - Set up alerts for unusual activity

5. **Secure your Firebase Functions**
   - Use environment variables for all secrets
   - Enable Cloud Functions authentication
   - Restrict function access to admin users only

## Troubleshooting

### Error: "Application requires admin consent"
- Make sure you clicked "Grant admin consent" in API permissions
- You need Azure AD admin privileges to grant consent

### Error: "Invalid client secret"
- Check that you copied the secret value (not the secret ID)
- Verify the secret hasn't expired
- Create a new secret if needed

### Error: "Authorization_RequestDenied"
- Check that your application has the correct permissions
- Verify admin consent was granted
- Ensure the user/service principal has access to the file

### Error: "Resource not found"
- Verify the share link is correct
- Check that the file hasn't been deleted or moved
- Ensure the file is shared with "Anyone with the link"

## Next Steps

After completing this setup:

1. Copy your credentials to the Firebase Functions environment variables
2. Configure the `.env` file in the `functions/` directory
3. Deploy the Cloud Functions
4. Test the scheduled import

See `ENVIRONMENT_SETUP.md` for environment variable configuration.
See `DEPLOYMENT_GUIDE.md` for deployment instructions.

## Additional Resources

- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/)
- [Azure AD App Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Microsoft Graph API Permissions](https://docs.microsoft.com/en-us/graph/permissions-reference)
- [OneDrive API Documentation](https://docs.microsoft.com/en-us/graph/api/resources/onedrive)
