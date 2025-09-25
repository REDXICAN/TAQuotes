# Setup Guide for New Development Computer
## Turbo Air Quotes (TAQ) - Flutter App

### 📋 Prerequisites
1. **Flutter SDK** (3.0+)
   ```bash
   # Download from https://flutter.dev/docs/get-started/install
   flutter --version  # Should be 3.0+
   ```

2. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

3. **Git**
   ```bash
   git --version
   ```

4. **VS Code or Android Studio**
   - Install Flutter and Dart extensions

### 🚀 Quick Setup Steps

#### 1. Clone Repository
```bash
git clone https://github.com/REDXICAN/TAQuotes.git
cd TAQuotes
```

#### 2. Create .env File (CRITICAL)
Create `.env` file in project root with these exact contents:
```env
# Admin Credentials
ADMIN_EMAIL=andres@turboairmexico.com
ADMIN_PASSWORD=andres123!@#

# Firebase Configuration
FIREBASE_PROJECT_ID=taquotes
FIREBASE_DATABASE_URL=https://taquotes-default-rtdb.firebaseio.com
FIREBASE_API_KEY_WEB=AIzaSyD7yqogFRdCD7i8zDZhLU5TtNNetKWpnQw
FIREBASE_API_KEY_ANDROID=AIzaSyBGeAvfO35-KL0r1UhfzykfGtNeeuK5dyY
FIREBASE_API_KEY_IOS=AIzaSyAVCBIzycrcpYxPTqRkSegLrrfqYO8xF5A
FIREBASE_API_KEY_WINDOWS=AIzaSyD7yqogFRdCD7i8zDZhLU5TtNNetKWpnQw
FIREBASE_AUTH_DOMAIN=taquotes.firebaseapp.com
FIREBASE_STORAGE_BUCKET=taquotes.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=1016639818898
FIREBASE_APP_ID_WEB=1:1016639818898:web:82356e945f9355a8196a4b
FIREBASE_APP_ID_ANDROID=1:988318636738:android:e00dc1a1f5dc009f8e3a5f
FIREBASE_APP_ID_IOS=1:988318636738:ios:a5a4f18fc3f17dff8e3a5f
FIREBASE_APP_ID_WINDOWS=1:1016639818898:web:82356e945f9355a8196a4b
FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXXX

# Email Service Configuration
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=pttm demo tqxl eiop
EMAIL_SENDER_NAME=TurboAir Quote System

# Security Configuration
CSRF_SECRET_KEY=SoTmXkBAQ1tJLZxNmzz5lzH1Kl4Zaj6BPRyanlrQbBrFt1EoHU6NK6XXl9kPL6ZX
EMAIL_APP_URL=https://taquotes.web.app

# SMTP Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
```

#### 3. Install Dependencies
```bash
flutter pub get
```

#### 4. Run the App
```bash
# Web (recommended for development)
flutter run -d chrome --web-port=5000

# Android
flutter run -d android

# iOS (Mac only)
flutter run -d ios
```

### 🔧 Firebase Configuration

#### Connect to Firebase Project
```bash
firebase use taquotes
```

#### Verify Firebase Connection
```bash
firebase projects:list
# Should show: taquotes (current)
```

### 📁 Important Files to Check

1. **.gitignore** - Ensure these are listed:
   ```
   .env
   .env.*
   firebase_options.dart
   ```

2. **pubspec.yaml** - Version should be: `1.0.0+1`

3. **database.rules.json** - Security rules for Firebase

### 🛠️ Common Issues & Solutions

#### Issue: Can't login
- Check .env file exists with correct credentials
- Verify internet connection
- Check Firebase Auth is enabled

#### Issue: Products not loading
- Verify Firebase Database URL in .env
- Check authentication (must be logged in)
- 835+ products should be in database

#### Issue: Email not sending
- Verify EMAIL_APP_PASSWORD in .env
- Must be Gmail App-Specific Password
- Check Gmail security settings

#### Issue: Images not loading
- Images are hosted on Firebase Storage
- Check FIREBASE_STORAGE_BUCKET in .env
- Fallback to local assets if Firebase fails

### 🔐 Security Notes

1. **NEVER commit .env file** - It's gitignored
2. **Session timeout** - 30 minutes of inactivity
3. **Rate limiting** - Applied to all endpoints
4. **CSRF protection** - Enabled by default

### 📱 Platform-Specific Setup

#### Web
```bash
flutter config --enable-web
flutter build web --release --web-renderer html
```

#### Android
- Minimum SDK: 21
- Target SDK: 33
- Enable multidex if needed

#### iOS
- Minimum iOS: 11.0
- Run `pod install` in ios folder

#### Windows
```bash
flutter config --enable-windows-desktop
flutter build windows --release
```

### 🚦 Verification Steps

After setup, verify everything works:

1. **Login**: Use credentials from .env
2. **Products**: Should see 835+ products
3. **Cart**: Add items, check calculations
4. **Quotes**: Create and save quotes
5. **Email**: Send quote with PDF
6. **Offline**: Works without internet

### 📞 Support Contacts

- **Lead Developer**: andres@turboairmexico.com
- **GitHub Issues**: https://github.com/REDXICAN/TAQuotes/issues
- **Live App**: https://taquotes.web.app

### ⚠️ Critical Reminders

1. **Production URL**: https://taquotes.web.app
2. **835 products** must remain in database
3. **Don't break** existing functionality
4. **Test everything** before pushing
5. **Session timeout** is 30 minutes

---
Last Updated: January 24, 2025
Version: 1.0.0