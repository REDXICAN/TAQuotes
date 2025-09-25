# Flutter Dependencies Installation Script
# Installs Android Studio, Google Chrome, and Visual Studio for Flutter development
# Run as Administrator

Write-Host "Flutter Dependencies Installation Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Function to check if a program is installed
function Test-ProgramInstalled {
    param($programName)

    $installed = $false

    # Check common installation paths
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $paths) {
        if (Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$programName*" }) {
            $installed = $true
            break
        }
    }

    return $installed
}

# Install Chocolatey if not installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "`nInstalling Chocolatey package manager..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "`nChecking and installing Flutter dependencies..." -ForegroundColor Green

# Install Google Chrome
if (Test-ProgramInstalled "Google Chrome") {
    Write-Host "`nGoogle Chrome is already installed" -ForegroundColor Green
} else {
    Write-Host "`nInstalling Google Chrome..." -ForegroundColor Yellow
    try {
        choco install googlechrome -y --force
        Write-Host "Google Chrome installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Google Chrome: $_" -ForegroundColor Red
    }
}

# Install Android Studio
if (Test-ProgramInstalled "Android Studio") {
    Write-Host "`nAndroid Studio is already installed" -ForegroundColor Green
} else {
    Write-Host "`nInstalling Android Studio..." -ForegroundColor Yellow
    Write-Host "This may take several minutes..." -ForegroundColor Yellow
    try {
        choco install androidstudio -y --force
        Write-Host "Android Studio installed successfully" -ForegroundColor Green

        # Set ANDROID_HOME environment variable
        $androidPath = "${env:LOCALAPPDATA}\Android\Sdk"
        [System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidPath, [System.EnvironmentVariableTarget]::User)
        [System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $androidPath, [System.EnvironmentVariableTarget]::User)

        # Add Android tools to PATH
        $pathValue = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        $androidPaths = @(
            "$androidPath\platform-tools",
            "$androidPath\tools",
            "$androidPath\tools\bin",
            "$androidPath\emulator"
        )

        foreach ($path in $androidPaths) {
            if ($pathValue -notlike "*$path*") {
                $pathValue = "$pathValue;$path"
            }
        }

        [System.Environment]::SetEnvironmentVariable("Path", $pathValue, [System.EnvironmentVariableTarget]::User)
        Write-Host "Android environment variables configured" -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Android Studio: $_" -ForegroundColor Red
    }
}

# Install Visual Studio 2022 Community with required workloads for Flutter
if (Test-ProgramInstalled "Visual Studio") {
    Write-Host "`nVisual Studio is already installed" -ForegroundColor Green
} else {
    Write-Host "`nInstalling Visual Studio 2022 Community..." -ForegroundColor Yellow
    Write-Host "This will take a while (10-30 minutes)..." -ForegroundColor Yellow

    try {
        # Download VS installer
        $vsInstallerUrl = "https://aka.ms/vs/17/release/vs_community.exe"
        $vsInstallerPath = "$env:TEMP\vs_community.exe"

        Write-Host "Downloading Visual Studio installer..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $vsInstallerUrl -OutFile $vsInstallerPath

        # Install with Desktop development with C++ workload (required for Flutter Windows)
        Write-Host "Installing Visual Studio with C++ development tools..." -ForegroundColor Yellow
        Start-Process -FilePath $vsInstallerPath -ArgumentList `
            "--quiet", `
            "--wait", `
            "--add", "Microsoft.VisualStudio.Workload.NativeDesktop", `
            "--add", "Microsoft.VisualStudio.Component.Windows10SDK.19041", `
            "--includeRecommended" `
            -Wait -NoNewWindow

        Write-Host "Visual Studio 2022 installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Visual Studio: $_" -ForegroundColor Red
        Write-Host "You can manually download from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Installation process completed!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Restart your terminal/IDE to refresh environment variables" -ForegroundColor White
Write-Host "2. Open Android Studio and complete the setup wizard" -ForegroundColor White
Write-Host "3. In Android Studio, install Android SDK Command-line Tools:" -ForegroundColor White
Write-Host "   - Go to Tools > SDK Manager" -ForegroundColor Gray
Write-Host "   - SDK Tools tab > Check Android SDK Command-line Tools" -ForegroundColor Gray
Write-Host "4. Run 'flutter doctor --android-licenses' to accept licenses" -ForegroundColor White
Write-Host "5. Run 'flutter doctor' to verify all installations" -ForegroundColor White

# Refresh environment for current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")