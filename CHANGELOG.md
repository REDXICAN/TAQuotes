# Changelog

All notable changes to the TAQuotes project will be documented in this file.

## [1.5.0] - 2024-12-09

### Added
- **Spare Parts Management System**
  - New dedicated spare parts screen with 525 items
  - Search and filter by SKU, name, and warehouse
  - Integration with cart and quote system
  - Real-time stock tracking across 14 warehouses
  - Auto-add to cart with plus/minus buttons
  - 0-based quantity system (starts at 0, not 1)

- **Stock Management Integration**
  - Products updated with real-time stock from Excel (10,112 total units)
  - Warehouse distribution tracking (CA, CA1-4, PU, SI, MEE, COCZ, COPZ, XCA, XPU, 999)
  - Stock-based sorting (highest quantity first)
  - Visual stock indicators on product cards
  - Stock display on product cards

- **Quote Status Management**
  - Manual status selection via dropdown (Draft, Sent, Accepted, Rejected)
  - Automatic status updates when exporting PDF/Excel
  - Visual color indicators for different statuses

### Fixed
- Real-time data loading issues (added autoDispose and keepSynced)
- Cart not displaying spare parts correctly
- User/Profile synchronization (fixed orphaned profiles)
- Database security rules for spare parts access

### Changed
- Quantity system now starts at 0 (was 1)
- Plus/minus buttons auto-update cart without confirmation
- Products sorted by stock quantity instead of alphabetically
- Cart updates existing items instead of creating duplicates

### Technical
- Added Firebase security rules for spareparts node
- Implemented StreamProvider.autoDispose for better memory management
- Added keepSynced(true) for critical data nodes
- Created Python scripts for stock data processing
- Database backup system with timestamps

## [1.4.0] - 2024-08-15

### Added
- Migrated 3,534 product images to Firebase Storage
- Firebase Storage URLs in database (thumbnailUrl, imageUrl, imageUrl2)
- P.2 screenshot support in product detail pages

### Fixed
- Thumbnails not displaying in production (Flutter web asset limitation)
- Image loading with CDN fallback to local assets

## [1.3.0] - 2024-12-01

### Added
- Comprehensive security enhancements
- CSRF protection and rate limiting
- Enhanced logging with security audit trails
- Input validation service

### Fixed
- Login screen logo rendering issue
- Enhanced Firebase security rules

## [1.2.1] - 2024-11-15

### Changed
- Made Order Summary collapsible in cart (starts collapsed)
- Made Comments section collapsible in cart
- Enhanced quotes search to include all client fields
- Products screen loads immediately without refresh

### Fixed
- Home screen thumbnails not displaying
- Quote detail screen thumbnails
- Products screen reload issue

## [1.2.0] - 2024-08-01

### Added
- Product type filtering tabs
- Price comma formatting
- Excel attachment functionality
- Toggle switches for client selection

### Fixed
- Quote editing functionality
- Offline synchronization issues

## [1.1.0] - 2024-07-15

### Added
- Excel import/export functionality
- Role management system
- Enhanced email templates

### Fixed
- Sync issues with offline mode

## [1.0.0] - 2024-07-01

### Initial Release
- Core product catalog with 835+ products
- Client management system
- Quote creation and management
- Shopping cart functionality
- PDF export with attachments
- Email integration with Gmail SMTP
- Offline mode with sync
- Firebase Authentication
- Real-time database synchronization