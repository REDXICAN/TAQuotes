# 💻 Windows PC Deployment Guide - TurboAir Quotes App

## 🚀 Quick Start - Portable Windows App

### Build Portable Windows App
```bash
# Build Windows release version
flutter build windows --release
```

### Application Location
After building, your Windows app will be located at:
```
build\windows\x64\runner\Release\
```

The complete portable app folder contains:
- `turbo_air_quotes.exe` - Main executable
- `data\` folder - App resources and Flutter assets
- `*.dll` files - Required Windows libraries

## 📦 Creating Portable Distribution

### Method 1: ZIP Archive (Recommended)
1. Navigate to the release folder:
   ```
   cd build\windows\x64\runner\Release\
   ```

2. Create a ZIP file containing all files:
   - Select all files and folders
   - Right-click → Send to → Compressed (zipped) folder
   - Name it: `TurboAirQuotes_Portable_v1.0.0.zip`

3. **Distribution size**: ~30-40 MB compressed

### Method 2: Self-Extracting Archive
Use 7-Zip or WinRAR to create a self-extracting executable:
1. Install 7-Zip
2. Select all files in Release folder
3. Right-click → 7-Zip → Add to archive
4. Archive format: 7z
5. Check "Create SFX archive"
6. Result: `TurboAirQuotes_Setup.exe`

## 🖥️ System Requirements

### Minimum Requirements:
- **OS**: Windows 10 version 1709 or higher (64-bit)
- **RAM**: 4 GB minimum, 8 GB recommended
- **Storage**: 200 MB free space
- **Display**: 1280x720 minimum resolution
- **Internet**: Required for initial login and sync

### Supported Windows Versions:
- ✅ Windows 10 (1709+)
- ✅ Windows 11
- ✅ Windows Server 2019+

## 📂 Portable App Structure

```
TurboAirQuotes_Portable/
├── turbo_air_quotes.exe          # Main executable
├── data/
│   ├── flutter_assets/           # App resources
│   │   ├── assets/               # Images, fonts
│   │   ├── packages/             # Package assets
│   │   └── fonts/                # Custom fonts
│   └── app.so                    # Flutter engine
├── flutter_windows.dll            # Flutter framework
├── msvcp140.dll                  # Visual C++ runtime
├── vcruntime140.dll              # Visual C++ runtime
├── vcruntime140_1.dll            # Visual C++ runtime
└── [other required DLLs]
```

## 🚀 Installation Instructions

### For End Users:

#### Portable Installation (No Admin Rights):
1. **Download** the ZIP file
2. **Extract** to any folder (e.g., Desktop, Documents, USB drive)
3. **Run** `turbo_air_quotes.exe`
4. **Create shortcut** (optional):
   - Right-click `turbo_air_quotes.exe`
   - Send to → Desktop (create shortcut)

#### USB Drive Installation:
1. Extract to USB drive root or any folder
2. Run directly from USB
3. All data stored locally on USB
4. Fully portable between PCs

### First Launch:
1. **Windows Defender** may scan the app (first time only)
2. If "Windows protected your PC" appears:
   - Click "More info"
   - Click "Run anyway"
3. **Login** with credentials
4. App will download product catalog (one-time)

## 🔧 Configuration

### App Data Location:
The app stores data in:
```
%APPDATA%\com.turboair\quotes\
```

For truly portable setup, data is stored in:
```
[App Directory]\data\.hive\
```

### Reset App Data:
1. Close the app
2. Delete folder: `%APPDATA%\com.turboair\quotes\`
3. Restart app

## 🌐 Offline Functionality

### Full Offline Features:
- ✅ Browse all 48 products
- ✅ Create and edit quotes
- ✅ Manage clients
- ✅ Shopping cart
- ✅ Generate PDFs
- ✅ View quote history

### Requires Internet:
- ❌ Initial login
- ❌ Sending emails
- ❌ Syncing with cloud
- ❌ Product updates

## 🛡️ Windows Security

### Digital Signature:
The app is not digitally signed (costs $200+/year). Users may see security warnings.

### Bypass Security Warnings:
1. **Windows Defender SmartScreen**:
   - Click "More info"
   - Click "Run anyway"

2. **Antivirus Software**:
   - Add exception for `turbo_air_quotes.exe`
   - Whitelist the app folder

### Corporate Environments:
IT departments should:
1. Whitelist the application
2. Add to approved software list
3. Deploy via Group Policy or SCCM

## 📊 Performance Optimization

### Recommended Settings:
- **RAM Usage**: App uses ~200-400 MB
- **CPU**: Minimal usage (<5% on modern CPUs)
- **GPU**: Hardware acceleration enabled
- **Network**: Caches data for offline use

### Troubleshooting Performance:
1. **Slow startup**: First launch downloads data
2. **High memory**: Clear cache in app settings
3. **Rendering issues**: Update graphics drivers

## 🔄 Updating the App

### Manual Update Process:
1. Download new version ZIP
2. Extract to new folder
3. Copy old data (optional):
   ```
   %APPDATA%\com.turboair\quotes\
   ```
4. Run new version
5. Delete old version

### Preserve User Data:
User data is stored separately and persists across updates.

## 🎯 Deployment Options

### 1. Direct Distribution (Simplest):
- Share ZIP file via:
  - Email
  - Google Drive
  - OneDrive
  - USB drive
  - Network share

### 2. Inno Setup Installer:
Create professional installer:
```iss
[Setup]
AppName=TurboAir Quotes
AppVersion=1.0.0
DefaultDirName={pf}\TurboAir Quotes
DefaultGroupName=TurboAir
OutputBaseFilename=TurboAirQuotes_Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\TurboAir Quotes"; Filename: "{app}\turbo_air_quotes.exe"
Name: "{commondesktop}\TurboAir Quotes"; Filename: "{app}\turbo_air_quotes.exe"
```

### 3. Microsoft Store (Future):
Requirements:
- MSIX package
- Developer account ($19 one-time)
- Code signing certificate

## 🐛 Troubleshooting

### App Won't Start:
1. **Check Windows version**: Must be Windows 10+
2. **Install Visual C++ Redistributables**:
   ```
   https://aka.ms/vs/17/release/vc_redist.x64.exe
   ```
3. **Run as administrator** (if needed)

### Black/White Screen:
1. Update graphics drivers
2. Disable hardware acceleration:
   - Add `--disable-gpu` to shortcut target

### Connection Issues:
1. Check firewall settings
2. Allow app through Windows Firewall
3. Check proxy settings

### Login Problems:
1. Verify internet connection
2. Check Firebase status
3. Confirm credentials

## 📝 Command Line Options

Run with options:
```bash
# Verbose logging
turbo_air_quotes.exe --verbose

