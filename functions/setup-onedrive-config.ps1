# OneDrive Auto-Sync Configuration Setup Script (PowerShell)
# This script helps configure the Microsoft Graph API credentials for automatic OneDrive sync

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OneDrive Auto-Sync Configuration Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will help you configure the Microsoft Graph API credentials"
Write-Host "for automatic OneDrive Excel file synchronization."
Write-Host ""
Write-Host "You'll need the following information from Azure Portal:" -ForegroundColor Yellow
Write-Host "1. Tenant ID (use 'common' for personal accounts)"
Write-Host "2. Client ID (Application ID from your app registration)"
Write-Host "3. Client Secret (from Certificates & secrets section)"
Write-Host "4. OneDrive Share Link (the link to your Excel file)"
Write-Host ""
Write-Host "Press Enter to continue or Ctrl+C to cancel..." -ForegroundColor Green
Read-Host

# Set default values
$DEFAULT_TENANT_ID = "common"
$DEFAULT_SHARE_LINK = "https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default"

# Get Tenant ID
Write-Host ""
Write-Host "Enter Microsoft Tenant ID (press Enter for default: '$DEFAULT_TENANT_ID'):" -ForegroundColor Cyan
$TENANT_ID = Read-Host
if ([string]::IsNullOrWhiteSpace($TENANT_ID)) {
    $TENANT_ID = $DEFAULT_TENANT_ID
}

# Get Client ID
Write-Host ""
Write-Host "Enter Microsoft Client ID (Application ID from Azure AD):" -ForegroundColor Cyan
$CLIENT_ID = Read-Host
if ([string]::IsNullOrWhiteSpace($CLIENT_ID)) {
    Write-Host "Error: Client ID is required. Please register an app in Azure AD first." -ForegroundColor Red
    Write-Host "See functions/MICROSOFT_GRAPH_SETUP.md for instructions." -ForegroundColor Yellow
    exit 1
}

# Get Client Secret
Write-Host ""
Write-Host "Enter Microsoft Client Secret (value, not ID):" -ForegroundColor Cyan
$CLIENT_SECRET = Read-Host -AsSecureString
$CLIENT_SECRET_TEXT = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($CLIENT_SECRET))
Write-Host ""
if ([string]::IsNullOrWhiteSpace($CLIENT_SECRET_TEXT)) {
    Write-Host "Error: Client Secret is required. Please create one in Azure AD." -ForegroundColor Red
    Write-Host "See functions/MICROSOFT_GRAPH_SETUP.md for instructions." -ForegroundColor Yellow
    exit 1
}

# Get OneDrive Share Link
Write-Host ""
Write-Host "Enter OneDrive Share Link (press Enter for default):" -ForegroundColor Cyan
Write-Host "Default: $DEFAULT_SHARE_LINK" -ForegroundColor Gray
$SHARE_LINK = Read-Host
if ([string]::IsNullOrWhiteSpace($SHARE_LINK)) {
    $SHARE_LINK = $DEFAULT_SHARE_LINK
}

# Set Firebase Functions configuration
Write-Host ""
Write-Host "Setting Firebase Functions configuration..." -ForegroundColor Yellow
Write-Host ""

$configCommand = @"
firebase functions:config:set microsoft.tenant_id="$TENANT_ID" microsoft.client_id="$CLIENT_ID" microsoft.client_secret="$CLIENT_SECRET_TEXT" onedrive.share_link="$SHARE_LINK"
"@

# Execute the command
Invoke-Expression $configCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Configuration set successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Install dependencies: cd functions && npm install"
    Write-Host "2. Deploy functions: firebase deploy --only functions"
    Write-Host "3. Monitor logs: firebase functions:log --only scheduledOneDriveImport"
    Write-Host ""
    Write-Host "The automatic sync will run every 30 minutes." -ForegroundColor Green
    Write-Host "You can also trigger manual sync from the Admin Panel." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "✗ Failed to set configuration. Please check your Firebase login." -ForegroundColor Red
}

# Clean up sensitive data
$CLIENT_SECRET_TEXT = $null
[System.GC]::Collect()