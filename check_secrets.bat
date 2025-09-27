@echo off
REM Pre-commit security check script for Windows
REM Prevents accidental commit of secrets and credentials

echo Running security checks...

REM Check for API keys and Firebase config
git diff --cached | findstr /R "apiKey AIzaSy authDomain projectId messagingSenderId appId measurementId" >nul
if %ERRORLEVEL% EQU 0 (
    echo ERROR: Firebase configuration detected in staged files!
    echo Remove Firebase config and use environment variables instead.
    exit /b 1
)

REM Check for email addresses and passwords
git diff --cached | findstr /R "@gmail\.com @turboairmexico\.com password PASSWORD EMAIL_APP_PASSWORD" >nul
if %ERRORLEVEL% EQU 0 (
    echo ERROR: Email addresses or passwords detected in staged files!
    echo Remove credentials and use environment variables instead.
    exit /b 1
)

REM Check for forbidden file patterns
for /f "delims=" %%i in ('git diff --cached --name-only ^| findstr /R "populate_stock firebase_config setup_admin firebase_import"') do (
    echo ERROR: Forbidden file detected: %%i
    echo These files often contain secrets and should not be committed.
    exit /b 1
)

REM Check HTML files
for /f "delims=" %%i in ('git diff --cached --name-only ^| findstr /R "\.html$"') do (
    findstr /R "firebase apiKey authDomain" "%%i" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo ERROR: HTML file with potential Firebase config: %%i
        echo HTML files with Firebase config should never be committed.
        exit /b 1
    )
)

echo Security checks passed!
exit /b 0