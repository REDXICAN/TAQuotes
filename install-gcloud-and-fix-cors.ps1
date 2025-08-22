# PowerShell script to install Google Cloud SDK and fix CORS
# Run PowerShell as Administrator before executing this script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Google Cloud SDK Installation & CORS Fix" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Function to test if running as admin
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if running as administrator
if (-not (Test-Admin)) {
    Write-Host "❌ This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if gcloud is already installed
$gcloudPath = Get-Command gcloud -ErrorAction SilentlyContinue

if ($gcloudPath) {
    Write-Host "✅ Google Cloud SDK is already installed!" -ForegroundColor Green
    Write-Host "Location: $($gcloudPath.Source)" -ForegroundColor Gray
    $install = Read-Host "`nDo you want to reinstall? (y/n)"
    if ($install -ne 'y') {
        Write-Host "`nSkipping installation..." -ForegroundColor Yellow
    }
} else {
    Write-Host "📦 Google Cloud SDK not found. Installing now..." -ForegroundColor Yellow
    
    # Download the installer
    $installerUrl = "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe"
    $installerPath = "$env:TEMP\GoogleCloudSDKInstaller.exe"
    
    Write-Host "`nDownloading Google Cloud SDK installer..." -ForegroundColor Cyan
    Write-Host "URL: $installerUrl" -ForegroundColor Gray
    
    try {
        # Download with progress bar
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        Write-Host "✅ Download completed!" -ForegroundColor Green
        
        # Run the installer
        Write-Host "`nStarting installer..." -ForegroundColor Cyan
        Write-Host "Please follow the installation wizard:" -ForegroundColor Yellow
        Write-Host "  1. Click 'Next' on welcome screen" -ForegroundColor Gray
        Write-Host "  2. Accept the license agreement" -ForegroundColor Gray
        Write-Host "  3. Choose installation location (default is fine)" -ForegroundColor Gray
        Write-Host "  4. Select components (keep defaults)" -ForegroundColor Gray
        Write-Host "  5. Click 'Install'" -ForegroundColor Gray
        Write-Host "  6. Wait for installation to complete" -ForegroundColor Gray
        Write-Host "  7. Click 'Finish'" -ForegroundColor Gray
        
        Start-Process -FilePath $installerPath -Wait
        
        Write-Host "`n✅ Installation completed!" -ForegroundColor Green
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
    } catch {
        Write-Host "❌ Error downloading installer: $_" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Step 2: Configuring Google Cloud" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Initialize gcloud
Write-Host "Initializing Google Cloud SDK..." -ForegroundColor Yellow
Write-Host "This will open a browser window for authentication." -ForegroundColor Gray
Write-Host "Please log in with your Google account that has access to the Firebase project.`n" -ForegroundColor Gray

Read-Host "Press Enter to continue with authentication"

# Run gcloud init
Start-Process -FilePath "cmd" -ArgumentList "/k", "gcloud init" -Wait

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Step 3: Applying CORS Configuration" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Navigate to project directory
$projectPath = "C:\Users\andre\Desktop\-- Flutter App"
if (Test-Path $projectPath) {
    Set-Location $projectPath
    Write-Host "✅ Navigated to project directory" -ForegroundColor Green
} else {
    Write-Host "❌ Project directory not found: $projectPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if cors.json exists
if (-not (Test-Path "cors.json")) {
    Write-Host "Creating cors.json file..." -ForegroundColor Yellow
    
    $corsContent = @'
[
  {
    "origin": [
      "https://taquotes.web.app",
      "https://taquotes.firebaseapp.com",
      "http://localhost:3000",
      "http://localhost:5000",
      "http://localhost:5001",
      "http://localhost:8080",
      "http://localhost:8081"
    ],
    "method": ["GET", "HEAD", "OPTIONS", "PUT", "POST"],
    "responseHeader": ["*"],
    "maxAgeSeconds": 3600
  }
]
'@
    
    $corsContent | Out-File -FilePath "cors.json" -Encoding UTF8
    Write-Host "✅ cors.json created" -ForegroundColor Green
} else {
    Write-Host "✅ cors.json found" -ForegroundColor Green
}

Write-Host "`nApplying CORS configuration to Firebase Storage..." -ForegroundColor Yellow
Write-Host "This will allow your web app to access images from Firebase Storage.`n" -ForegroundColor Gray

# Open new command prompt to run gsutil
$commands = @"
@echo off
echo.
echo Applying CORS configuration...
echo.
gcloud config set project taquotes
gsutil cors set cors.json gs://taquotes.firebasestorage.app
echo.
echo Verifying CORS configuration...
gsutil cors get gs://taquotes.firebasestorage.app
echo.
echo ========================================
echo CORS configuration has been applied!
echo.
echo Please wait 5-10 minutes for changes to propagate.
echo Then clear your browser cache (Ctrl+Shift+Delete).
echo ========================================
pause
"@

$batchPath = "$env:TEMP\apply-cors-temp.bat"
$commands | Out-File -FilePath $batchPath -Encoding ASCII

Write-Host "Opening command prompt to apply CORS..." -ForegroundColor Cyan
Start-Process -FilePath "cmd" -ArgumentList "/k", $batchPath

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Installation & Configuration Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Wait 5-10 minutes for CORS to propagate" -ForegroundColor White
Write-Host "  2. Clear browser cache (Ctrl+Shift+Delete)" -ForegroundColor White
Write-Host "  3. Hard refresh the web app (Ctrl+Shift+R)" -ForegroundColor White
Write-Host "  4. Images should now load without CORS errors`n" -ForegroundColor White

Read-Host "Press Enter to exit"