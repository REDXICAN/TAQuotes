# Shipment Tracking System - Complete Documentation

## Overview

A comprehensive shipment tracking system integrated into the TAQuotes application. This system allows tracking of shipments associated with quotes, with support for both manual Excel upload and automated synchronization via Cloud Functions.

## Features

### Core Functionality
- Track shipments with detailed information (tracking number, status, carrier, locations, dates)
- Link shipments to quotes for complete order lifecycle visibility
- Real-time updates via Firebase Realtime Database
- Timeline view of tracking events
- Status filtering and search
- Delayed shipment alerts
- Statistics dashboard (total, in transit, delivered, pending, delayed)

### Data Management
- Manual Excel file upload with preview
- Automatic data syncing from OneDrive (optional Cloud Function)
- Bulk import with error handling
- Update existing or create new tracking records
- Data validation and mapping

### UI Components
- Dedicated tracking tab in Quotes screen
- Responsive design (mobile, tablet, desktop)
- Interactive tracking cards with status badges
- Detailed tracking dialog with event timeline
- Admin panel integration for data management

## Architecture

### File Structure
```
lib/
├── core/
│   ├── models/
│   │   ├── shipment_tracking.dart     # Data models
│   │   └── models.dart                 # Export tracking model
│   └── services/
│       └── tracking_service.dart       # Firebase operations
├── features/
│   ├── quotes/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── quotes_with_tracking_screen.dart  # Main screen with tabs
│   │       └── widgets/
│   │           └── tracking_tab_widget.dart          # Tracking UI
│   └── admin/
│       └── presentation/
│           └── widgets/
│               └── tracking_import_widget.dart       # Excel upload
```

### Database Schema

Firebase Realtime Database path: `/tracking/{trackingId}`

```json
{
  "tracking": {
    "push-id-1": {
      "trackingNumber": "1234567890",
      "quoteNumber": "Q-2025-001",
      "quoteId": "quote-id-123",
      "orderReference": "ORD-001",
      "customerName": "John Doe",
      "customerEmail": "john@example.com",
      "status": "In Transit",
      "carrier": "FedEx",
      "origin": "Cancun, Mexico",
      "destination": "Miami, FL",
      "currentLocation": "Houston, TX",
      "shipmentDate": 1735689600000,
      "estimatedDeliveryDate": 1735862400000,
      "actualDeliveryDate": null,
      "createdAt": 1735689600000,
      "updatedAt": 1735776000000,
      "events": [
        {
          "status": "Picked Up",
          "location": "Cancun, Mexico",
          "timestamp": 1735689600000,
          "description": "Package picked up by carrier"
        },
        {
          "status": "In Transit",
          "location": "Houston, TX",
          "timestamp": 1735776000000,
          "description": "Arrived at sorting facility"
        }
      ],
      "metadata": {},
      "notes": "Fragile - Handle with care",
      "productIds": ["product-1", "product-2"],
      "weight": 25.5,
      "weightUnit": "kg",
      "numberOfPackages": 3
    }
  }
}
```

## Setup Instructions

### 1. Firebase Database Rules

Add these rules to Firebase Realtime Database:

```json
{
  "rules": {
    "tracking": {
      ".read": "auth != null",
      ".write": "auth != null && (auth.token.admin == true || auth.token.email == 'andres@turboairmexico.com')",
      "$trackingId": {
        ".validate": "newData.hasChildren(['trackingNumber', 'status', 'createdAt'])"
      }
    }
  }
}
```

### 2. Update Routing (if needed)

If you want the tracking screen to be accessible via deep linking:

```dart
// In your router configuration
GoRoute(
  path: '/quotes',
  name: 'quotes',
  builder: (context, state) => const QuotesWithTrackingScreen(),
),
```

### 3. Add to Admin Panel

Edit `lib/features/admin/presentation/screens/admin_panel_screen.dart`:

Add import:
```dart
import '../widgets/tracking_import_widget.dart';
```

Add to the admin panel UI (in the appropriate section):
```dart
// In your admin panel sections
ExpansionTile(
  leading: const Icon(Icons.local_shipping),
  title: const Text('Shipment Tracking'),
  subtitle: const Text('Import and manage tracking data'),
  children: const [
    Padding(
      padding: EdgeInsets.all(16),
      child: TrackingImportWidget(),
    ),
  ],
),
```

### 4. Update Navigation

Replace `QuotesScreen` with `QuotesWithTrackingScreen` in your main navigation:

```dart
// Before
BottomNavigationBarItem(
  icon: Icon(Icons.receipt_long),
  label: 'Quotes',
)
// Routes to: QuotesScreen()

// After
BottomNavigationBarItem(
  icon: Icon(Icons.receipt_long),
  label: 'Quotes',
)
// Routes to: QuotesWithTrackingScreen()
```

