# Turbo Air Quotes (TAQ) - Development Documentation

## 🚨 CRITICAL: NEVER HARDCODE CREDENTIALS
**VIOLATION COUNT: 5** - Use environment variables ONLY. No passwords, emails, or API keys in code.

## 🚀 Production Status: LIVE
- **URL**: https://taquotes.web.app
- **Users**: 500+ sales reps, 1000+ quotes/month
- **Products**: 835 in database (Firebase Storage for images)

## ⚠️ PRIMARY DIRECTIVE
**NEVER BREAK WORKING FEATURES** - App is LIVE. Read entire doc before modifications.

## 🔴 CRITICAL ISSUES (January 2025)

### Must Fix Immediately:
1. **Offline Service Broken on Web** - Primary platform has no offline functionality
2. **No RBAC System** - Only email checks, major security vulnerability
3. **Quote Menu Actions** - All show "coming soon" instead of working
4. **Bulk PDF Export** - Shows "not implemented" message
5. **Excel Import Backend** - Preview works but actual import missing
6. **Email Service Stub** - Non-web platforms always return false
7. **Stock Dashboard Mock Data** - Should use real Firebase data
8. **Debug Prints in Production** - Multiple files leak info to console
9. **Null Safety Issues** - stock_dashboard.dart has crash risks
10. **Empty Catch Blocks** - Silent failures hiding critical errors

## ✅ WORKING FEATURES - DO NOT MODIFY

### Protected Code Patterns:
```dart
// Cart Client Selection (cart_screen.dart:258) - WORKS PERFECTLY
return clientsAsync.when(
  data: (clients) => SearchableClientDropdown(...),
  loading: () => const LinearProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
);

// Cart Notifications - ALWAYS use SKU
SnackBar(content: Text('${product.sku ?? product.model ?? 'Item'} removed'))

// Static Services - DO NOT change to instance
OfflineService.staticMethod() // Keep static
CacheManager.staticInit() // Keep static
```

### Image System:
- Thumbnails: `assets/thumbnails/SKU/SKU.jpg`
- Screenshots: `assets/screenshots/SKU/SKU P.1.png`
- Firebase Storage: `taquotes.firebasestorage.app`
- 3,534 images migrated to cloud

## 📋 Feature Status

| Feature | Status | Issue |
|---------|--------|-------|
| **Core** | | |
| Products | ✅ | Working |
| Clients | ✅ | Working |
| Quotes | ⚠️ | Menu actions broken |
| Cart | ✅ | Working |
| **Admin** | | |
| Performance | ✅ | Working |
| Stock Dashboard | ⚠️ | Mock data only |
| User Analytics | ⚠️ | Shows mock to non-admins |
| **Export** | | |
| PDF Individual | ✅ | Working |
| PDF Bulk | ❌ | Not implemented |
| Excel Export | ✅ | Working |
| Excel Import | ⚠️ | Preview only, no import |
| **Email** | | |
| Web Email | ⚠️ | No attachments (free tier) |
| Mobile Email | ❌ | Stub returns false |
| **Offline** | | |
| Web Offline | ❌ | Broken - null instance |
| Mobile Offline | ⚠️ | Basic retry only |
| **Security** | | |
| Auth | ✅ | Working |
| RBAC | ❌ | Email checks only |
| Encryption | ✅ | In transit |
| Audit Logs | ⚠️ | Debug prints exist |

## 🛠️ Technical Stack
- Flutter 3.x / Firebase (Realtime DB, Auth, Storage)
- Riverpod / Hive / Mailer 6.0.1 / PDF Package
- Deployment: Firebase Hosting (web primary)

## 🔧 Quick Commands
```bash
flutter run -d chrome           # Development
flutter build web --release      # Production build
firebase deploy --only hosting   # Deploy to Firebase
dart fix --apply                 # Fix issues
```

## 📂 Key Files
```
lib/
├── core/services/
│   ├── offline_service.dart     # ❌ Broken on web
│   ├── email_service.dart       # ⚠️ Web only
│   └── emailjs_service_stub.dart # ❌ Returns false
├── features/
│   ├── quotes/quote_detail_screen.dart # ❌ Menu broken
│   ├── stock/stock_dashboard_screen.dart # ⚠️ Mock data
│   └── admin/user_info_dashboard.dart # ⚠️ Shows mock
└── assets/ → Firebase Storage (migrated)
```

## 🔐 Environment Variables (.env)
```
ADMIN_EMAIL=andres@turboairmexico.com
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=[from-env-only]
FIREBASE_DATABASE_URL=https://taquotes-default-rtdb.firebaseio.com
```

## 🚨 Database Safety Protocol
1. **ALWAYS backup first**: `firebase database:get "/" > backup.json`
2. **NEVER import at root (/)** - Will delete everything
3. **Specify exact path**: Import to `/products` NOT `/`
4. **Test with 5 items first**

## 📊 Priority Fix Order

### Week 1 - Critical Security & Functionality:
1. Implement RBAC system (replace email checks)
2. Fix offline service for web platform
3. Complete quote menu actions
4. Remove all debug prints

### Week 2 - Core Business Features:
5. Implement bulk PDF export
6. Complete Excel import backend
7. Fix email service for mobile
8. Connect real warehouse data

### Week 3 - Quality & Stability:
9. Fix null safety issues
10. Replace empty catch blocks
11. Standardize error handling
12. Add input validation

## 🎯 Development Rules

### NEVER DO:
- Delete database records (835 products)
- Change database field names
- Remove working features
- Modify static service patterns
- Create files unless necessary
- Add mock data (except spare parts)
- Hardcode credentials ANYWHERE

### ALWAYS DO:
- Read entire CLAUDE.md first
- Check git status before changes
- Preserve existing functionality
- Test critical paths
- Use environment variables
- Backup before database ops

## 📝 Recent Updates
- **Jan 2025**: Critical issues audit, CLAUDE.md synthesized
- **Dec 2025**: Backup system, export fixes, encoding fixes
- **Aug 2025**: Firebase Storage migration (3,534 images)

## 🆘 Support
- **Lead**: andres@turboairmexico.com
- **Support**: turboairquotes@gmail.com
- **GitHub**: https://github.com/REDXICAN/TAQuotes
- **Firebase Console**: https://console.firebase.google.com/project/taquotes

---
**Version**: 1.5.3 | **Last Updated**: January 2025 | **Status**: PRODUCTION LIVE