# 📱 Android Deployment Guide - TurboAir Quotes App

## 🚀 Quick Start (Build & Install APK)

### Step 1: Build the APK
```bash
# Build release APK (recommended for production)
flutter build apk --release

# Or build split APKs for smaller size
flutter build apk --split-per-abi --release
```

### Step 2: Find Your APK
After building, your APK will be located at:
- **Release APK**: `build\app\outputs\flutter-apk\app-release.apk`
- **Split APKs**: 
  - `app-armeabi-v7a-release.apk` (32-bit devices)
  - `app-arm64-v8a-release.apk` (64-bit devices)
  - `app-x86_64-release.apk` (emulators)

## 📲 Installation Methods

### Method 1: Direct USB Installation (Recommended)
1. **Connect your Android device** via USB cable
2. **Enable Developer Options** on your phone:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings → Developer Options
   - Enable "USB Debugging"
3. **Install the app**:
   ```bash
   flutter install
   ```
   Or manually:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

### Method 2: Transfer APK File
1. **Copy the APK** to your phone via:
   - USB cable (copy to Downloads folder)
   - Google Drive
   - Email attachment
   - WhatsApp (send to yourself)

2. **On your Android device**:
   - Open File Manager
   - Navigate to the APK file
   - Tap on it to install
   - If prompted, enable "Install from Unknown Sources":
     - Settings → Security → Unknown Sources (Enable)
     - Or Settings → Apps → Special Access → Install Unknown Apps

### Method 3: Using QR Code (Quick Share)
1. Upload APK to a file sharing service (Google Drive, Dropbox)
2. Generate a QR code for the download link
3. Scan QR code with phone to download and install

## 🔧 Prerequisites Check

### Required on Development Machine:
```bash
# Check Flutter installation
flutter doctor

# Check Android setup specifically
flutter doctor -v
```

### Fix Common Issues:
```bash
# Accept Android licenses
flutter doctor --android-licenses

# Update Flutter
flutter upgrade

# Clean and rebuild if having issues
flutter clean
flutter pub get
flutter build apk --release
```

## 📱 Running on Physical Device

### Connect & Run Directly:
```bash
# 1. List connected devices
flutter devices

# 2. Run on specific device
flutter run -d <device-id>

# 3. Run release mode (faster, no debug banner)
flutter run --release
```

### Enable Developer Mode on Android:
1. **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. Go back → **Developer Options**
4. Enable:
   - ✅ USB Debugging
   - ✅ Install via USB
   - ✅ USB Debugging (Security Settings)

## 🎯 Features Available Offline

Once installed, the app works offline with these features:

### ✅ Full Offline Capabilities:
- **Browse Products** - All 835 products with images cached
- **Create Quotes** - Build quotes without internet
- **Manage Clients** - Add/edit client information
- **Shopping Cart** - Items persist across sessions
- **Generate PDFs** - Create quote PDFs locally
- **View History** - Access previous quotes

### ⚠️ Requires Internet:
- Initial login (first time only)
- Sending emails with attachments
- Syncing data with cloud
- Downloading product updates

## 🔐 First Time Setup

### 1. Launch the App
After installation, open "TurboAir Quotes" from your app drawer

### 2. Login Credentials
Use your assigned credentials:
```
Email: andres@turboairmexico.com
Password: [Your secure password]
```

### 3. Initial Data Sync
- **Connect to WiFi** for first login
- App will download product catalog (835 products)
- Takes about 30 seconds
- After sync, app works fully offline

### 4. Test Offline Mode
1. Create a test quote while online
2. Turn on **Airplane Mode**
3. Continue using all features
4. Turn off Airplane Mode - changes sync automatically

## 📊 App Permissions

The app will request these permissions:

| Permission | Purpose | Required |
|------------|---------|----------|
| **Internet** | Sync data, send emails | Yes |
| **Storage** | Cache products, save quotes | Yes |
| **Network State** | Detect offline/online | Yes |

## 🎨 App Information

- **App Name**: TurboAir Quotes (TAQ)
- **Package**: com.turboair.quotes
- **Version**: 1.0.0
- **Size**: ~25MB (APK) + ~50MB (cached data)
- **Min Android**: 5.0 (API 21)
- **Target**: Android 14 (API 34)

## 🚦 Troubleshooting

### "App Not Installed" Error:
1. **Uninstall previous version** if exists
2. **Check storage space** (need 100MB free)
3. **Enable Unknown Sources** in settings
4. Try split APK for your architecture

### Black/White Screen on Launch:
1. **Clear app cache**: Settings → Apps → TurboAir → Clear Cache
2. **Force stop and restart** the app
3. **Reinstall** if issue persists

### Can't Login:
1. **Check internet connection** (required for first login)
2. **Verify credentials** are correct
3. **Check Firebase status**: https://status.firebase.google.com

### Data Not Syncing:
1. **Check internet connection**
2. **Login again** to refresh token
3. **Pull down to refresh** on main screen
4. Check **sync indicator** (top right)

## 🔄 Updating the App

### Option 1: Manual Update
1. Build new APK with higher version number
2. Install over existing app (data preserved)
```bash
flutter build apk --release --build-number=2
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Option 2: Google Play Store (Future)
Once published, updates will be automatic

## 📝 Build Variants

### Debug Build (Development):
```bash
flutter build apk --debug
# Includes debugging tools, larger size
# Shows debug banner
```

### Release Build (Production):
```bash
flutter build apk --release
# Optimized, smaller size
# No debug banner
# Ready for distribution
```

### Profile Build (Performance Testing):
```bash
flutter build apk --profile
# Performance profiling enabled
# Some debugging capability
```

## 🎁 Distribution Options

### 1. Direct APK Sharing
- Email the APK file
- Upload to Google Drive
- Share via WhatsApp/Telegram
- Use file transfer apps

### 2. Firebase App Distribution (Beta Testing)
```bash
# Install Firebase App Distribution plugin
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:1016639818898:android:xxxxx \
  --groups testers
```

### 3. Google Play Store (Production)
1. Build App Bundle:
   ```bash
   flutter build appbundle --release
   ```
2. Upload to Play Console
3. Complete store listing
4. Submit for review

## 🔍 Verify Installation

After installation, verify the app is working:

1. **Open the app** from app drawer
2. **Login** with credentials
3. **Check products load** (48 items)
4. **Create a test quote**
5. **Test offline mode** (Airplane mode)
6. **Send test email** with quote

## 📞 Support

If you encounter issues:

1. **Check this guide** for solutions
2. **Email**: andres@turboairmexico.com
3. **App Logs**: 
   ```bash
   adb logcat | grep flutter
   ```

## ✅ Deployment Checklist

Before distributing the APK:

- [ ] Built in release mode
- [ ] Tested on physical device
- [ ] Verified offline functionality
- [ ] Checked email sending works
- [ ] Confirmed products load (48 items)
- [ ] Tested quote creation/editing
- [ ] Verified PDF generation
- [ ] Checked data syncing
- [ ] Removed test data
- [ ] Updated version number

## 🎯 Quick Commands Reference

```bash
# Build APK
flutter build apk --release

# Install on connected device
flutter install

# Run on device
flutter run --release

# Check connected devices
flutter devices

# View logs
adb logcat | grep flutter

# Uninstall app
adb uninstall com.turboair.quotes

# Clear app data
adb shell pm clear com.turboair.quotes
```

---

**Note**: The app is fully functional offline after initial setup. Internet is only required for first login and sending emails. All other features work without connection.