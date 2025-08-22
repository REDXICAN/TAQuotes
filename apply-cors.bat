@echo off
echo ==========================================
echo Firebase Storage CORS Configuration Script
echo ==========================================
echo.

REM Check if gcloud is installed
where gcloud >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Google Cloud SDK not found!
    echo.
    echo Please install it from: https://cloud.google.com/sdk/docs/install
    echo.
    echo After installation, run this script again.
    pause
    exit /b 1
)

echo Google Cloud SDK found!
echo.

echo Authenticating with Google Cloud...
call gcloud auth login

echo.
echo Setting project to 'taquotes'...
call gcloud config set project taquotes

echo.
echo Applying CORS configuration to Firebase Storage...
call gsutil cors set cors.json gs://taquotes.firebasestorage.app

echo.
echo Verifying CORS configuration...
call gsutil cors get gs://taquotes.firebasestorage.app

echo.
echo ==========================================
echo CORS configuration applied successfully!
echo Please wait 5-10 minutes for changes to propagate.
echo Clear your browser cache (Ctrl+Shift+Delete) and try again.
echo ==========================================
pause