## Usage Guide

### For End Users

#### Viewing Tracking Information

1. Navigate to **Quotes** screen from bottom navigation
2. Tap on the **Tracking** tab
3. View all shipments with current status
4. Use search to find specific tracking numbers or customers
5. Filter by status (All, In Transit, Delivered, Pending)
6. Toggle "Delayed Only" to see shipments past ETA

#### Viewing Detailed Tracking

1. Tap on any tracking card
2. View complete shipment details:
   - Tracking number and quote reference
   - Customer information
   - Carrier and route details
   - Dates (shipment, estimated, actual delivery)
   - Package details (weight, number of packages)
   - Notes and special instructions
3. Scroll down to view tracking history timeline
4. See all events with timestamps and locations

### For Administrators

#### Manual Excel Upload

1. Open **Admin Panel**
2. Navigate to **Shipment Tracking** section
3. Click **Download Excel Template** to get the correct format
4. Prepare your Excel file with columns:
   - Tracking Number (required)
   - Quote Number
   - Order Reference
   - Customer Name
   - Customer Email
   - Status (required)
   - Carrier
   - Origin
   - Destination
   - Current Location
   - Shipment Date
   - Estimated Delivery
   - Actual Delivery
   - Weight
   - Packages
   - Notes

5. Click **Select File** and choose your Excel file
6. Review the preview (first 5 rows)
7. Click **Import** to upload to Firebase
8. View results (success/error counts)

#### Auto-Sync Setup (Optional)

See `TRACKING_CLOUD_FUNCTION_SETUP.md` for detailed Cloud Function instructions.

Quick steps:
1. Set up Microsoft Azure App Registration
2. Configure OneDrive API access
3. Deploy Firebase Cloud Function
4. Schedule automatic sync (every 30 minutes)

## Excel File Format

### Required Columns
- **Tracking Number**: Unique shipment identifier
- **Status**: Current shipment status

### Optional Columns
- Quote Number: Link to quote
- Order Reference: Customer order number
- Customer Name: Recipient name
- Customer Email: Recipient email
- Carrier: Shipping company (FedEx, UPS, DHL, etc.)
- Origin: Starting location
- Destination: Delivery location
- Current Location: Latest known location
- Shipment Date: When package was shipped
- Estimated Delivery: Expected delivery date
- Actual Delivery: When package was delivered
- Weight: Package weight
- Packages: Number of packages
- Notes: Special instructions or comments

### Example Excel Data

| Tracking Number | Quote Number | Customer Name | Status | Carrier | Origin | Destination | Shipment Date | Estimated Delivery |
|----------------|--------------|---------------|---------|---------|---------|-------------|---------------|-------------------|
| 1234567890 | Q-2025-001 | John Doe | In Transit | FedEx | Cancun | Miami | 2025-01-01 | 2025-01-03 |
| 0987654321 | Q-2025-002 | Jane Smith | Delivered | UPS | Houston | Chicago | 2024-12-28 | 2025-01-02 |

## API Reference

### TrackingService Methods

```dart
// Get all trackings as stream
Stream<List<ShipmentTracking>> getTrackingsStream()

// Get single tracking
Future<ShipmentTracking?> getTracking(String trackingId)

// Get trackings by quote
Future<List<ShipmentTracking>> getTrackingsByQuote(String quoteNumber)

// Search by tracking number
Future<ShipmentTracking?> searchByTrackingNumber(String trackingNumber)

// Create new tracking
Future<String> createTracking(ShipmentTracking tracking)

// Update tracking
Future<void> updateTracking(String trackingId, Map<String, dynamic> updates)

// Delete tracking
Future<void> deleteTracking(String trackingId)

// Add event to tracking
Future<void> addTrackingEvent(String trackingId, TrackingEvent event)

// Bulk import from Excel
Future<Map<String, dynamic>> bulkImportTrackings(List<Map<String, dynamic>> data)

// Get statistics
Future<Map<String, dynamic>> getTrackingStats()
```

### Example Usage

```dart
// Initialize service
final trackingService = TrackingService();

// Create new tracking
final tracking = ShipmentTracking(
  trackingNumber: '1234567890',
  quoteNumber: 'Q-2025-001',
  customerName: 'John Doe',
  status: 'In Transit',
  carrier: 'FedEx',
  shipmentDate: DateTime.now(),
  estimatedDeliveryDate: DateTime.now().add(Duration(days: 3)),
  createdAt: DateTime.now(),
);

final trackingId = await trackingService.createTracking(tracking);

// Add tracking event
final event = TrackingEvent(
  status: 'Arrived at facility',
  location: 'Houston, TX',
  timestamp: DateTime.now(),
  description: 'Package arrived at sorting facility',
);

await trackingService.addTrackingEvent(trackingId, event);

// Search for tracking
final found = await trackingService.searchByTrackingNumber('1234567890');
print('Status: ${found?.status}');
```

