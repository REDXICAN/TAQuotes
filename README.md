# Turbo Air Quotes (TAQ) - Flutter Application

A comprehensive B2B equipment catalog and quote management system built with Flutter and Firebase, featuring offline-first architecture, real-time synchronization, and full email integration with PDF attachments.

## 🚀 Key Features

### Core Functionality
- **Multi-Platform Support**: iOS, Android, Web, Windows, macOS
- **Offline-First Architecture**: Full functionality without internet connection
- **Real-time Sync**: Automatic data synchronization when online
- **Role-Based Access**: Admin, Sales, and Distributor roles
- **PDF Generation**: Professional quote PDFs with company branding
- **Email Integration**: Send quotes with PDF attachments via Gmail SMTP

### Business Features
- **Product Catalog**: 1000+ products with images and specifications
- **Quote Management**: Create, edit, delete, and export quotes
- **Client Management**: Full CRM with add, edit, delete functionality
- **Excel Import**: Bulk product import/update for administrators
- **Shopping Cart**: Persistent cart with real-time updates
- **Search & Filter**: Advanced product search with category filtering

## 🛠️ Technology Stack

### Frontend
- **Flutter 3.x**: Cross-platform UI framework
- **Riverpod**: State management solution
- **Hive**: Local database for offline support
- **Go Router**: Navigation and routing
- **PDF Package**: PDF generation for quotes
- **Mailer 6.0.1**: Email with attachment support

### Backend Services
- **Firebase Realtime Database**: NoSQL cloud database with real-time sync
- **Firebase Authentication**: Secure user authentication
- **Firebase Storage**: Product images and documents
- **Gmail SMTP**: Professional email delivery

### Development Tools
- **Flutter DevTools**: Performance monitoring
- **Logger**: Comprehensive logging system
- **Device Info Plus**: Device information collection
- **Connectivity Plus**: Network status monitoring

## 📁 Project Structure

```
turbo-air-quotes/
├── lib/
│   ├── main.dart                         # App entry point with Firebase init
│   ├── app.dart                          # Main application widget
│   ├── firebase_options.dart             # Firebase configuration
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart          # App constants
│   │   │   ├── env_config.dart          # Environment variables
│   │   │   └── secure_email_config.dart # Email configuration
│   │   ├── services/
│   │   │   ├── realtime_database_service.dart  # Database operations
│   │   │   ├── offline_service.dart            # Offline management
│   │   │   ├── firebase_auth_service.dart      # Authentication
│   │   │   ├── email_service.dart              # Email with PDF attachments
│   │   │   ├── export_service.dart             # PDF/Excel generation
│   │   │   ├── excel_upload_service.dart       # Excel import
│   │   │   ├── cache_manager.dart              # Cache management
│   │   │   └── app_logger.dart                 # Logging service
│   │   ├── utils/
│   │   │   ├── product_image_helper.dart       # Product image mapping
│   │   │   └── responsive_helper.dart          # Responsive utilities
│   │   └── widgets/
│   │       ├── offline_status_widget.dart      # Connection indicator
│   │       └── offline_queue_widget.dart       # Sync queue display
│   ├── features/
│   │   ├── auth/                        # Authentication screens
│   │   ├── products/                    # Product catalog
│   │   ├── clients/                     # Client management
│   │   ├── cart/                        # Shopping cart
│   │   ├── quotes/                      # Quote management
│   │   ├── admin/                       # Admin panel
│   │   ├── home/                        # Dashboard
│   │   └── profile/                     # User profile
│   └── assets/
│       └── screenshots/                  # Product images (1000+ SKUs)
├── android/                             # Android configuration
├── ios/                                 # iOS configuration
├── web/                                 # Web configuration
├── windows/                             # Windows configuration
├── .env                                 # Environment variables (git-ignored)
├── .gitignore                           # Git ignore configuration
├── pubspec.yaml                         # Dependencies
├── firebase.json                        # Firebase hosting config
└── database.rules.json                  # Firebase security rules
```

## 🔐 Security & Configuration

### Environment Variables
Create a `.env` file in the project root:

