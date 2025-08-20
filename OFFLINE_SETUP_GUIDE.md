# 📱 Offline Setup Guide for Android & iOS

## Overview
The TurboAir Quotes app is designed to work offline using Firebase Realtime Database persistence and Hive local storage. This guide explains how to build and run the app offline on Android and iOS devices.

## 🔧 Prerequisites

### For Android:
- Android Studio installed
- Android device or emulator (API level 21+)
- USB debugging enabled on physical device

### For iOS:
- Mac with Xcode installed
- iOS device or simulator (iOS 12.0+)
- Apple Developer account (for physical devices)
- CocoaPods installed

## 🚀 Quick Start Commands

### Android
```bash
# Build and install on connected device
flutter run -d android

# Build APK for distribution
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release

# Install APK on device
flutter install
```

### iOS
```bash
# Install pods (required first time)
cd ios && pod install && cd ..

# Run on iOS device/simulator
flutter run -d ios

# Build for iOS (archive)
flutter build ios --release

# Build IPA for distribution
flutter build ipa --release
```

## 📲 Android Setup

### 1. Enable Offline Persistence
The app already has Firebase offline persistence enabled in `lib/core/services/realtime_database_service.dart`:
```dart
FirebaseDatabase.instance.setPersistenceEnabled(true);
FirebaseDatabase.instance.setPersistenceCacheSizeBytes(100 * 1024 * 1024); // 100MB
```

### 2. Build APK for Testing
```bash
# Debug APK (larger size, includes debugging info)
flutter build apk --debug

# Release APK (optimized, smaller size)
flutter build apk --release

# Split APKs by ABI (smaller downloads)
flutter build apk --split-per-abi --release
```

The APK files will be in:
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

### 3. Install on Android Device

#### Option A: Using Flutter
```bash
# Make sure device is connected
flutter devices

# Install and run
flutter run -d android --release
```

#### Option B: Using ADB
```bash
# Check connected devices
adb devices

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### Option C: Manual Installation
1. Copy APK to device via USB/Google Drive/Email
2. Enable "Install from Unknown Sources" in Settings
3. Open APK file on device to install

### 4. Test Offline Mode
1. Launch the app while online to sync initial data
2. Login with credentials
3. Browse products and create quotes (data will be cached)
4. Enable Airplane Mode
5. Continue using the app - all features work offline
6. Create/edit quotes while offline
7. Disable Airplane Mode - changes sync automatically

## 🍎 iOS Setup

### 1. Configure iOS Project
```bash
# Navigate to iOS folder
cd ios

# Install/update pods
pod install
pod update

# Return to project root
cd ..
```

### 2. Open in Xcode (Optional)
```bash
open ios/Runner.xcworkspace
```

In Xcode:
- Select your development team
- Choose your device/simulator
- Update bundle identifier if needed

### 3. Build for iOS

#### For Simulator:
```bash
# List available simulators
flutter devices

# Run on specific simulator
flutter run -d "iPhone 15 Pro"
```

#### For Physical Device:
1. Connect iPhone via USB
2. Trust the computer on your iPhone
3. Run:
```bash
# Check device is recognized
flutter devices

# Run on device
flutter run -d ios --release
```

### 4. Build IPA for Distribution
```bash
# Build iOS archive
flutter build ios --release

# Build IPA file
flutter build ipa --release

