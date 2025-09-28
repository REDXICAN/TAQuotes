@echo off
echo =====================================
echo TurboAir Sales Data Population Script
echo =====================================
echo.

echo Checking Node.js installation...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

echo Node.js found:
node --version

echo.
echo Checking dependencies...
if not exist "node_modules\firebase-admin" (
    echo Installing dependencies...
    npm install
)

echo.
echo Testing Firebase connection...
node test_firebase_connection.js

if errorlevel 1 (
    echo.
    echo =====================================
    echo FIREBASE AUTHENTICATION SETUP NEEDED
    echo =====================================
    echo.
    echo The Firebase connection test failed. You need to set up authentication.
    echo.
    echo OPTION 1 - Service Account Key (Recommended):
    echo 1. Go to https://console.firebase.google.com/project/taquotes
    echo 2. Project Settings ^> Service Accounts
    echo 3. Click "Generate New Private Key"
    echo 4. Save the downloaded file as "firebase-admin-key.json" in this folder
    echo 5. Run this script again
    echo.
    echo OPTION 2 - Google Cloud SDK:
    echo 1. Install Google Cloud SDK
    echo 2. Run: gcloud auth application-default login
    echo 3. Run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo =====================================
echo READY TO POPULATE TURBOAIR DATA
echo =====================================
echo.
echo This will create:
echo - 10 Mexican sales representatives
echo - ~40 realistic clients (hotels, restaurants)
echo - ~250 quotes with TurboAir products
echo - ~40 major installation projects
echo - Realistic 3-month sales history
echo.
set /p confirm="Are you sure you want to proceed? (y/N): "

if /i not "%confirm%"=="y" (
    echo Operation cancelled.
    pause
    exit /b 0
)

echo.
echo Starting population process...
echo This may take 2-3 minutes...
echo.

node populate_turboair_data.js

if errorlevel 1 (
    echo.
    echo Population failed. Check the error messages above.
    pause
    exit /b 1
)

echo.
echo =====================================
echo POPULATION COMPLETED SUCCESSFULLY!
echo =====================================
echo.
echo You can now:
echo 1. Visit https://taquotes.web.app to see the data
echo 2. Login with: andres@turboairmexico.com
echo 3. Check the admin dashboard for sales metrics
echo 4. Review quotes, clients, and projects
echo.
echo The data includes realistic Mexican sales scenarios
echo with proper TurboAir products and pricing.
echo.
pause