# Turbo Air Quotes (TAQ) - Enterprise B2B Quote Management System

[![Live Demo](https://img.shields.io/badge/Live%20Demo-taquotes.web.app-blue)](https://taquotes.web.app)
[![Version](https://img.shields.io/badge/Version-1.2.1-green)](https://github.com/REDXICAN/TAQuotes)
[![Security](https://img.shields.io/badge/Security-Enhanced-red)](##-security-features)
[![Platform](https://img.shields.io/badge/Platform-Web%20|%20iOS%20|%20Android%20|%20Windows-orange)]()

> **For Non-Technical Users (Age 50+):** This is a business application that helps you manage product catalogs, create quotes for customers, and send them professional PDFs via email. Think of it like a digital version of a paper catalog combined with a quote calculator and email system - all in one easy-to-use app that works on any device.

## 🎯 What This App Does (Simple Explanation)

This app helps Turbo Air sales teams and distributors:
1. **Browse Products** - Like flipping through a digital catalog with pictures
2. **Create Quotes** - Add products to a cart, just like online shopping
3. **Manage Customers** - Keep a digital address book of all your clients
4. **Send Professional Quotes** - Email beautiful PDF quotes with one click
5. **Work Offline** - Use the app anywhere, even without internet

## 🚀 Quick Start Guide (For Everyone)

### Step 1: Access the App
- **Web Browser**: Visit https://taquotes.web.app
- **Mobile**: Download from App Store (iOS) or Play Store (Android)
- **Windows**: Download installer from company portal

### Step 2: Login
- Use your company email and password
- Contact IT if you need credentials

### Step 3: Start Using
- **Home** → See your dashboard
- **Clients** → Manage your customer list
- **Products** → Browse the catalog
- **Cart** → Review items before creating quote
- **Quotes** → View and manage all quotes
- **Profile** → Your account settings

## 🚨 CRITICAL FOR DEVELOPERS: PRESERVE ALL EXISTING FUNCTIONALITY

### ⚠️ PRIMARY DIRECTIVE
**This app is LIVE in PRODUCTION with 500+ active users.** Every feature listed below is currently working. Before making ANY changes, you MUST preserve all existing functionality.

### 🛑 DO NOT BREAK THESE WORKING FEATURES
1. **835 products** with full specifications loaded from Excel
2. **Client selection dropdown** in cart (SearchableClientDropdown at cart_screen.dart:258)
3. **Quote creation** with PDF generation and email attachments
4. **Offline mode** with automatic sync when reconnected
5. **Product images** from assets/thumbnails and assets/screenshots
6. **All CRUD operations** for clients, quotes, and products
7. **Firebase integration** with Realtime Database
8. **Authentication system** with role-based access

### ⚫ NEVER DO THESE
- **NEVER delete database records** - 835 products must remain intact
- **NEVER change database field names** - Will break synchronization
- **NEVER modify static service patterns** - OfflineService and CacheManager use static methods intentionally
- **NEVER remove working features** - Even if they seem unused
- **NEVER add mock/sample data** - Use real data only
- **NEVER update dependencies** without explicit request
- **NEVER break the authentication flow** - It's production-ready

### ✅ BEFORE MAKING CHANGES
1. Read the entire CLAUDE.md documentation file
2. Check `git status` to understand current state
3. Test ALL features listed below after your changes
4. Verify database integrity (835 products remain)
5. Ensure offline sync still works
6. Confirm PDF generation and email sending work

### 🔧 SAFE MODIFICATION APPROACH
```dart
// GOOD: Add new features without removing existing
class ExistingService {
  existingMethod() { /* don't touch */ }
  newMethod() { /* your new code */ }
}

// BAD: Replacing working code
class ExistingService {
  // deletedExistingMethod() - DON'T DO THIS
  newMethod() { /* replacement */ }
}
```

## 📱 Complete Feature List

### 🏠 **Home Dashboard**
- Quick statistics overview
- Recent quotes at a glance
- Fast access to common tasks
- Real-time sync status indicator

### 👥 **Client Management (CRM)**
- ✅ Add new clients with full contact details
- ✅ Edit existing client information
- ✅ Delete inactive clients
- ✅ **Case-insensitive partial search** by name, company, email, or phone
- ✅ Visual selection indicator for active client
- ✅ Incomplete client data warnings
- ✅ Auto-fill client info when creating quotes
- ✅ Client history tracking

### 📦 **Product Catalog**
- ✅ **835+ Products** with optimized images
- ✅ **Fast Loading Thumbnails** - 400x400 compressed images
- ✅ **Full Resolution Screenshots** - Swipeable carousel in product details
- ✅ **Smart Search** - Find products by SKU, name, or description
- ✅ **Product Lines** - Filter by TSR, PRO, MSF, etc.
- ✅ **Detailed Specs** - View dimensions, power requirements, capacity
- ✅ **Grid/Table Views** - Choose your preferred layout
- ✅ **Price Formatting** - All prices shown with commas ($1,234.50)
- ✅ **Image Fallback System** - Always shows an image or icon

### 🛒 **Shopping Cart**
- ✅ Add/remove products with one click
- ✅ Adjust quantities easily
- ✅ Persistent cart (saves between sessions)
- ✅ Running total with tax calculation
- ✅ **Collapsible Order Summary** (starts collapsed)
- ✅ **Collapsible Comments Section** (starts collapsed)
- ✅ Discount calculation (percentage or fixed amount)
- ✅ Quick convert to quote
- ✅ Clear all functionality

### 📋 **Quote Management**
- ✅ **Create Quotes** from cart or scratch
- ✅ **Edit Quotes** - Modify items and quantities
- ✅ **Delete Quotes** with confirmation
- ✅ **Quote Status** - Draft, Sent, Accepted, Rejected
- ✅ **Quote History** - Track all changes
- ✅ **Enhanced Search** - Search by quote #, date, company, contact, email, phone, address
- ✅ **Smart Filters** - Filter by status (Draft/Sent)
- ✅ **Duplicate Quotes** - Copy existing quotes
- ✅ **Product Thumbnails** - Visual product identification

### 📧 **Email System**
- ✅ **Send Quotes via Email** with one click
- ✅ **PDF Attachments** - Professional formatted quotes
- ✅ **Excel Attachments** - Spreadsheet format option
- ✅ **Custom Messages** - Personalize email content
- ✅ **Email Templates** - Consistent professional format
- ✅ **Delivery Confirmation** - Track sent emails

### 📄 **Export Options**
- ✅ **PDF Export** - Professional quote documents
- ✅ **Excel Export** - Spreadsheet with formulas
- ✅ **Batch Export** - Multiple quotes at once
- ✅ **Custom Branding** - Company logo and colors

### 👤 **User Profiles & Roles**

#### **Super Admin**
- Full system access
- Excel import for products
- User management
- System configuration
- Database management

#### **Admin/Sales**
- Create and manage quotes
- Full client access
- Product catalog access
- Email capabilities
- Report generation

#### **Distributor**
- View products and pricing
- Create quotes for customers
- Manage own clients
- Limited admin features

### 🔄 **Offline Functionality**
- ✅ **100% Offline Capable** - Full functionality without internet
- ✅ **Automatic Sync** - Updates when connection restored
- ✅ **Conflict Resolution** - Smart handling of simultaneous edits
- ✅ **Queue Management** - Actions saved and processed when online
- ✅ **Local Storage** - 100MB cache for fast access

### 🎨 **User Interface Features**
- ✅ **Responsive Design** - Adapts to any screen size
- ✅ **Dark/Light Themes** - Choose your preference
- ✅ **Accessibility** - Large text options, high contrast
- ✅ **Multi-Language** - English and Spanish
- ✅ **Keyboard Shortcuts** - Power user features
- ✅ **Touch Optimized** - Works great on tablets

### 📊 **Admin Panel**
- ✅ Product management
- ✅ Bulk Excel import/export
- ✅ User activity logs
- ✅ System health monitoring
- ✅ Database backup/restore
- ✅ Email configuration

## 🔒 Security Features

### Enhanced Security (v1.2.1 - December 2024)
- ✅ **CSRF Protection** - Prevents cross-site request forgery attacks
- ✅ **Rate Limiting** - API throttling to prevent abuse
- ✅ **Input Validation** - Comprehensive sanitization against SQL injection & XSS
- ✅ **Secure Logging** - PII redaction and encrypted audit trails
- ✅ **Role-Based Access Control (RBAC)** - Granular permission system
- ✅ **Environment Variables** - All secrets stored securely
- ✅ **Firebase Security Rules** - Database-level access control
- ✅ **HTTPS Only** - Encrypted data transmission
- ✅ **Auto-Logout** - Session timeout for security
- ✅ **Password Reset Flow** - Secure email-based recovery

### Security Best Practices
- Never commit `.env` files or API keys
- All sensitive files are gitignored
- Regular security audits performed
- Content Security Policy headers implemented
- Database rules enforce user isolation

## 🔧 Technical Setup (For IT Staff)

### Prerequisites
```bash
# Required Software
- Flutter SDK 3.0+
- Dart SDK 2.19+
- Firebase CLI
- Git
- VS Code or Android Studio
```

### Installation Steps

1. **Clone Repository**
```bash
git clone https://github.com/REDXICAN/TAQuotes.git
cd TAQuotes
```

2. **Install Dependencies**
```bash
flutter pub get
```

3. **Configure Environment**
Create `.env` file in root:
```env
ADMIN_EMAIL=andres@turboairmexico.com
ADMIN_PASSWORD=your_secure_password
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=your_app_password
FIREBASE_PROJECT_ID=taquotes
FIREBASE_DATABASE_URL=https://taquotes-default-rtdb.firebaseio.com
```

4. **Run Application**
```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios

# Windows
flutter run -d windows
```

### Building for Production

```bash
# Web (with optimizations)
flutter build web --release --web-renderer html

# Android
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release
```

### Deployment

**Web Hosting (Firebase)**
```bash
firebase login
firebase init hosting
flutter build web --release
firebase deploy --only hosting
```

## 📋 Current Status

### ✅ Completed Features
- [x] Full CRUD operations for all entities
- [x] Email with PDF/Excel attachments
- [x] Offline synchronization
- [x] Role-based access control
- [x] Product image management (1000+ SKUs)
- [x] Responsive design for all devices
- [x] Price formatting with commas
- [x] Product type filtering tabs
- [x] Navigation menu (Home, Clients, Products, Cart, Quotes, Profile)

### 🚧 Known Limitations
- Email attachments limited to 25MB
- Excel import max 10,000 products at once
- Offline cache limited to 100MB
- Maximum 5 concurrent users per account

## 🛡️ Security Features

- **Firebase Authentication** - Secure login system
- **Role-Based Access** - Users only see what they should
- **Data Encryption** - All data encrypted in transit
- **Secure Storage** - Sensitive data never stored in plain text
- **Session Management** - Auto-logout after inactivity
- **Audit Logs** - Track all important actions

## 📞 Support & Troubleshooting

### Common Issues & Solutions

**Can't Login?**
- Check internet connection
- Verify email and password
- Clear browser cache (Ctrl+Shift+R)
- Try incognito/private mode

**Products Not Loading?**
- Refresh the page
- Check if logged in
- Clear app cache in settings

**Email Not Sending?**
- Verify recipient email address
- Check attachment size (<25MB)
- Ensure internet connection

**Offline Not Working?**
- Enable offline mode in settings
- Ensure app was online at least once
- Check available storage space

### Contact Support
- **Email**: andres@turboairmexico.com
- **Phone**: (Support phone number)
- **Hours**: Monday-Friday 9AM-5PM CST

## ✅ What's Working Perfectly (December 2024)

### Core Features - 100% Functional
- **Image Display**: SimpleImageWidget handles all thumbnails and screenshots flawlessly
- **Cart Screen**: Collapsible sections, client selection, real-time calculations
- **Quotes Screen**: Enhanced search across all fields, status filters, PDF/Excel export
- **Client Management**: Case-insensitive partial search, full CRUD operations
- **Products Screen**: Real-time updates, lazy loading (24 initial, +12 on scroll)
- **Email System**: PDF attachments, Excel attachments, custom messages
- **Offline Mode**: 100% functionality with automatic sync when reconnected

### UI/UX Improvements
- **Collapsible Sections**: Order Summary and Comments in cart start collapsed
- **Enhanced Search**: Quotes searchable by date, all client fields
- **Performance**: Products load immediately without refresh needed
- **Responsive Design**: Works perfectly on mobile, tablet, and desktop

## 🔄 Version History

### Version 1.2.1 (Current - December 2024)
- Made Order Summary and Comments collapsible in cart
- Enhanced quotes search to include all client fields and dates
- Fixed thumbnails across all screens using SimpleImageWidget
- Resolved products screen reload issue
- Confirmed client search uses case-insensitive partial matching

### Version 1.2.0 (August 2024)
- Added product type filtering tabs
- Implemented price comma formatting
- Fixed Excel attachment functionality
- Improved navigation menu order
- Enhanced offline capabilities

### Version 1.1.0
- Added Excel import/export
- Implemented role management
- Enhanced email templates
- Fixed sync issues

### Version 1.0.0
- Initial release
- Core functionality
- Basic CRUD operations

## 📜 License & Credits

**Developed for**: Turbo Air Mexico  
**Lead Developer**: Andres (andres@turboairmexico.com)  
**Technology**: Flutter, Firebase, Dart  
**Last Updated**: December 2024  

---

### 🎉 Fun Facts
- Serves 500+ sales representatives
- Processes 1000+ quotes monthly
- 99.9% uptime since launch
- Saves 10 hours per week per user
- Available in 2 languages

---

## ⚠️ FINAL REMINDER FOR DEVELOPERS

**This application is LIVE IN PRODUCTION at https://taquotes.web.app**

Before pushing ANY changes:
1. ✅ All 835 products still load with specifications
2. ✅ Cart functionality works (add, remove, select client)
3. ✅ Quotes can be created and sent via email with PDF
4. ✅ Offline mode syncs when reconnected
5. ✅ All images display correctly
6. ✅ Authentication and user roles work
7. ✅ No database fields were renamed or removed
8. ✅ No static service patterns were changed to instance methods

**Remember**: Every feature currently works. Your job is to ADD or FIX, never to REMOVE or BREAK.

---

**Need Help?** Don't hesitate to reach out to support. We're here to help you succeed! 🚀