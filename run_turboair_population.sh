#!/bin/bash

echo "====================================="
echo "TurboAir Sales Data Population Script"
echo "====================================="
echo

echo "Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed or not in PATH"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

echo "Node.js found: $(node --version)"

echo
echo "Checking dependencies..."
if [ ! -d "node_modules/firebase-admin" ]; then
    echo "Installing dependencies..."
    npm install
fi

echo
echo "Testing Firebase connection..."
if ! node test_firebase_connection.js; then
    echo
    echo "====================================="
    echo "FIREBASE AUTHENTICATION SETUP NEEDED"
    echo "====================================="
    echo
    echo "The Firebase connection test failed. You need to set up authentication."
    echo
    echo "OPTION 1 - Service Account Key (Recommended):"
    echo "1. Go to https://console.firebase.google.com/project/taquotes"
    echo "2. Project Settings > Service Accounts"
    echo "3. Click 'Generate New Private Key'"
    echo "4. Save the downloaded file as 'firebase-admin-key.json' in this folder"
    echo "5. Run this script again"
    echo
    echo "OPTION 2 - Google Cloud SDK:"
    echo "1. Install Google Cloud SDK"
    echo "2. Run: gcloud auth application-default login"
    echo "3. Run this script again"
    echo
    exit 1
fi

echo
echo "====================================="
echo "READY TO POPULATE TURBOAIR DATA"
echo "====================================="
echo
echo "This will create:"
echo "- 10 Mexican sales representatives"
echo "- ~40 realistic clients (hotels, restaurants)"
echo "- ~250 quotes with TurboAir products"
echo "- ~40 major installation projects"
echo "- Realistic 3-month sales history"
echo

read -p "Are you sure you want to proceed? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo
echo "Starting population process..."
echo "This may take 2-3 minutes..."
echo

if node populate_turboair_data.js; then
    echo
    echo "====================================="
    echo "POPULATION COMPLETED SUCCESSFULLY!"
    echo "====================================="
    echo
    echo "You can now:"
    echo "1. Visit https://taquotes.web.app to see the data"
    echo "2. Login with: andres@turboairmexico.com"
    echo "3. Check the admin dashboard for sales metrics"
    echo "4. Review quotes, clients, and projects"
    echo
    echo "The data includes realistic Mexican sales scenarios"
    echo "with proper TurboAir products and pricing."
    echo
else
    echo
    echo "Population failed. Check the error messages above."
    exit 1
fi