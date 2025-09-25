# Turbo Air Quotes (TAQ) - Development Documentation

## 🚨🚨🚨 ABSOLUTELY CRITICAL - READ FIRST 🚨🚨🚨

### ⛔⛔⛔ NEVER EVER HARDCODE CREDENTIALS ⛔⛔⛔

**VIOLATION COUNT: 5 TIMES** - This is UNACCEPTABLE!

### CREDENTIAL RULES - NEVER BREAK THESE:
1. **NEVER hardcode passwords in ANY file** - Not even as "fallback"
2. **NEVER hardcode email addresses** - Use environment variables ONLY
3. **NEVER hardcode API keys** - All keys must be in .env
4. **NEVER commit credentials** - They will be exposed in git history
5. **NEVER use default values for sensitive data** - Return empty strings
6. **NEVER put credentials in comments** - They still get committed

### FILES TO NEVER PUT CREDENTIALS IN:
- ❌ `email_config.dart` - NO DEFAULT EMAILS OR PASSWORDS
- ❌ `env_config.dart` - NO DEFAULT CREDENTIALS IN FALLBACKS
- ❌ Any `.dart` file - NO HARDCODED SECRETS
- ❌ Any config file - USE ENVIRONMENT VARIABLES ONLY
- ❌ Any documentation - NO EXAMPLE PASSWORDS

### WHAT HAPPENS WHEN YOU HARDCODE:
- Credentials get exposed in GitHub
- Gmail accounts get compromised
- Production systems get hacked
- Customer data gets stolen
- Business reputation destroyed
- Legal liability for data breaches

### THE ONLY CORRECT WAY:
```dart
// ✅ CORRECT - Gets from environment only
static String get emailAppPassword => dotenv.env['EMAIL_APP_PASSWORD'] ?? '';

// ❌ WRONG - NEVER DO THIS
static String get emailAppPassword => 'any_password_here'; // NEVER!

// ❌ WRONG - NO FALLBACKS WITH REAL DATA
static String get email => _getEnv('EMAIL', 'real@email.com'); // NEVER!
```

**IF YOU HARDCODE CREDENTIALS AGAIN, YOU ARE FAILING AT BASIC SECURITY!**

## 🚀 Project Overview

Enterprise B2B equipment catalog and quote management system with offline-first architecture, real-time synchronization, and complete email integration with PDF attachments. Serves 500+ sales representatives and processes 1000+ quotes monthly.

### Production Status: ✅ DEPLOYED (v1.0.1)
- **Live URL**: https://taquotes.web.app
- **Firebase Console**: https://console.firebase.google.com/project/taquotes/overview
- **Last Deployment**: January 24, 2025
- All critical features implemented and tested
- Security audit passed and fixes deployed
- Email with PDF attachments functional
- Client CRUD operations complete
- Quote management fully operational
- Firebase Hosting deployment successful
- **835 products loaded in database**
- **Latest: Merge conflicts resolved, error monitoring fixed, projects unified**

## 🚨 CRITICAL: PRESERVE ALL EXISTING FUNCTIONALITY

### PRIMARY DIRECTIVE
**NEVER BREAK WORKING FEATURES** - This app is LIVE with 500+ active users. Read this ENTIRE document before making ANY modifications.

## ⛔ CATASTROPHIC MISTAKES TO NEVER MAKE AGAIN ⛔

### DATABASE OPERATIONS - EXTREME CAUTION
**INCIDENT HISTORY:** Claude has previously caused COMPLETE DATA LOSS by giving incorrect Firebase import instructions.

#### ❌ NEVER DO THIS:
1. **NEVER tell user to import JSON without specifying EXACT path**
   - WRONG: "Import this JSON to Firebase"
   - RIGHT: "Import this JSON to `/products` node ONLY, NOT at root"
2. **NEVER suggest deleting .env, .venv, or environment files**
3. **NEVER give ambiguous database instructions**
4. **NEVER assume user knows Firebase import nuances**

#### ✅ ALWAYS DO THIS BEFORE ANY DATABASE OPERATION:
1. **CREATE FULL BACKUP FIRST:**
   ```bash
   firebase database:get "/" > FULL_BACKUP_$(date +%Y%m%d_%H%M%S).json
   ```
2. **SPECIFY EXACT NODE PATH:**
   - "Import to `/products` node ONLY"
   - "This will ONLY affect the products data"
   - "DO NOT import at root level"
3. **PROVIDE MULTIPLE WARNINGS:**
   ```
   ⚠️ WARNING: Importing at root (/) will DELETE EVERYTHING
   ⚠️ WARNING: Make sure you select the specific node (/products)
   ⚠️ WARNING: Wrong path = TOTAL DATA LOSS
   ```
4. **TEST WITH 5 ITEMS FIRST**

### TRUST STATUS: ⚠️ COMPROMISED
- **Date:** 2024-08-27
- **Incident:** Instructed user to import JSON without specifying path, causing complete database deletion
- **Data Lost:** All clients, users, quotes
- **Recovery:** Partial from incomplete backups

### MANDATORY SAFETY PROTOCOL
Before ANY risky operation:
1. Ask: "Have you created a backup?"
2. Provide backup command first
3. Explain EXACTLY what will be affected
4. Explain what will NOT be affected
5. Provide recovery plan BEFORE operation

### ⚠️ DO NOT BREAK THESE WORKING FEATURES

#### Critical Working Code - DO NOT MODIFY WITHOUT TESTING:

**1. Client Selection in Cart (cart_screen.dart:258)**
```dart
// THIS WORKS PERFECTLY - DO NOT CHANGE
return clientsAsync.when(
  data: (clients) => SearchableClientDropdown(...),
  loading: () => const LinearProgressIndicator(),
  error: (error, stack) => Text('Error loading clients: $error'),
);
```

