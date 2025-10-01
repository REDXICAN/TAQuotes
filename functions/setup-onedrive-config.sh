#!/bin/bash

# OneDrive Auto-Sync Configuration Setup Script
# This script helps configure the Microsoft Graph API credentials for automatic OneDrive sync

echo "=========================================="
echo "OneDrive Auto-Sync Configuration Setup"
echo "=========================================="
echo ""
echo "This script will help you configure the Microsoft Graph API credentials"
echo "for automatic OneDrive Excel file synchronization."
echo ""
echo "You'll need the following information from Azure Portal:"
echo "1. Tenant ID (use 'common' for personal accounts)"
echo "2. Client ID (Application ID from your app registration)"
echo "3. Client Secret (from Certificates & secrets section)"
echo "4. OneDrive Share Link (the link to your Excel file)"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Set default values
DEFAULT_TENANT_ID="common"
DEFAULT_SHARE_LINK="https://onedrive.live.com/personal/537ba0d7826179ca/_layouts/15/Doc.aspx?sourcedoc=%7B826179ca-a0d7-207b-8053-2e6a00000000%7D&action=default"

# Get Tenant ID
echo ""
echo "Enter Microsoft Tenant ID (press Enter for default: '$DEFAULT_TENANT_ID'):"
read TENANT_ID
TENANT_ID=${TENANT_ID:-$DEFAULT_TENANT_ID}

# Get Client ID
echo ""
echo "Enter Microsoft Client ID (Application ID from Azure AD):"
read CLIENT_ID
if [ -z "$CLIENT_ID" ]; then
    echo "Error: Client ID is required. Please register an app in Azure AD first."
    echo "See functions/MICROSOFT_GRAPH_SETUP.md for instructions."
    exit 1
fi

# Get Client Secret
echo ""
echo "Enter Microsoft Client Secret (value, not ID):"
read -s CLIENT_SECRET
echo ""
if [ -z "$CLIENT_SECRET" ]; then
    echo "Error: Client Secret is required. Please create one in Azure AD."
    echo "See functions/MICROSOFT_GRAPH_SETUP.md for instructions."
    exit 1
fi

# Get OneDrive Share Link
echo ""
echo "Enter OneDrive Share Link (press Enter for default):"
echo "Default: $DEFAULT_SHARE_LINK"
read SHARE_LINK
SHARE_LINK=${SHARE_LINK:-$DEFAULT_SHARE_LINK}

# Set Firebase Functions configuration
echo ""
echo "Setting Firebase Functions configuration..."
echo ""

firebase functions:config:set \
    microsoft.tenant_id="$TENANT_ID" \
    microsoft.client_id="$CLIENT_ID" \
    microsoft.client_secret="$CLIENT_SECRET" \
    onedrive.share_link="$SHARE_LINK"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Configuration set successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Install dependencies: cd functions && npm install"
    echo "2. Deploy functions: firebase deploy --only functions"
    echo "3. Monitor logs: firebase functions:log --only scheduledOneDriveImport"
    echo ""
    echo "The automatic sync will run every 30 minutes."
    echo "You can also trigger manual sync from the Admin Panel."
else
    echo ""
    echo "✗ Failed to set configuration. Please check your Firebase login."
fi