```env
# Admin Credentials
ADMIN_EMAIL=andres@turboairmexico.com
ADMIN_PASSWORD=secure_password_here

# Firebase Configuration
FIREBASE_PROJECT_ID=turbo-air-viewer
FIREBASE_DATABASE_URL=https://turbo-air-viewer-default-rtdb.firebaseio.com
FIREBASE_API_KEY_WEB=your_api_key
FIREBASE_AUTH_DOMAIN=turbo-air-viewer.firebaseapp.com
FIREBASE_STORAGE_BUCKET=turbo-air-viewer.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID_WEB=your_app_id

# Email Service
EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com
EMAIL_APP_PASSWORD=your_app_password
```

### Security Features
- Environment variables for sensitive data
- Firebase security rules for data access
- Role-based access control
- Secure email credentials
- Input validation and sanitization
- Error handling and logging

## 🚀 Installation & Setup

### Prerequisites
- Flutter SDK 3.0+
- Firebase CLI
- Git
- VS Code or Android Studio

### Setup Steps

1. **Clone the repository**
```bash
git clone https://github.com/REDXICAN/Turbo-Air-Viewer-Flutter-App.git
cd Turbo-Air-Viewer-Flutter-App
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure environment**
- Create `.env` file with your credentials
- Update Firebase configuration files

4. **Run the application**
```bash
# Web
flutter run -d chrome

# Mobile
flutter run

# Windows
flutter run -d windows
```

## 📱 Platform-Specific Setup

### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 33 (Android 13)
- Google Services configured

### iOS
- Minimum iOS: 11.0
- Xcode 14+ required
- Info.plist configured for network access

### Web
- Supports all modern browsers
- Responsive design for all screen sizes
- PWA capabilities enabled

## 🌐 Deployment

### Web Deployment
```bash
# Build for web
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting

# Or deploy to GitHub Pages
./deploy-github-pages.bat
```

### Mobile Deployment
```bash
# Android
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 📊 Features Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| User Authentication | ✅ Complete | Firebase Auth with roles |
| Product Catalog | ✅ Complete | 1000+ products with images |
| Client Management | ✅ Complete | Add, edit, delete functionality |
| Quote Management | ✅ Complete | Create, edit, delete, export |
| PDF Generation | ✅ Complete | Professional quote PDFs |
| Email with Attachments | ✅ Complete | PDF attachments via Gmail |
| Excel Import | ✅ Complete | Bulk product management |
| Offline Support | ✅ Complete | Full offline functionality |
| Real-time Sync | ✅ Complete | Automatic data synchronization |
| Search & Filter | ✅ Complete | Advanced product search |
| Shopping Cart | ✅ Complete | Persistent across sessions |
| Admin Panel | ✅ Complete | User and product management |

## 🔧 Recent Updates

### Version 1.0.0 (Current)
- ✅ Implemented PDF attachments in email service
- ✅ Added client edit functionality
- ✅ Implemented quote deletion
- ✅ Fixed all compilation errors
- ✅ Enhanced offline synchronization
- ✅ Improved error handling
- ✅ Updated security configuration

## 📝 API Documentation

### Email Service
```dart
// Send quote with PDF attachment
await EmailService().sendQuoteWithPDF(
  recipientEmail: 'client@example.com',
  recipientName: 'Client Name',
  quoteNumber: 'Q-2025-001',
  quoteId: 'quote_id_123',
  userInfo: userProfileData,
);
```

### Database Service
```dart
// Client operations
await dbService.addClient(clientData);
await dbService.updateClient(clientId, updatedData);
await dbService.deleteClient(clientId);

// Quote operations
await dbService.createQuote(quoteData);
await dbService.updateQuote(quoteId, updatedData);
await dbService.deleteQuote(quoteId);
```

## 🐛 Troubleshooting

### Common Issues

1. **Build Errors**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

2. **Firebase Connection**
- Verify `.env` file configuration
- Check Firebase project settings
- Ensure network connectivity

3. **Email Not Sending**
- Verify Gmail app password
- Check SMTP settings
- Enable less secure app access

## 📄 License

Proprietary software owned by Turbo Air Inc. All rights reserved.

## 🤝 Support

For technical support:
- Email: turboairquotes@gmail.com
- GitHub Issues: [Create Issue](https://github.com/REDXICAN/Turbo-Air-Viewer-Flutter-App/issues)

## 👥 Contributors

- Andres - Lead Developer (andres@turboairmexico.com)

---

© 2025 Turbo Air Inc. All rights reserved.