**2. Cart Notifications - Always Use SKU**
```dart
// ALWAYS use SKU for notifications
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('${product.sku ?? product.model ?? 'Item'} removed from cart')),
);
// NEVER use product.displayName (too generic)
```

**3. Static Service Methods**
- `OfflineService` uses STATIC methods - DO NOT convert to instance
- `CacheManager` uses STATIC initialization - DO NOT change pattern
- These patterns are intentional for proper access across the app

**4. Image Handling System**
- ProductImageWidget fallback system works perfectly
- 1000+ SKU mappings are correct
- Thumbnail paths: `assets/thumbnails/SKU/SKU.jpg`
- Screenshot paths: `assets/screenshots/SKU/SKU P.1.png`

**5. Database Integrity**
- 835 products with full specifications - DO NOT delete or recreate
- All products have specs from Excel columns F-W
- Firebase URL: `https://taquotes-default-rtdb.firebaseio.com`

### 🚫 NEVER DO THESE
1. **NEVER delete existing database records** - 835 products must remain
2. **NEVER change existing database field names** - Will break sync
3. **NEVER remove working features** - Even if they seem unused
4. **NEVER modify authentication flow** - Current system is production-ready
5. **NEVER change static service patterns** - They're designed that way
6. **NEVER update dependencies** without explicit request
7. **NEVER create new files** unless absolutely necessary
8. **NEVER add mock/sample data** - Use real data only

### 📋 BEFORE MAKING CHANGES CHECKLIST
- [ ] Read entire CLAUDE.md document
- [ ] Check git status for modified files
- [ ] Identify which features will be affected
- [ ] Verify changes won't break existing providers
- [ ] Ensure database structure remains intact
- [ ] Test all critical paths after changes

## 🔧 Technical Architecture

### Core Technologies
- **Flutter 3.x** - Cross-platform framework
- **Firebase Realtime Database** - NoSQL with offline persistence
- **Firebase Authentication** - Secure user management
- **Riverpod** - State management
- **Hive** - Local storage for offline mode
- **Mailer 6.0.1** - Email service with attachment support
- **PDF Package** - Professional PDF generation
- **Image Optimization** - 1000+ thumbnails (400x400 JPEG 85% quality)

### Key Services

#### Email Service (`email_service.dart`)
```dart
// Fully functional PDF attachment support
sendQuoteWithPDF() - Generates and attaches PDF
sendQuoteWithPDFBytes() - Accepts pre-generated PDF
StreamAttachment - Used for memory-efficient attachments
```

#### Database Service (`realtime_database_service.dart`)
```dart
// Complete CRUD operations
addClient() / updateClient() / deleteClient()
createQuote() / updateQuote() / deleteQuote()
Real-time listeners with offline queue
```

#### Offline Service (`offline_service.dart`)
```dart
Static initialization for proper access
Sync queue management
Automatic conflict resolution
100MB cache for Firebase
```

## 📂 Project Structure

```
lib/
├── core/
│   ├── services/
│   │   ├── email_service.dart         # ✅ PDF attachments implemented
│   │   ├── export_service.dart        # ✅ PDF generation
│   │   ├── offline_service.dart       # ✅ Static methods fixed
│   │   ├── app_logger.dart           # ✅ Comprehensive logging
│   │   └── cache_manager.dart        # ✅ Static access patterns
│   ├── widgets/
│   │   └── product_image_widget.dart  # ✅ Smart fallback system
│   └── utils/
│       ├── product_image_helper.dart  # ✅ 1000+ SKU mappings
│       └── responsive_helper.dart     # ✅ Multi-platform support
├── features/
│   ├── clients/                       # ✅ Add/Edit/Delete functional
│   ├── quotes/                        # ✅ Complete management
│   ├── products/                      # ✅ Excel import ready
│   ├── admin/                         # ✅ Enhanced admin features
│   │   ├── data/
│   │   │   └── populate_demo_data.dart # ✅ Demo data generator
│   │   └── presentation/screens/
│   │       ├── admin_panel_screen.dart # ✅ Admin dashboard
│   │       └── performance_dashboard_screen.dart # ✅ User metrics
│   └── stock/
│       └── presentation/screens/
│           └── stock_dashboard_screen.dart # ✅ Warehouse tracking
└── assets/
    ├── thumbnails/                     # ✅ 1000+ optimized thumbnails
    └── screenshots/                    # ✅ Full resolution specs
```

## 🔐 Security Configuration

### Environment Variables (.env)
```env
ADMIN_EMAIL=andres@turboairmexico.com
ADMIN_PASSWORD=[secure-password]
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=[app-specific-password]
FIREBASE_PROJECT_ID=taquotes
FIREBASE_DATABASE_URL=https://taquotes-default-rtdb.firebaseio.com
```

