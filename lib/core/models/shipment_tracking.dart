// lib/core/models/shipment_tracking.dart
import 'models.dart';

/// Shipment tracking model for tracking product shipments
class ShipmentTracking {
  final String? id;
  final String trackingNumber;
  final String? quoteNumber;
  final String? quoteId;
  final String? orderReference;
  final String? customerName;
  final String? customerEmail;
  final String status; // In Transit, Delivered, Pending, Cancelled, etc.
  final String? carrier; // FedEx, UPS, DHL, etc.
  final String? origin;
  final String? destination;
  final String? currentLocation;
  final DateTime? shipmentDate;
  final DateTime? estimatedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<TrackingEvent> events;
  final Map<String, dynamic>? metadata; // Additional custom fields
  final String? notes;
  final List<String>? productIds;
  final double? weight;
  final String? weightUnit;
  final int? numberOfPackages;

  ShipmentTracking({
    this.id,
    required this.trackingNumber,
    this.quoteNumber,
    this.quoteId,
    this.orderReference,
    this.customerName,
    this.customerEmail,
    required this.status,
    this.carrier,
    this.origin,
    this.destination,
    this.currentLocation,
    this.shipmentDate,
    this.estimatedDeliveryDate,
    this.actualDeliveryDate,
    required this.createdAt,
    this.updatedAt,
    this.events = const [],
    this.metadata,
    this.notes,
    this.productIds,
    this.weight,
    this.weightUnit,
    this.numberOfPackages,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trackingNumber': trackingNumber,
      'quoteNumber': quoteNumber,
      'quoteId': quoteId,
      'orderReference': orderReference,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'status': status,
      'carrier': carrier,
      'origin': origin,
      'destination': destination,
      'currentLocation': currentLocation,
      'shipmentDate': shipmentDate?.toIso8601String(),
      'estimatedDeliveryDate': estimatedDeliveryDate?.toIso8601String(),
      'actualDeliveryDate': actualDeliveryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'events': events.map((e) => e.toMap()).toList(),
      'metadata': metadata,
      'notes': notes,
      'productIds': productIds,
      'weight': weight,
      'weightUnit': weightUnit,
      'numberOfPackages': numberOfPackages,
    };
  }

  factory ShipmentTracking.fromMap(Map<String, dynamic> map) {
    return ShipmentTracking(
      id: map['id'],
      trackingNumber: map['trackingNumber'] ?? map['tracking_number'] ?? '',
      quoteNumber: map['quoteNumber'] ?? map['quote_number'],
      quoteId: map['quoteId'] ?? map['quote_id'],
      orderReference: map['orderReference'] ?? map['order_reference'],
      customerName: map['customerName'] ?? map['customer_name'],
      customerEmail: map['customerEmail'] ?? map['customer_email'],
      status: map['status'] ?? 'Pending',
      carrier: map['carrier'],
      origin: map['origin'],
      destination: map['destination'],
      currentLocation: map['currentLocation'] ?? map['current_location'],
      shipmentDate: safeParseDateTimeOrNull(map['shipmentDate'] ?? map['shipment_date']),
      estimatedDeliveryDate: safeParseDateTimeOrNull(map['estimatedDeliveryDate'] ?? map['estimated_delivery_date']),
      actualDeliveryDate: safeParseDateTimeOrNull(map['actualDeliveryDate'] ?? map['actual_delivery_date']),
      createdAt: safeParseDateTimeWithFallback(map['createdAt'] ?? map['created_at']),
      updatedAt: safeParseDateTimeOrNull(map['updatedAt'] ?? map['updated_at']),
      events: (map['events'] as List<dynamic>?)
          ?.map((e) => TrackingEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList() ?? [],
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
      notes: map['notes'],
      productIds: (map['productIds'] ?? map['product_ids']) != null
          ? List<String>.from(map['productIds'] ?? map['product_ids'])
          : null,
      weight: map['weight']?.toDouble(),
      weightUnit: map['weightUnit'] ?? map['weight_unit'],
      numberOfPackages: map['numberOfPackages'] ?? map['number_of_packages'],
    );
  }

  // Helper methods
  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isInTransit => status.toLowerCase() == 'in transit' || status.toLowerCase() == 'in_transit';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  /// Calculate days since shipment
  int? get daysSinceShipment {
    if (shipmentDate == null) return null;
    return DateTime.now().difference(shipmentDate!).inDays;
  }

  /// Calculate days until estimated delivery
  int? get daysUntilDelivery {
    if (estimatedDeliveryDate == null) return null;
    return estimatedDeliveryDate!.difference(DateTime.now()).inDays;
  }

  /// Check if shipment is delayed
  bool get isDelayed {
    if (estimatedDeliveryDate == null || isDelivered) return false;
    return DateTime.now().isAfter(estimatedDeliveryDate!);
  }

  factory ShipmentTracking.fromJson(Map<String, dynamic> json) => ShipmentTracking.fromMap(json);
  String toJson() => toMap().toString();
}

/// Tracking event for shipment timeline
class TrackingEvent {
  final String status;
  final String location;
  final DateTime timestamp;
  final String? description;
  final String? eventCode;

  TrackingEvent({
    required this.status,
    required this.location,
    required this.timestamp,
    this.description,
    this.eventCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'eventCode': eventCode,
    };
  }

  factory TrackingEvent.fromMap(Map<String, dynamic> map) {
    return TrackingEvent(
      status: map['status'] ?? '',
      location: map['location'] ?? '',
      timestamp: safeParseDateTimeWithFallback(map['timestamp']),
      description: map['description'],
      eventCode: map['eventCode'] ?? map['event_code'],
    );
  }
}

/// Shipment status enum for type safety
enum ShipmentStatus {
  pending,
  inTransit,
  outForDelivery,
  delivered,
  delayed,
  cancelled,
  returned,
  failed,
}

extension ShipmentStatusExtension on ShipmentStatus {
  String get displayName {
    switch (this) {
      case ShipmentStatus.pending:
        return 'Pending';
      case ShipmentStatus.inTransit:
        return 'In Transit';
      case ShipmentStatus.outForDelivery:
        return 'Out for Delivery';
      case ShipmentStatus.delivered:
        return 'Delivered';
      case ShipmentStatus.delayed:
        return 'Delayed';
      case ShipmentStatus.cancelled:
        return 'Cancelled';
      case ShipmentStatus.returned:
        return 'Returned';
      case ShipmentStatus.failed:
        return 'Failed';
    }
  }

  static ShipmentStatus fromString(String status) {
    final normalized = status.toLowerCase().replaceAll(' ', '');
    switch (normalized) {
      case 'intransit':
      case 'shipped':
      case 'shipping':
        return ShipmentStatus.inTransit;
      case 'outfordelivery':
        return ShipmentStatus.outForDelivery;
      case 'delivered':
        return ShipmentStatus.delivered;
      case 'delayed':
        return ShipmentStatus.delayed;
      case 'cancelled':
      case 'canceled':
        return ShipmentStatus.cancelled;
      case 'returned':
        return ShipmentStatus.returned;
      case 'failed':
        return ShipmentStatus.failed;
      default:
        return ShipmentStatus.pending;
    }
  }
}
