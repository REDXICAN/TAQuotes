// lib/core/services/tracking_service.dart
import 'package:firebase_database/firebase_database.dart';
import '../models/shipment_tracking.dart';
import 'app_logger.dart';

/// Service for managing shipment tracking data in Firebase
class TrackingService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Database path
  static const String _trackingPath = 'tracking';

  /// Get all shipment trackings
  Stream<List<ShipmentTracking>> getTrackingsStream() {
    return _database.ref(_trackingPath).onValue.map((event) {
      try {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <ShipmentTracking>[];
        }

        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final trackings = <ShipmentTracking>[];

        data.forEach((key, value) {
          try {
            final trackingData = Map<String, dynamic>.from(value as Map);
            trackingData['id'] = key;
            trackings.add(ShipmentTracking.fromMap(trackingData));
          } catch (e) {
            AppLogger.error('Error parsing tracking $key',
              error: e, category: LogCategory.data);
          }
        });

        // Sort by created date (newest first)
        trackings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return trackings;
      } catch (e) {
        AppLogger.error('Error loading trackings stream',
          error: e, category: LogCategory.data);
        return <ShipmentTracking>[];
      }
    });
  }

  /// Get shipment tracking by ID
  Future<ShipmentTracking?> getTracking(String trackingId) async {
    try {
      final snapshot = await _database.ref('$_trackingPath/$trackingId').get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = trackingId;

      return ShipmentTracking.fromMap(data);
    } catch (e) {
      AppLogger.error('Error loading tracking $trackingId',
        error: e, category: LogCategory.data);
      return null;
    }
  }

  /// Get trackings by quote number
  Future<List<ShipmentTracking>> getTrackingsByQuote(String quoteNumber) async {
    try {
      final snapshot = await _database
          .ref(_trackingPath)
          .orderByChild('quoteNumber')
          .equalTo(quoteNumber)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final trackings = <ShipmentTracking>[];

      data.forEach((key, value) {
        try {
          final trackingData = Map<String, dynamic>.from(value as Map);
          trackingData['id'] = key;
          trackings.add(ShipmentTracking.fromMap(trackingData));
        } catch (e) {
          AppLogger.error('Error parsing tracking for quote $quoteNumber',
            error: e, category: LogCategory.data);
        }
      });

      return trackings;
    } catch (e) {
      AppLogger.error('Error loading trackings for quote $quoteNumber',
        error: e, category: LogCategory.data);
      return [];
    }
  }

  /// Search trackings by tracking number
  Future<ShipmentTracking?> searchByTrackingNumber(String trackingNumber) async {
    try {
      final snapshot = await _database
          .ref(_trackingPath)
          .orderByChild('trackingNumber')
          .equalTo(trackingNumber)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (data.isEmpty) return null;

      // Get first matching tracking
      final firstKey = data.keys.first;
      final trackingData = Map<String, dynamic>.from(data[firstKey] as Map);
      trackingData['id'] = firstKey;

      return ShipmentTracking.fromMap(trackingData);
    } catch (e) {
      AppLogger.error('Error searching tracking number $trackingNumber',
        error: e, category: LogCategory.data);
      return null;
    }
  }

  /// Create new shipment tracking
  Future<String> createTracking(ShipmentTracking tracking) async {
    try {
      final ref = _database.ref(_trackingPath).push();
      final trackingData = tracking.toMap();
      trackingData['createdAt'] = DateTime.now().millisecondsSinceEpoch;
      trackingData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await ref.set(trackingData);

      AppLogger.info('Created tracking ${ref.key}',
        category: LogCategory.business);

      return ref.key!;
    } catch (e) {
      AppLogger.error('Error creating tracking',
        error: e, category: LogCategory.data);
      rethrow;
    }
  }

  /// Update existing shipment tracking
  Future<void> updateTracking(String trackingId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await _database.ref('$_trackingPath/$trackingId').update(updates);

      AppLogger.info('Updated tracking $trackingId',
        category: LogCategory.business);
    } catch (e) {
      AppLogger.error('Error updating tracking $trackingId',
        error: e, category: LogCategory.data);
      rethrow;
    }
  }

  /// Delete shipment tracking
  Future<void> deleteTracking(String trackingId) async {
    try {
      await _database.ref('$_trackingPath/$trackingId').remove();

      AppLogger.info('Deleted tracking $trackingId',
        category: LogCategory.business);
    } catch (e) {
      AppLogger.error('Error deleting tracking $trackingId',
        error: e, category: LogCategory.data);
      rethrow;
    }
  }

  /// Add tracking event to existing shipment
  Future<void> addTrackingEvent(String trackingId, TrackingEvent event) async {
    try {
      final tracking = await getTracking(trackingId);
      if (tracking == null) {
        throw Exception('Tracking $trackingId not found');
      }

      final events = List<TrackingEvent>.from(tracking.events);
      events.add(event);

      await updateTracking(trackingId, {
        'events': events.map((e) => e.toMap()).toList(),
        'currentLocation': event.location,
        'status': event.status,
      });

      AppLogger.info('Added event to tracking $trackingId',
        category: LogCategory.business);
    } catch (e) {
      AppLogger.error('Error adding event to tracking $trackingId',
        error: e, category: LogCategory.data);
      rethrow;
    }
  }

  /// Bulk import tracking data from Excel/CSV
  Future<Map<String, dynamic>> bulkImportTrackings(List<Map<String, dynamic>> trackingsData) async {
    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    try {
      for (var i = 0; i < trackingsData.length; i++) {
        try {
          final trackingData = trackingsData[i];

          // Check if tracking number already exists
          final existingTracking = await searchByTrackingNumber(
            trackingData['trackingNumber'] ?? trackingData['tracking_number'] ?? ''
          );

          if (existingTracking != null) {
            // Update existing tracking
            await updateTracking(existingTracking.id!, trackingData);
          } else {
            // Create new tracking
            final tracking = ShipmentTracking.fromMap(trackingData);
            await createTracking(tracking);
          }

          successCount++;
        } catch (e) {
          errorCount++;
          errors.add('Row ${i + 1}: ${e.toString()}');
          AppLogger.error('Error importing tracking row ${i + 1}',
            error: e, category: LogCategory.data);
        }
      }

      AppLogger.info('Bulk import completed: $successCount success, $errorCount errors',
        category: LogCategory.business);

      return {
        'success': successCount,
        'errors': errorCount,
        'errorDetails': errors,
      };
    } catch (e) {
      AppLogger.error('Error in bulk import',
        error: e, category: LogCategory.data);
      rethrow;
    }
  }

  /// Get tracking statistics
  Future<Map<String, dynamic>> getTrackingStats() async {
    try {
      final snapshot = await _database.ref(_trackingPath).get();

      if (!snapshot.exists || snapshot.value == null) {
        return {
          'total': 0,
          'inTransit': 0,
          'delivered': 0,
          'pending': 0,
          'delayed': 0,
        };
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int total = data.length;
      int inTransit = 0;
      int delivered = 0;
      int pending = 0;
      int delayed = 0;

      data.forEach((key, value) {
        try {
          final trackingData = Map<String, dynamic>.from(value as Map);
          trackingData['id'] = key;
          final tracking = ShipmentTracking.fromMap(trackingData);

          if (tracking.isInTransit) inTransit++;
          if (tracking.isDelivered) delivered++;
          if (tracking.isPending) pending++;
          if (tracking.isDelayed) delayed++;
        } catch (e) {
          AppLogger.error('Error parsing tracking stats',
            error: e, category: LogCategory.data);
        }
      });

      return {
        'total': total,
        'inTransit': inTransit,
        'delivered': delivered,
        'pending': pending,
        'delayed': delayed,
      };
    } catch (e) {
      AppLogger.error('Error getting tracking stats',
        error: e, category: LogCategory.data);
      return {
        'total': 0,
        'inTransit': 0,
        'delivered': 0,
        'pending': 0,
        'delayed': 0,
      };
    }
  }

  /// Clear all tracking data (admin only - use with caution)
  Future<void> clearAllTrackings() async {
    try {
      await _database.ref(_trackingPath).remove();
      AppLogger.info('Cleared all tracking data',
        category: LogCategory.business);
    } catch (e) {
      AppLogger.error('Error clearing tracking data',
        error: e, category: LogCategory.data);
      rethrow;
    }
  }
}