# Or with export options
flutter build ipa --export-options-plist=ios/ExportOptions.plist
```

The IPA will be in: `build/ios/ipa/`

### 5. Install IPA on Device

#### Option A: Using Xcode
1. Open Xcode > Window > Devices and Simulators
2. Select your device
3. Drag IPA file to the device

#### Option B: Using Apple Configurator 2
1. Download from Mac App Store
2. Connect device
3. Add IPA through the app

#### Option C: TestFlight (Recommended for Testing)
1. Upload to App Store Connect
2. Invite testers via TestFlight
3. Install from TestFlight app

## 🔄 Offline Sync Behavior

### Data Caching
The app caches the following data locally:
- **Products catalog** - Full product list with images
- **Clients** - Customer information
- **Quotes** - Draft and sent quotes
- **Cart items** - Shopping cart persists across sessions
- **User profile** - Authentication state

### Sync Queue
When offline, the app queues operations:
```
CREATE → UPDATE → DELETE operations stored in order
↓
When online, operations replay automatically
↓
Conflicts resolved by timestamp (last write wins)
```

### Offline Capabilities
✅ **Can Do Offline:**
- Browse all products
- Search and filter products
- Create new quotes
- Edit existing quotes
- Add/edit clients
- Manage cart items
- View quote history
- Generate PDFs locally

❌ **Requires Internet:**
- Login/authentication
- Sending emails
- Initial product sync
- Uploading to cloud

## 🧪 Testing Offline Mode

### Android Testing Steps:
1. Install app: `flutter run -d android`
2. Login and let data sync
3. Create a test quote
4. Enable Airplane Mode
5. Create another quote offline
6. Edit a client offline
7. Add items to cart
8. Disable Airplane Mode
9. Verify all changes synced

### iOS Testing Steps:
1. Install app: `flutter run -d ios`
2. Login with credentials
3. Browse products (they'll cache)
4. Turn on Airplane Mode in Settings
5. Create/edit quotes
6. Turn off Airplane Mode
7. Check Firebase Console for synced data

## 📱 Performance Tips

### Android Optimization:
```bash
# Build with optimization flags
flutter build apk --release --shrink --obfuscate

# For larger apps, use app bundles
flutter build appbundle --release
```

### iOS Optimization:
```bash
# Build with bitcode for smaller size
flutter build ios --release

# Archive for App Store
flutter build ipa --release
```

## 🛠️ Troubleshooting

### Android Issues:

**"App not installed" error:**
- Uninstall previous version
- Check minimum SDK version in `android/app/build.gradle`
- Ensure sufficient storage space

**Offline data not persisting:**
- Check permissions in AndroidManifest.xml
- Verify Firebase configuration
- Clear app data and reconfigure

### iOS Issues:

**"Unable to install" error:**
- Check provisioning profiles
- Verify bundle identifier
- Trust developer certificate on device

**Offline sync not working:**
- Check Background App Refresh is enabled
- Verify Firebase configuration
- Check network permissions in Info.plist

## 📝 Build Configuration

### Android (`android/app/build.gradle`):
```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        multiDexEnabled true
    }
}
```

### iOS (`ios/Runner/Info.plist`):
```xml
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>armv7</string>
</array>
<key>MinimumOSVersion</key>
<string>12.0</string>
```

## 🚢 Distribution

### Android Distribution:
1. **Google Play Store:**
   ```bash
   flutter build appbundle --release
   ```
   Upload `.aab` file to Play Console

2. **Direct APK:**
   ```bash
   flutter build apk --release
   ```
   Share APK file directly

3. **Firebase App Distribution:**
   - Use Firebase CLI to distribute test builds

### iOS Distribution:
1. **App Store:**
   ```bash
   flutter build ipa --release
   ```
   Upload via Xcode or Transporter

2. **TestFlight:**
   - Upload to App Store Connect
   - Distribute to beta testers

3. **Ad Hoc:**
   - Requires provisioning profiles
   - Limited to registered devices

## 📞 Support

For issues with offline functionality:
1. Check Firebase Console for sync status
2. Review logs: `flutter logs`
3. Clear cache: Settings > Apps > TurboAir > Clear Cache
4. Reinstall app if persistent issues

## ✅ Verification Checklist

- [ ] Firebase offline persistence enabled
- [ ] Hive boxes initialized
- [ ] Network permissions configured
- [ ] Minimum SDK/iOS versions met
- [ ] Offline queue service running
- [ ] Local storage permissions granted
- [ ] Background sync configured
- [ ] Conflict resolution working
- [ ] Cache size limits set
- [ ] Error handling for offline scenarios

---

**Note:** The app is designed to work seamlessly offline. Initial login requires internet to authenticate and download the product catalog. After that, all features work offline with automatic sync when connection is restored.