# Specific window size
turbo_air_quotes.exe --window-size=1920,1080

# Disable GPU acceleration
turbo_air_quotes.exe --disable-gpu
```

## 🔍 Logs and Debugging

### Log Location:
```
%APPDATA%\com.turboair\quotes\logs\
```

### Enable Debug Mode:
1. Create file: `debug.txt` in app folder
2. Restart app
3. Check logs for detailed output

## ✅ Features Checklist

### Desktop-Specific Features:
- [x] Keyboard shortcuts (Ctrl+S to save, etc.)
- [x] Multi-window support
- [x] Drag and drop file upload
- [x] System tray integration (minimize)
- [x] Local file access for exports
- [x] Print directly to printer
- [x] Full screen mode (F11)

### Cross-Platform Features:
- [x] Responsive design
- [x] Touch and mouse support
- [x] Offline functionality
- [x] Auto-sync when online
- [x] PDF generation
- [x] Excel import/export

## 🚢 Distribution Checklist

Before distributing:
- [ ] Build in release mode
- [ ] Test on clean Windows 10/11
- [ ] Verify offline functionality
- [ ] Check all DLLs included
- [ ] Create ZIP archive
- [ ] Test extraction and run
- [ ] Document version number
- [ ] Include README.txt

## 📦 Sample README.txt for Users

```text
TurboAir Quotes - Portable Windows Application
Version 1.0.0

INSTALLATION:
1. Extract all files to a folder
2. Run turbo_air_quotes.exe
3. Login with your credentials

REQUIREMENTS:
- Windows 10 or higher
- 4 GB RAM minimum
- 200 MB free space

SUPPORT:
Email: andres@turboairmexico.com
```

## 🎁 Quick Distribution Package

Create a folder with:
```
TurboAirQuotes_Portable_v1.0.0/
├── turbo_air_quotes.exe
├── [all DLL files]
├── data/ (folder)
├── README.txt
└── CHANGELOG.txt
```

Compress to ZIP and share!

---

**Note**: The Windows app is fully portable and requires no installation. Simply extract and run from any location including USB drives, network shares, or local folders.