### Firebase Security Rules
```json
{
  "rules": {
    "products": {
      ".read": true,
      ".write": "auth != null && auth.token.email == 'andres@turboairmexico.com'"
    },
    "clients": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "quotes": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

## ⚠️ CRITICAL: DO NOT BREAK THESE (UPDATED DEC 2024)

### ✅ FULLY WORKING FEATURES - DO NOT MODIFY

#### 1. Image Display System
```dart
// SimpleImageWidget - WORKS PERFECTLY for thumbnails and screenshots
// Used in: cart_screen.dart, products_screen.dart, quote_detail_screen.dart, home_screen.dart
SimpleImageWidget(
  sku: product.sku ?? product.model ?? '',
  useThumbnail: true,  // or false for screenshots
  width: 60,
  height: 60,
  fit: BoxFit.contain,
)
```

#### 2. Cart Screen Features (cart_screen.dart)
- **Collapsible Order Summary** - Starts collapsed, expandable with ExpansionTile
- **Collapsible Comments Section** - Starts collapsed, expandable with ExpansionTile
- **Client Selection** - SearchableClientDropdown works perfectly
- **Cart Notifications** - Always shows SKU (not generic displayName)
```dart
// Line 134-135: Collapsible states
bool _isOrderSummaryExpanded = false; // Start collapsed
bool _isCommentsExpanded = false; // Start collapsed
```

#### 3. Quotes Screen Search (quotes_screen.dart)
```dart
// Enhanced search - searches ALL fields (line 219-244)
// Searches: quote number, date, company, contact name, email, phone, address
final query = _searchQuery.toLowerCase();
filteredQuotes = filteredQuotes.where((q) {
  // Search in quote number, date, and all client fields
  if (q.quoteNumber?.toLowerCase().contains(query) ?? false) return true;
  if (dateFormat.format(q.createdAt).toLowerCase().contains(query)) return true;
  if (q.client != null) {
    final client = q.client!;
    return client.company.toLowerCase().contains(query) ||
           client.contactName.toLowerCase().contains(query) ||
           client.email.toLowerCase().contains(query) ||
           client.phone.toLowerCase().contains(query) ||
           (client.address?.toLowerCase().contains(query) ?? false);
  }
  return false;
}).toList();
```

#### 4. Client Search (clients_screen.dart)
```dart
// Case-insensitive partial matching (line 393-405)
final filteredClients = clients.where((client) {
  final companyLower = client.company.toLowerCase();
  final contactLower = (client.contactName ?? '').toLowerCase();
  final emailLower = (client.email ?? '').toLowerCase();
  final phoneLower = (client.phone ?? '').toLowerCase();
  
  return companyLower.contains(_searchQuery) ||
         contactLower.contains(_searchQuery) ||
         emailLower.contains(_searchQuery) ||
         phoneLower.contains(_searchQuery);
}).toList();
```

#### 5. Products Screen (products_screen.dart)
- **StreamProvider** for real-time updates
- **Initial load of 24 items** for performance
- **Load more on scroll** (12 items at a time)
- **SimpleImageWidget** for all thumbnails

### SCREENS THAT ARE PERFECT - DO NOT BREAK
```
✅ cart_screen.dart - Collapsible sections, client selection, thumbnails
✅ profile_screen.dart - User profile management
✅ quotes_screen.dart - Enhanced search, thumbnails in details
✅ quote_detail_screen.dart - Product thumbnails with SimpleImageWidget
✅ clients_screen.dart - Case-insensitive partial search
✅ products_screen.dart - Real-time updates, lazy loading
✅ home_screen.dart - SimpleImageWidget for featured products
```

## 🎯 Recent Implementations (January 2025)

### ✅ Admin Dashboard Features
```dart
// performance_dashboard_screen.dart
- User performance metrics tracking
- Revenue and conversion rate analysis
- Performance scoring algorithm
- Top performers ranking
- Three-tab interface: Overview, Users, Analytics
```

### ✅ Stock Dashboard
```dart
// stock_dashboard_screen.dart
- Real-time Firebase warehouse data
- 6 warehouse locations (KR, VN, CN, TX, CUN, CDMX)
- Category-based equipment tracking
- Critical stock alerts
- Warehouse comparison tables
- Global vs warehouse-specific views
```

### ✅ Demo Data Population
```dart
// populate_demo_data.dart
- 10 demo users with authentication
- 30 clients (3 per user) with detailed info
- 100 quotes (10 per user) with realistic data
- Warehouse stock for all products
- One-click population from Admin Panel
- Loading indicators and confirmation dialogs
```

### ✅ PDF Attachments (Completed)
```dart
// email_service.dart
- StreamAttachment for memory efficiency
- Automatic PDF generation from quotes
- Fallback for email without attachment
- Two methods: sendQuoteWithPDF() and sendQuoteWithPDFBytes()
```

### ✅ Client Edit Functionality (Completed)
```dart
// clients_screen.dart
- Form reuse for add/edit
- State management with _editingClientId
- Dynamic button labels
- Proper data population
```

### ✅ Quote Delete Functionality (Completed)
```dart
// quotes_screen.dart
- Confirmation dialog
- Database deletion
- Error handling
- Success feedback
```

## 📊 Database Schema

### Products Collection
```json
{
  "sku": "string",
  "name": "string",
  "description": "string",
  "price": "number",
  "category": "string",
  "image_url": "string"
}
```

### Clients Collection
```json
{
  "company": "string",
  "contact_name": "string",
  "email": "string",
  "phone": "string",
  "address": "string",
  "user_id": "string"
}
```

### Quotes Collection
```json
{
  "quote_number": "string",
  "client_id": "string",
  "items": "array",
  "total": "number",
  "status": "string",
  "created_at": "timestamp"
}
```

## 🚀 Deployment

### Live Deployment Information
- **Production URL**: https://taquotes.web.app
- **Alternative URL**: https://taquotes.firebaseapp.com
- **Firebase Project**: taquotes
- **Deployment Account**: andres.xbgo@gmail.com
- **Last Deployed**: January 2025

### Firebase Hosting Configuration
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}]
  }
}
```

### Deployment Commands
```bash
# Login to Firebase
firebase login

# Build for production with HTML renderer
flutter build web --release --web-renderer html

# Deploy to Firebase Hosting
firebase deploy --only hosting

# Deploy everything (database rules, hosting, storage)
firebase deploy
```

### Build Commands
```bash
# Web
flutter build web --release

# Android
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release
```

## 📋 Features Status