## Status Values

Standard status values (case-insensitive):
- **Pending**: Shipment created but not yet picked up
- **In Transit** / **Shipped** / **Shipping**: Package is on the way
- **Out for Delivery**: Package is with delivery driver
- **Delivered**: Successfully delivered
- **Delayed**: Past estimated delivery date
- **Cancelled** / **Canceled**: Shipment cancelled
- **Returned**: Package returned to sender
- **Failed**: Delivery attempt failed

## Providers

### trackingServiceProvider
```dart
final trackingServiceProvider = Provider<TrackingService>((ref) {
  return TrackingService();
});
```

### trackingsStreamProvider
```dart
final trackingsStreamProvider = StreamProvider.autoDispose<List<ShipmentTracking>>((ref) {
  final service = ref.watch(trackingServiceProvider);
  return service.getTrackingsStream();
});
```

### trackingStatsProvider
```dart
final trackingStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.watch(trackingServiceProvider);
  return await service.getTrackingStats();
});
```

## Troubleshooting

### Common Issues

**1. No data showing in Tracking tab**
- Check Firebase Database rules allow read access
- Verify tracking data exists at `/tracking` path
- Check console for errors
- Ensure user is authenticated

**2. Excel upload fails**
- Verify Excel file is .xlsx format
- Check required columns exist (Tracking Number, Status)
- Ensure no empty rows
- Check file size (< 10MB recommended)

**3. Import succeeds but records not visible**
- Refresh the page
- Check Firebase Console to verify data
- Verify tracking numbers are unique
- Check provider invalidation

**4. Delayed status not showing**
- Ensure Estimated Delivery date is set
- Check date format is valid
- Verify current date is after estimated delivery

**5. Tracking details dialog not opening**
- Check for console errors
- Verify tracking data is complete
- Ensure proper state management

### Debug Mode

Enable detailed logging:
```dart
// In tracking_service.dart or tracking_tab_widget.dart
AppLogger.setLogLevel(LogLevel.debug);
```

## Performance Considerations

### Optimizations Implemented
- Stream providers with autoDispose for automatic cleanup
- Pagination ready (currently loads all, can be modified)
- Indexed Firebase queries for fast searches
- Cached statistics calculations
- Lazy loading of tracking details

### Scaling Recommendations
For > 10,000 tracking records:
- Implement pagination (25-50 records per page)
- Add server-side date range filtering
- Use Firebase compound indexes
- Consider moving old records to archive

## Security

### Current Implementation
- Read access: All authenticated users
- Write access: Admin users only
- Data validation on required fields
- Tracking number uniqueness enforced
- Input sanitization in Excel parser

### Recommended Enhancements
- Row-level security (user can only see their quotes' trackings)
- Audit logs for data changes
- Rate limiting on bulk imports
- IP-based access restrictions
- Encrypted tracking numbers for sensitive shipments

## Future Enhancements

### Planned Features
- [ ] Email notifications for status changes
- [ ] SMS alerts for delivery
- [ ] Integration with carrier APIs (FedEx, UPS tracking APIs)
- [ ] QR code generation for tracking links
- [ ] Customer portal for self-service tracking
- [ ] Predictive delivery time estimation
- [ ] Geolocation tracking map view
- [ ] Export tracking reports to PDF
- [ ] Automated status updates from carrier webhooks

### API Integrations
Consider integrating with:
- **FedEx Tracking API**: Real-time status updates
- **UPS Tracking API**: Automated event logging
- **DHL Express API**: International shipment tracking
- **ShipEngine**: Multi-carrier tracking aggregation
- **EasyPost**: Unified tracking across carriers

## Support

### Documentation
- Main docs: `TRACKING_SYSTEM_README.md` (this file)
- Cloud Functions: `TRACKING_CLOUD_FUNCTION_SETUP.md`
- Main project: `CLAUDE.md`

### Contact
- **Project Lead**: andres@turboairmexico.com
- **Support Email**: turboairquotes@gmail.com
- **GitHub**: https://github.com/REDXICAN/TAQuotes

### Reporting Issues
Include:
1. Steps to reproduce
2. Expected vs actual behavior
3. Browser/device information
4. Console error messages
5. Sample tracking data (if applicable)

## License

This tracking system is part of TAQuotes and follows the same license terms as the main application.

---

**Version**: 1.0.0
**Last Updated**: January 2025
**Status**: Production Ready
