#!/bin/bash

# OneDrive Excel Import - Quick Setup Script
# This script helps you set up the OneDrive import Cloud Function

set -e

echo "=========================================="
echo "OneDrive Excel Import - Quick Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the functions directory
if [ ! -f "package.json" ]; then
  echo -e "${RED}Error: Must run from functions/ directory${NC}"
  echo "cd functions/"
  exit 1
fi

echo "Step 1: Install dependencies"
echo "----------------------------------------"
echo "Installing axios and xlsx packages..."
npm install axios@^1.6.0 xlsx@^0.18.5 --save
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

echo "Step 2: Environment variables setup"
echo "----------------------------------------"
if [ ! -f ".env" ]; then
  echo "Creating .env file from template..."
  cp .env.example .env
  echo -e "${YELLOW}⚠ Please edit .env file with your credentials${NC}"
  echo ""
  echo "You need to configure:"
  echo "  - MICROSOFT_TENANT_ID"
  echo "  - MICROSOFT_CLIENT_ID"
  echo "  - MICROSOFT_CLIENT_SECRET"
  echo "  - ONEDRIVE_SHARE_LINK"
  echo ""
  echo "See MICROSOFT_GRAPH_SETUP.md for instructions"
  echo ""
  read -p "Press Enter after editing .env file..."
else
  echo -e "${GREEN}✓ .env file already exists${NC}"
fi
echo ""

echo "Step 3: Verify .gitignore"
echo "----------------------------------------"
if grep -q "^\.env$" .gitignore 2>/dev/null; then
  echo -e "${GREEN}✓ .env is in .gitignore${NC}"
else
  echo "Adding .env to .gitignore..."
  echo ".env" >> .gitignore
  echo -e "${GREEN}✓ Added .env to .gitignore${NC}"
fi
echo ""

echo "Step 4: Check Firebase configuration"
echo "----------------------------------------"
cd ..
if command -v firebase &> /dev/null; then
  echo "Checking Firebase config..."
  firebase functions:config:get > /dev/null 2>&1 && echo -e "${GREEN}✓ Firebase CLI is working${NC}" || echo -e "${YELLOW}⚠ Not logged in to Firebase${NC}"
else
  echo -e "${RED}✗ Firebase CLI not installed${NC}"
  echo "Install with: npm install -g firebase-tools"
fi
cd functions
echo ""

echo "Step 5: Test local setup"
echo "----------------------------------------"
echo "Testing if all required variables are set..."

if [ -f ".env" ]; then
  source .env

  missing_vars=0

  if [ -z "$MICROSOFT_TENANT_ID" ]; then
    echo -e "${RED}✗ MICROSOFT_TENANT_ID not set${NC}"
    missing_vars=1
  else
    echo -e "${GREEN}✓ MICROSOFT_TENANT_ID set${NC}"
  fi

  if [ -z "$MICROSOFT_CLIENT_ID" ]; then
    echo -e "${RED}✗ MICROSOFT_CLIENT_ID not set${NC}"
    missing_vars=1
  else
    echo -e "${GREEN}✓ MICROSOFT_CLIENT_ID set${NC}"
  fi

  if [ -z "$MICROSOFT_CLIENT_SECRET" ]; then
    echo -e "${RED}✗ MICROSOFT_CLIENT_SECRET not set${NC}"
    missing_vars=1
  else
    echo -e "${GREEN}✓ MICROSOFT_CLIENT_SECRET set${NC}"
  fi

  if [ -z "$ONEDRIVE_SHARE_LINK" ]; then
    echo -e "${RED}✗ ONEDRIVE_SHARE_LINK not set${NC}"
    missing_vars=1
  else
    echo -e "${GREEN}✓ ONEDRIVE_SHARE_LINK set${NC}"
  fi

  if [ $missing_vars -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}⚠ Please configure missing variables in .env${NC}"
    echo "See ENVIRONMENT_SETUP.md for details"
    exit 1
  fi
else
  echo -e "${RED}✗ .env file not found${NC}"
  exit 1
fi
echo ""

echo "=========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Set up Microsoft Graph API (if not done):"
echo "   See: MICROSOFT_GRAPH_SETUP.md"
echo ""
echo "2. Configure Firebase environment variables:"
echo "   cd .."
echo "   firebase functions:config:set microsoft.tenant_id=\"\$MICROSOFT_TENANT_ID\""
echo "   firebase functions:config:set microsoft.client_id=\"\$MICROSOFT_CLIENT_ID\""
echo "   firebase functions:config:set microsoft.client_secret=\"\$MICROSOFT_CLIENT_SECRET\""
echo "   firebase functions:config:set onedrive.share_link=\"\$ONEDRIVE_SHARE_LINK\""
echo ""
echo "3. Test locally:"
echo "   firebase emulators:start --only functions"
echo ""
echo "4. Deploy to production:"
echo "   firebase deploy --only functions"
echo ""
echo "5. Monitor first runs:"
echo "   firebase functions:log --only scheduledOneDriveImport"
echo ""
echo "See DEPLOYMENT_GUIDE.md for detailed instructions"
echo ""