| Feature | Status | Details |
|---------|--------|---------|
| **Core Features** | | |
| Product Catalog | ✅ | 835+ products with images |
| Client Management | ✅ | Full CRUD with search |
| Quote System | ✅ | Create, edit, duplicate, delete |
| Shopping Cart | ✅ | Persistent with tax calculation |
| **Admin Features** | | |
| Performance Dashboard | ✅ | User metrics, revenue, conversion rates |
| Stock Dashboard | ✅ | Real-time warehouse tracking |
| Demo Data Population | ✅ | One-click test data generation |
| User Analytics | ✅ | Performance scoring system |
| Warehouse Management | ✅ | 6 locations with stock alerts |
| **Export/Import** | | |
| PDF Export | ✅ | Professional formatted quotes |
| Excel Export | ✅ | Spreadsheet with formulas |
| Excel Import | ✅ | Bulk product upload (10k limit) |
| Batch Export | ✅ | Multiple quotes at once |
| **Email System** | | |
| Quote Emails | ✅ | Gmail SMTP integration |
| PDF Attachments | ✅ | StreamAttachment implementation |
| Excel Attachments | ✅ | Up to 25MB |
| Email Templates | ✅ | Professional HTML format |
| **Offline Features** | | |
| Offline Mode | ✅ | 100% functionality |
| Auto Sync | ✅ | Queue management |
| Conflict Resolution | ✅ | Smart merge |
| Local Cache | ✅ | 100MB storage |
| **UI/UX** | | |
| Responsive Design | ✅ | Mobile/Tablet/Desktop |
| Dark Mode | ✅ | Theme switching |
| Product Tabs | ✅ | Filter by type |
| Price Formatting | ✅ | Comma separators |
| Image Gallery | ✅ | 1053 product folders |
| **Security** | | |
| Authentication | ✅ | Firebase Auth |
| Role Management | ✅ | Admin/Sales/Distributor |
| Data Encryption | ✅ | In transit |
| Session Management | ✅ | Auto-logout |
| Audit Logs | ✅ | Activity tracking |

## 🛠️ Development Commands

```bash
# Run locally
flutter run -d chrome

# Fix issues
dart fix --apply

# Analyze
flutter analyze

# Clean build
flutter clean && flutter pub get

# Generate icons
flutter pub run flutter_launcher_icons

# Run tests
flutter test
```

## 🔑 Authentication & Access

### Admin Login Credentials
- **Email**: andres@turboairmexico.com
- **Password**: Stored securely in .env file
- **Note**: Authentication required to view products and clients

### User Roles
- **Super Admin**: Full system access, Excel import
- **Admin**: Client and quote management
- **Sales**: Create quotes, manage clients
- **Distributor**: View products, create quotes

## 🐛 Troubleshooting

### Common Issues & Solutions

#### Can't Login?
- Check internet connection
- Verify email and password
- Clear browser cache (Ctrl+Shift+R)
- Try incognito/private browsing mode
- Ensure .env file exists locally
- Verify Firebase Auth is enabled

#### Products Not Loading?
- Refresh the page (F5)
- Check if logged in (authentication required)
- Clear app cache in settings
- Verify Firebase database rules
- Database has 835+ products loaded

#### Email Not Sending?
- Verify recipient email address
- Check attachment size (<25MB limit)
- Ensure internet connection
- Confirm Gmail SMTP settings in .env

#### Offline Not Working?
- Enable offline mode in settings
- Ensure app was online at least once
- Check available storage space (100MB cache)
- Verify Firebase persistence is enabled

#### White/Blank Page on Deployment
- Clear browser cache (Ctrl+Shift+R)
- Check browser console for errors (F12)
- Ensure Firebase SDKs are loaded in index.html
- Try different browser or device

#### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release --web-renderer html
```

### Known Limitations
- Email attachments limited to 25MB
- Excel import max 10,000 products at once
- Offline cache limited to 100MB
- Maximum 5 concurrent users per account

## 📝 Code Quality

### Fixed Issues
- ✅ All TODO comments resolved
- ✅ Static/instance method conflicts fixed
- ✅ Null safety violations resolved
- ✅ AsyncValue patterns corrected
- ✅ Unused variables removed
- ✅ Deprecated APIs updated

### Current State
- 0 critical errors
- 0 blocking issues
- Full functionality across all platforms
- Production-ready security

## 🔄 Git Workflow

```bash
# Stage changes
git add .

# Commit with message
git commit -m "feat: implement PDF attachments and complete CRUD operations"

