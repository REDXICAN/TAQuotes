@echo off
title Google Cloud SDK Installation and CORS Fix
color 0A

echo ==========================================
echo   Google Cloud SDK Installation
echo ==========================================
echo.

:: Check if gcloud is installed
where gcloud >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Google Cloud SDK is already installed!
    echo.
    goto :APPLY_CORS
)

echo Google Cloud SDK not found. Installing...
echo.

:: Download the installer
echo Downloading Google Cloud SDK installer...
set "INSTALLER_URL=https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe"
set "INSTALLER_PATH=%TEMP%\GoogleCloudSDKInstaller.exe"

powershell -Command "Invoke-WebRequest -Uri '%INSTALLER_URL%' -OutFile '%INSTALLER_PATH%'"

if not exist "%INSTALLER_PATH%" (
    echo ERROR: Failed to download installer!
    echo.
    echo Please download manually from:
    echo https://cloud.google.com/sdk/docs/install
    echo.
    pause
    exit /b 1
)

echo.
echo Starting installer...
echo Please complete the installation wizard.
echo.
start /wait "" "%INSTALLER_PATH%"

echo.
echo Installation completed!
echo.

:APPLY_CORS
echo ==========================================
echo   Applying CORS Configuration
echo ==========================================
echo.

:: Refresh PATH to find gcloud
set PATH=%PATH%;%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin

:: Check again if gcloud is available
where gcloud >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: gcloud still not found!
    echo Please restart this script after installation.
    pause
    exit /b 1
)

echo Step 1: Authenticating with Google Cloud
echo ----------------------------------------
echo A browser window will open. Please sign in with your Google account.
echo.
pause

call gcloud auth login

echo.
echo Step 2: Setting project to 'taquotes'
echo ----------------------------------------
call gcloud config set project taquotes

echo.
echo Step 3: Applying CORS configuration
echo ----------------------------------------

:: Create cors.json if it doesn't exist
if not exist cors.json (
    echo Creating cors.json file...
    (
        echo [
        echo   {
        echo     "origin": ["https://taquotes.web.app", "https://taquotes.firebaseapp.com", "http://localhost:*"],
        echo     "method": ["GET", "HEAD", "OPTIONS", "PUT", "POST"],
        echo     "responseHeader": ["*"],
        echo     "maxAgeSeconds": 3600
        echo   }
        echo ]
    ) > cors.json
)

echo.
echo Applying CORS to Firebase Storage bucket...
call gsutil cors set cors.json gs://taquotes.firebasestorage.app

echo.
echo Step 4: Verifying CORS configuration
echo ----------------------------------------
call gsutil cors get gs://taquotes.firebasestorage.app

echo.
echo ==========================================
echo   CORS Configuration Complete!
echo ==========================================
echo.
echo IMPORTANT: Next steps
echo ----------------------
echo 1. Wait 5-10 minutes for changes to propagate
echo 2. Clear your browser cache (Ctrl+Shift+Delete)
echo 3. Hard refresh the web app (Ctrl+Shift+R)
echo 4. Images should now load without CORS errors
echo.
echo If you still see CORS errors after 10 minutes:
echo - Try opening the app in an incognito/private window
echo - Check the browser console for any new error messages
echo.
pause