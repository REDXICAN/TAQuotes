# PowerShell script to apply CORS to Firebase Storage
# Run this script as Administrator

Write-Host "Firebase Storage CORS Configuration Script" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Check if gcloud is installed
$gcloudInstalled = Get-Command gcloud -ErrorAction SilentlyContinue

if (-not $gcloudInstalled) {
    Write-Host "`nGoogle Cloud SDK not found. Installing..." -ForegroundColor Yellow
    
    # Download and install Google Cloud SDK
    $installerUrl = "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe"
    $installerPath = "$env:TEMP\GoogleCloudSDKInstaller.exe"
    
    Write-Host "Downloading Google Cloud SDK..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    
    Write-Host "Running installer (follow the prompts)..." -ForegroundColor Yellow
    Start-Process -FilePath $installerPath -Wait
    
    Write-Host "`nPlease restart PowerShell after installation completes and run this script again." -ForegroundColor Yellow
    exit
}

Write-Host "`nGoogle Cloud SDK found!" -ForegroundColor Green

# Authenticate
Write-Host "`nAuthenticating with Google Cloud..." -ForegroundColor Yellow
gcloud auth login

# Set project
Write-Host "`nSetting project to 'taquotes'..." -ForegroundColor Yellow
gcloud config set project taquotes

# Apply CORS configuration
Write-Host "`nApplying CORS configuration to Firebase Storage..." -ForegroundColor Yellow
gsutil cors set cors.json gs://taquotes.firebasestorage.app

# Verify CORS was applied
Write-Host "`nVerifying CORS configuration..." -ForegroundColor Yellow
gsutil cors get gs://taquotes.firebasestorage.app

Write-Host "`n✅ CORS configuration applied successfully!" -ForegroundColor Green
Write-Host "Please wait 5-10 minutes for changes to propagate." -ForegroundColor Yellow
Write-Host "Clear your browser cache (Ctrl+Shift+Delete) and try again." -ForegroundColor Yellow