# Push to remote
git push origin main
```

## 📧 Support Contacts

- **Lead Developer**: andres@turboairmexico.com
- **Support Email**: turboairquotes@gmail.com
- **GitHub**: [Repository](https://github.com/REDXICAN/TAQuotes)

## ✅ Production Checklist

- [x] Environment variables configured
- [x] Firebase security rules applied and deployed
- [x] Email service with PDF attachments
- [x] PDF generation functional
- [x] Client CRUD operations
- [x] Quote management complete
- [x] Offline synchronization
- [x] Excel import with preview
- [x] Logging system active
- [x] Error handling comprehensive
- [x] Authentication secure
- [x] Role-based access control
- [x] Product catalog complete (835 products)
- [x] Shopping cart persistent
- [x] Admin panel functional
- [x] Firebase Hosting deployed
- [x] GitHub repository updated
- [x] Production URL active

## 🎉 Production Deployed

Application successfully deployed to Firebase Hosting and fully operational.

### Access the Application
- **URL**: https://taquotes.web.app
- **Login**: Use admin credentials from .env file
- **Support**: andres@turboairmexico.com

### Key Metrics
- **Products in Database**: 835+ products
- **Product Images**: 1053 folders available
- **Active Users**: 500+ sales representatives
- **Monthly Quotes**: 1000+ processed
- **Platform Support**: Web, Android, iOS, Windows
- **Languages**: English and Spanish
- **Uptime**: 99.9% since launch
- **Time Saved**: 10 hours per week per user
- **Deployment Platform**: Firebase Hosting
- **Database**: Firebase Realtime Database
- **Authentication**: Firebase Auth

## 🔒 Security Enhancements (January 2025)

### Critical Security Implementations
1. **CSRF Protection Service** (`csrf_protection_service.dart`)
   - Token generation and validation for all state-changing operations
   - Prevents cross-site request forgery attacks
   - Automatic token refresh mechanism

2. **Rate Limiting Service** (`rate_limiter_service.dart`)
   - API call throttling to prevent abuse
   - Configurable limits per endpoint
   - User-specific rate tracking

3. **Enhanced Logging System** (`secure_app_logger.dart`)
   - Secure logging with PII redaction
   - Audit trail for security events
   - Encrypted log storage for sensitive operations

4. **Input Validation Service** (`validation_service.dart`)
   - Comprehensive input sanitization
   - SQL injection prevention
   - XSS attack mitigation

5. **Active Client Banner** (`active_client_banner.dart`)
   - Visual indicator for current client selection
   - Prevents accidental data mixing between clients

### Security Best Practices Implemented
- ✅ All sensitive files in .gitignore
- ✅ Environment variables for secrets
- ✅ Firebase security rules enforced
- ✅ Role-based access control (RBAC)
- ✅ Secure password reset flow
- ✅ Session management with auto-logout
- ✅ HTTPS-only communication
- ✅ Content Security Policy headers

### Database Security Rules
```json
{
  "rules": {
    "products": {
      ".read": "auth != null",
      ".write": "auth.token.email == 'andres@turboairmexico.com'"
    },
    "clients": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "quotes": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

## 🎨 UI/UX Improvements (January 2025)

### Logo Implementation
- **Splash Screen**: Enhanced logo display with white background container
- **Login Screen**: Logo with subtle background for better visibility
- **Web Loading**: Configured in index.html with fallback text
- **Asset Management**: Proper logo path configuration in pubspec.yaml

### Visual Enhancements
- Improved loading animations with dots
- Better error state displays
- Consistent branding across all screens
- Responsive design optimizations

## ⚠️ IMPORTANT NOTES FOR DEVELOPERS

### Things That Already Work - DO NOT MODIFY
1. **Client Selection in Cart** (cart_screen.dart:258)
   - SearchableClientDropdown implementation is perfect
   - AsyncValue.when pattern works correctly
   - DO NOT change the loading/error handling

2. **Cart Notifications**
   - Always use SKU for notifications: `product.sku ?? product.model ?? 'Item'`
   - Never use product.displayName (too generic)

3. **Static Service Methods**
   - OfflineService uses static methods - DO NOT convert to instance
   - CacheManager uses static initialization - DO NOT change pattern

4. **Image Handling**
   - ProductImageWidget fallback system works perfectly
   - 1000+ SKU mappings are correct
   - Thumbnail/screenshot paths are validated

### Common Issues and Solutions
- **White Screen on Deploy**: Clear browser cache (Ctrl+Shift+R)
- **Products Not Loading**: Check authentication status
- **Email Not Sending**: Verify Gmail SMTP settings in .env
- **Offline Not Working**: Ensure 100MB cache space available

## 🖼️ Firebase Storage Image System (CRITICAL - WORKING)

### Image Migration to Firebase Storage (January 2025)
**Problem Solved**: Flutter web cannot bundle 3,534 nested asset files. Images were not displaying in production.

**Solution Implemented**:
1. **Firebase Storage Configuration**
   - Storage bucket: `taquotes.firebasestorage.app` (NOT taquotes.appspot.com)
   - 3,534 images successfully uploaded (1,454 thumbnails, 2,080 screenshots)
   - Public read access enabled for product images

2. **Database Image URLs**
   - `thumbnailUrl`: Firebase Storage URL for product thumbnails
   - `imageUrl`: P.1 screenshot URL
   - `imageUrl2`: P.2 screenshot URL
   - 830 products have Firebase URLs
   - 823 products have both P.1 and P.2 screenshots

3. **Flutter App Updates**
   - `SimpleImageWidget` accepts `imageUrl` parameter for Firebase URLs
   - `ProductImageDisplay` supports network images with fallback to assets
   - `ProductDetailImages` displays both P.1 and P.2 from Firebase
   - All product cards pass Firebase URLs to image widgets

4. **Scripts Created**
   - `upload_images_to_firebase.py`: Uploads all images to Firebase Storage
   - `update_database_urls.py`: Updates database with Firebase Storage URLs
   - `add_p2_urls.py`: Adds P.2 screenshot URLs to database
   - `count_uploads.py`: Monitors upload progress
   - `verify_urls.py`: Verifies database has all image URLs

### IMPORTANT: DO NOT CHANGE
- Thumbnails in products screen are working perfectly with Firebase Storage
- Screenshots in product detail pages display both P.1 and P.2
- The storage bucket name is `taquotes.firebasestorage.app`
- Image loading falls back to local assets if Firebase fails

## 🔧 FIX: Auto-Refresh Data Loading Solution

### Problem
Screens requiring manual refresh to display data, particularly:
- Pending user approvals not showing without reload
- Stock dashboard needing refresh
- Client lists not updating automatically
- Quote screens showing stale data

### Solution Applied
1. **Convert FutureProvider to StreamProvider** for real-time updates
2. **Add `.autoDispose` modifier** to force data refresh on widget rebuild
3. **Implement error handling** with fallback empty states
4. **Show loading indicators** while data is being fetched

### Implementation Pattern
```dart
// ❌ OLD: FutureProvider (requires manual refresh)
final dataProvider = FutureProvider<List<Item>>((ref) async {
  return await fetchData();
});

// ✅ NEW: StreamProvider with autoDispose (auto-refreshes)
final dataProvider = StreamProvider.autoDispose<List<Item>>((ref) {
  final service = ref.watch(serviceProvider);
  return service.streamData()
    .handleError((error) {
      AppLogger.error('Error loading data', error: error);
      return [];
    });
});
```

### Screens Fixed
- ✅ User Approvals Widget - Now loads immediately
- ✅ Stock Dashboard - Real-time stock updates
- ✅ Clients Screen - Auto-refresh client list
- ✅ Products Screen - Live product updates
- ✅ Quotes Screen - Real-time quote tracking
- ✅ Admin Panel - All admin features auto-refresh

### Key Files Modified
- `user_approvals_widget.dart` - Added StreamProvider.autoDispose
- `stock_dashboard_screen.dart` - Implemented real-time data loading
- `auto_refresh_providers.dart` - Created universal refresh solution

### Usage in New Screens
```dart
// 1. Use StreamProvider.autoDispose for auto-refresh
final myDataProvider = StreamProvider.autoDispose<List<MyData>>((ref) {
  return ref.watch(databaseService).streamMyData();
});

// 2. Show loading state while fetching
Widget build(context, ref) {
  final dataAsync = ref.watch(myDataProvider);

  return dataAsync.when(
    data: (data) => ListView(...),
    loading: () => CircularProgressIndicator(),
    error: (e, s) => Text('Error: $e'),
  );
}
```

## 🔄 Auto-Refresh Data Loading Solution (January 2025)

### Problem Solved
Screens were requiring manual refresh/reload to display new data. Users had to navigate away and back to see updates, particularly affecting:
- Pending user approvals widget
- Admin dashboards
- Stock monitoring screens
- Error monitoring dashboard

### Solution: StreamProvider.autoDispose Pattern

#### Implementation Pattern
Convert all data-fetching providers from `FutureProvider` to `StreamProvider.autoDispose` with periodic refresh:

```dart
// BEFORE - Requires manual refresh
final dataProvider = FutureProvider<DataType>((ref) async {
  return await fetchData();
});

// AFTER - Auto-refreshes every 30 seconds
final dataProvider = StreamProvider.autoDispose<DataType>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) => null)
      .asyncMap((_) async => await fetchData())
      .startWith(defaultValue) // Initial value while loading
      .handleError((error) => fallbackValue); // Error handling
});
```

### Screens Updated with Auto-Refresh

#### Core Screens (Already using StreamProvider)
- ✅ **Products Screen** - Real-time product catalog updates
- ✅ **Clients Screen** - Live client list updates
- ✅ **Quotes Screen** - Real-time quote status changes

#### Admin Features (Converted to StreamProvider)
- ✅ **User Approvals Widget** - Auto-refreshes pending approvals
- ✅ **Performance Dashboard** - Live user metrics updates
- ✅ **Error Monitoring Dashboard** - Real-time error tracking
- ✅ **Backup Status Widget** - Live backup statistics
- ✅ **User Info Dashboard** - Auto-updates user activity
- ✅ **Stock Dashboard** - Real-time warehouse stock levels

#### Project Features (Converted to StreamProvider)
- ✅ **Project by ID Provider** - Single project auto-refresh
- ✅ **Projects by Client** - Client project list updates

### Universal Auto-Refresh Utilities

Created `lib/core/providers/auto_refresh_providers.dart` with:
- **AutoRefreshMixin** - Add to any ConsumerStatefulWidget
- **AutoRefreshProvider extension** - Convert any provider easily
- **createAutoRefreshingProvider helper** - Quick provider creation
- **globalRefreshProvider** - Force refresh all providers

### Usage Examples

#### For New Screens
```dart
// Define provider with auto-refresh
final myDataProvider = StreamProvider.autoDispose<List<Item>>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) => null)
      .asyncMap((_) async {
        // Fetch fresh data
        return await fetchItems();
      })
      .startWith([]); // Start with empty list
});

// Use in widget
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(myDataProvider);

    return dataAsync.when(
      data: (items) => ListView(children: items.map(...)),
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text('Error: $e'),
    );
  }
}
```

#### For Existing FutureProvider
```dart
// Convert existing FutureProvider
// FROM:
final oldProvider = FutureProvider<Data>((ref) async => fetchData());

// TO:
final newProvider = StreamProvider.autoDispose<Data>((ref) {
  return Stream.periodic(Duration(seconds: 30), (_) => null)
      .asyncMap((_) => fetchData())
      .startWith(null);
});
```

### Benefits
- **No Manual Refresh** - Data updates automatically
- **Better UX** - Users see changes without interaction
- **Resource Efficient** - autoDispose cleans up unused streams
- **Error Resilient** - Handles network issues gracefully
- **Configurable** - Adjust refresh intervals as needed

### Performance Considerations
- Default refresh interval: 30 seconds
- Streams auto-dispose when widgets unmount
- Firebase real-time listeners used where available
- Polling fallback for non-real-time endpoints

## 🔄 Version History

### Version 1.0.1 (Current - January 2025)

#### Merge Conflict Resolution & Deployment (January 24, 2025)
**Major Fixes After Git Merge:**
- **Error Monitoring Dashboard Fixed**
  - Added missing methods: `clearResolvedErrors()`, `clearAllErrors()`, `markErrorAsResolved()`
  - Added missing properties to ErrorReport: `isResolved`, `metadata`
  - Added helper methods: `_getCategoryColor()`, `_formatTimestamp()`
  - Full error tracking and resolution functionality now working

- **Project Model Conflicts Resolved**
  - Unified to use single Project model from `core/models/project.dart`
  - Fixed property naming: `projectName` → `name` throughout
  - Fixed `createProject()` method signature mismatches
  - Fixed DateTime nullable issues with proper null safety
  - Removed duplicate domain model that was causing conflicts

- **Cart Screen Null Safety Fixed**
  - Fixed discount calculation null safety issues (lines 1795-1797)
  - Proper null coalescing for `discountValue` and `discountAmount`
  - Maintained calculation logic while ensuring type safety

- **Admin Panel Improvements**
  - Updated deprecated `withOpacity()` to `withValues(alpha:)`
  - Removed 91 lines of unused code
  - Fixed null-aware expressions for non-nullable types
  - All Firebase imports properly resolved

**Deployment:**
- Successfully built Flutter web (60 seconds, with 99% font optimization)
- Deployed to Firebase Hosting: https://taquotes.web.app
- 47 files uploaded to production
- All security fixes and warehouse features preserved

### Version 1.0.0 (January 2025)

#### Critical Security Audit & Fixes (January 24, 2025)
**Security Enhancements:**
- **Session Timeout Implementation**
  - Added 30-minute automatic logout for inactivity
  - Created `SessionTimeoutService` and `SessionTimeoutWrapper`
  - Tracks all user interactions (clicks, scrolls, mouse movement)
  - Integrated into main app wrapper for automatic security

- **CSRF Protection Hardening**
  - Replaced timestamp-based CSRF keys with cryptographically secure random generation
  - Using `Random.secure()` for 256-bit entropy
  - Enhanced `env_config.dart` with secure key generation

- **Mock Data Security**
  - Restricted mock data to debug mode AND admin/superadmin users only
  - Added multiple protection layers in `user_info_dashboard_screen.dart`
  - Prevents accidental data exposure in production

- **Rate Limiting Enhancements**
  - Applied rate limiting to all authentication endpoints
  - Added database operation throttling
  - Prevents brute force and DoS attacks

- **Test Infrastructure Created**
  - Created comprehensive test structure (unit/widget/integration)
  - Added initial tests for models, services, and widgets
  - Increased test coverage from 0% to initial baseline

**Documentation Fixes:**
- Fixed all version number inconsistencies (now correctly shows v1.0.0)
- Corrected impossible future dates in documentation
- Updated all .md files with accurate information
- Renamed development reports to correct years

**Performance Optimizations:**
- Products screen already has lazy loading (24 initial, +12 on scroll)
- Identified but preserved large cart_screen.dart to avoid breaking production
- Added logging import fixes in models.dart

**Files Modified (44 files):**
- Core Services: `session_timeout_service.dart` (NEW), `csrf_protection_service.dart`, `rate_limiter_service.dart`
- Security: `env_config.dart`, `validation_service.dart`, `offline_service.dart`
- Documentation: `CLAUDE.md`, `README.md`, development reports
- Test Files: Created `test/` directory with initial test suite
- Models: Fixed import issues in `models.dart`

**Previous Features:**
- **Auto-Refresh Data Loading Implementation**
  - Converted all FutureProviders to StreamProvider.autoDispose
  - Added universal auto-refresh utilities
  - Fixed pending user approvals loading issue
  - Applied auto-refresh to all admin screens
  - Enhanced real-time data synchronization
  - No more manual page reloads required

### Version 0.9.9 (January 2025)
- **Stock Dashboard - Persistent Editable Values**
  - Added save icons next to utilization % and capacity input fields
  - Implemented SharedPreferences for persistent storage
  - Values persist across page refreshes
  - Fixed loading issue that required page reload
  - Controllers initialize properly on first load
  - Mock warehouse stock data remains for demo purposes

### Version 0.9.8 (January 2025)
- **MAJOR: Admin Dashboard Enhancements**
- Added comprehensive Performance Dashboard for admin/superadmin users
  - Access control for andres@turboairmexico.com and admin roles
  - User performance metrics and scoring system
- Created Stock Dashboard with real-time Firebase warehouse data
  - Redesigned with improved visualization (Session 2)
  - Enhanced warehouse health scores and comparison views
  - Category distribution charts
  - Critical stock alerts with better UI
- Added warehouse stock display in product detail screens
  - Real-time stock levels for all 6 warehouses
  - Color-coded availability indicators
  - Shows available vs reserved quantities
- Implemented demo data population system (10 users, 30 clients, 100 quotes)
- Added warehouse stock tracking for 6 global locations
- Performance metrics: revenue tracking, conversion rates, user scoring
- Stock management: category breakdowns, critical alerts, comparison tables
- Created DemoDataPopulator class for instant test data generation
- Added "Populate Demo Data" button in Admin Panel settings

### Version 0.9.7 (August 2024)
- **MAJOR: Migrated all 3,534 product images to Firebase Storage**
- Fixed thumbnails not displaying in production (Flutter web asset limitation)
- Added Firebase Storage URLs to database (thumbnailUrl, imageUrl, imageUrl2)
- Updated all image widgets to load from Firebase Storage CDN
- Implemented fallback to local assets if Firebase fails
- Created Python scripts for image migration and database updates
- 830 products now have Firebase Storage image URLs
- Both P.1 and P.2 screenshots working in product detail pages

### Version 1.3.0 (December 2024)
- Implemented comprehensive security enhancements
- Added CSRF protection and rate limiting
- Enhanced logging with security audit trails
- Improved logo display on splash and login screens
- Fixed login screen logo rendering issue
- Added input validation service
- Updated Firebase security rules

### Version 1.2.1 (December 2024)
- **UI/UX Improvements**:
  - Made Order Summary collapsible in cart (starts collapsed)
  - Made Comments section collapsible in cart (starts collapsed)
  - Fixed thumbnails across all screens using SimpleImageWidget
- **Search Enhancements**:
  - Enhanced quotes search to include all client fields (name, email, phone, address)
  - Improved quotes search to include date searching
  - Confirmed client search uses case-insensitive partial matching
- **Performance**:
  - Products screen loads immediately without requiring refresh
  - Optimized image loading with SimpleImageWidget
- **Bug Fixes**:
  - Fixed home screen thumbnails not displaying
  - Fixed quote detail screen thumbnails
  - Resolved products screen reload issue

### Version 0.9.4 (August 2024)
- Added product type filtering tabs
- Implemented price comma formatting  
- Fixed Excel attachment functionality
- Improved navigation menu order
- Enhanced offline capabilities
- Added toggle switches for client selection
- Fixed quote editing functionality
- Optimized image handling for 835+ products

### Version 1.1.0
- Added Excel import/export
- Implemented role management
- Enhanced email templates
- Fixed sync issues

### Version 1.0.0
- Initial release
- Core functionality
- Basic CRUD operations

---

**Last Updated**: January 2025
**Current Version**: 1.0.0
**Deployment**: Firebase Hosting (taquotes)
**Repository**: https://github.com/REDXICAN/TAQuotes

## 🔴 CRITICAL SAFETY RULES - MANDATORY READING

### ⚠️ TRUST LEVEL: COMPROMISED DUE TO CATASTROPHIC ERRORS

#### DOCUMENTED FAILURES:
1. **2024-08-27:** Caused complete database deletion by not specifying import path
2. **2024-08-26:** Instructed to delete .venv breaking development environment

### BULLETPROOF SAFETY PROTOCOLS

#### 1. DATABASE OPERATIONS
**BEFORE suggesting ANY database operation:**
```
□ Have I told them to create a backup FIRST?
□ Have I specified the EXACT node path (/products, /clients, etc)?
□ Have I warned what happens if they import at root?
□ Have I provided a recovery plan?
□ Have I suggested testing with 5 items first?
```

**TEMPLATE FOR DATABASE OPERATIONS:**
```markdown
⚠️⚠️⚠️ CRITICAL DATABASE OPERATION ⚠️⚠️⚠️

STEP 1 - CREATE BACKUP FIRST:
firebase database:get "/" > BACKUP_[timestamp].json
Verify file size > 0

STEP 2 - UNDERSTAND THE RISK:
- This operation affects: [specific path]
- This will NOT affect: [other paths]
- Wrong path = TOTAL DATA LOSS

STEP 3 - IMPORT INSTRUCTIONS:
1. Go to Firebase Console
2. Navigate to SPECIFIC node: /products (NOT root!)
3. Verify path shows "/products" before importing
4. Import JSON

RECOVERY PLAN IF SOMETHING GOES WRONG:
[Specific steps to restore from backup]
```

#### 2. FILE OPERATIONS
**NEVER suggest deleting:**
- .env (contains credentials)
- .venv or venv/ (Python environment)
- node_modules/ (dependencies)
- firebase.json (configuration)
- Any file without backup

**BEFORE ANY file deletion:**
```
□ Have I checked what's in the file?
□ Have I created a backup?
□ Have I verified it's not critical?
```

#### 3. FIREBASE SPECIFIC RULES
- **Root import (/)** = DELETES ENTIRE DATABASE
- **Node import (/products)** = Replaces ONLY that node
- **Firebase Auth** ≠ Firebase Database (separate systems)
- **Always use --shallow** for large data checks

#### 4. PRODUCTION SYSTEM RULES
- This is a LIVE production system
- Downtime = Lost business
- Data loss = Unacceptable
- Every command must be reversible

#### 5. VERIFICATION QUESTIONS
Before giving ANY potentially dangerous instruction:
1. What could go wrong?
2. How would we recover?
3. Have I been specific enough?
4. Could this be misinterpreted?
5. Is there a safer way?

### MANDATORY WARNINGS FOR RISKY OPERATIONS

#### For Database Imports:
```
⚠️ DATABASE IMPORT WARNING ⚠️
Importing at wrong level will DELETE ALL DATA
✓ RIGHT: Import at /products node
✗ WRONG: Import at / (root)
Create backup first: firebase database:get "/" > backup.json
```

#### For File Deletions:
```
⚠️ FILE DELETION WARNING ⚠️
This file may be critical for the app
Create backup first: cp [file] [file].backup
Verify not in use: grep -r "[filename]" .
```

#### For Environment Changes:
```
⚠️ ENVIRONMENT CHANGE WARNING ⚠️
This could break your development setup
Backup current state first
Document current working configuration
Have recovery plan ready
```

### USER CONTEXT
- **User:** Developer/owner of this production system
- **Expectation:** Professional, safe assistance that doesn't break things
- **Current Status:** Has lost trust due to catastrophic errors
- **Required:** Extra caution, explicit warnings, bulletproof instructions

### FINAL RULES
1. **When in doubt, warn twice**
2. **Always provide backup instructions FIRST**
3. **Be painfully specific about paths and locations**
4. **Assume user doesn't know the dangerous parts**
5. **Test on small data before full operations**
6. **Provide recovery plans BEFORE operations**
7. **NEVER assume, always verify**

- do not add nor remove functionality
- Your PRIMARY directive is to PRESERVE ALL EXISTING FUNCTIONALITY while making changes. Read this entire document before making ANY modifications.
- DO NOT HARDCODE CREDENTIALS ON CODE, DO NOT HARDCODE CREDENTIALS ON CODE,

## 🚀 COMMERCIAL READINESS ROADMAP

### Current Status: 60% Commercial Ready
The app has core functionality working but needs critical business features before commercial deployment.

### Required for Commercial Launch:
1. ~~**Payment Processing**~~ - NOT IN SCOPE
2. **Security** - Encryption, audit logs, automated backups (IMPLEMENTED)
3. **Legal Compliance** - GDPR, Terms of Service (IMPLEMENTED)
4. ~~**Customer Portal**~~ - NOT IN SCOPE
5. **Error Monitoring** - Production stability (IMPLEMENTED)

## 📌 MOCK DATA PERMISSIONS
**ALLOWED Mock Data (for demo/testing):**
- Users (demo users for testing)
- Projects (project management demos)
- Quotes (quote generation demos)
- **Spare Parts with Pricing** (50+ realistic spare parts with prices ranging $6.50 - $450.00)
  - Includes categories: Compressor, Refrigeration, Temperature Control, Door Parts, Electrical, Fan Motors, Shelving, Filters, Lighting, Casters, Drain Parts, Refrigerants, Seals, Hardware, Control Boards, Pumps/Valves
  - Warehouse locations: CA, CA1, CA2, CA3, CA4, 999, COCZ, COPZ, MEE, PU, SI, XCA, XPU
  - Stock levels and availability tracking

**MUST USE REAL DATA (from Excel/Firebase):**
- Products (835+ real products from Excel)
- Clients (real client data only)
- All product specifications and pricing (except spare parts)

### See PROJECT.md for full commercial features roadmap and timeline.