import 'package:flutter/foundation.dart';
import 'models.dart';

/// Project Model - Tracks client projects for sales representatives
///
/// Simplified model focusing on essential information:
/// - Project name and location
/// - Person in charge (name, phone, email)
/// - Client relationship
/// - Product lines/categories
/// - Status tracking
/// - Estimated value and dates
///
/// Design Decision: Keep model simple and flat for easy maintenance
/// Avoid nested objects and complex computed fields
@immutable
class Project {
  // ========== CORE INFORMATION ==========

  /// Unique project identifier (Firebase push key)
  final String id;

  /// Project name (e.g., "Hotel Kitchen Renovation")
  final String name;

  /// User ID of project owner (sales representative)
  final String userId;

  // ========== CLIENT RELATIONSHIP ==========

  /// Reference to client in /clients/{userId}/{clientId}
  final String clientId;

  /// Client company name (denormalized for quick display)
  final String clientName;

  // ========== LOCATION ==========

  /// Simple location string (e.g., "Cancún, Quintana Roo")
  /// Design Decision: Single string is sufficient, no need for complex address object
  final String location;

  // ========== PERSON IN CHARGE (ON-SITE CONTACT) ==========

  /// Name of person in charge at project location
  /// Example: "Carlos Mendoza" or "Head Chef - Carlos Mendoza"
  final String personInCharge;

  /// Contact phone number (optional)
  /// Example: "+52-998-123-4567"
  final String? phone;

  /// Contact email address (optional)
  /// Example: "carlos.mendoza@hilton.com"
  final String? email;

  // ========== PRODUCT CATEGORIES ==========

  /// List of product lines/categories for this project
  /// Examples: "Refrigeration", "Freezers", "Prep Tables", "Ice Machines"
  final List<String> productLines;

  // ========== STATUS & PROGRESS ==========

  /// Current project status
  /// Values: 'planning', 'active', 'completed', 'on-hold'
  final String status;

  // ========== FINANCIAL ==========

  /// Estimated project value in USD (optional)
  final double? estimatedValue;

  // ========== DATES ==========

  /// When project was created
  final DateTime createdAt;

  /// Planned start date (optional)
  final DateTime? startDate;

  /// Planned or actual completion date (optional)
  final DateTime? completionDate;

  // ========== ADDITIONAL ==========

  /// Optional internal notes
  final String? notes;

  // ========== CONSTRUCTOR ==========

  const Project({
    required this.id,
    required this.name,
    required this.userId,
    required this.clientId,
    required this.clientName,
    required this.location,
    required this.personInCharge,
    this.phone,
    this.email,
    required this.productLines,
    required this.status,
    this.estimatedValue,
    required this.createdAt,
    this.startDate,
    this.completionDate,
    this.notes,
  });

  // ========== JSON SERIALIZATION ==========

  /// Create Project from Firebase JSON
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      userId: json['userId'] as String? ?? json['salesRepId'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      location: json['location'] as String? ?? json['address'] as String? ?? '',
      personInCharge: json['personInCharge'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      productLines: (json['productLines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'planning',
      estimatedValue: (json['estimatedValue'] as num?)?.toDouble(),
      createdAt: safeParseDateTimeWithFallback(
        json['createdAt'] ?? json['created_at'],
      ),
      startDate: safeParseDateTimeOrNull(
        json['startDate'] ?? json['start_date'],
      ),
      completionDate: safeParseDateTimeOrNull(
        json['completionDate'] ?? json['completion_date'],
      ),
      notes: json['notes'] as String? ?? json['description'] as String?,
    );
  }

  /// Convert Project to Firebase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'clientId': clientId,
      'clientName': clientName,
      'location': location,
      'personInCharge': personInCharge,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      'productLines': productLines,
      'status': status,
      if (estimatedValue != null) 'estimatedValue': estimatedValue,
      'createdAt': createdAt.toIso8601String(),
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (completionDate != null)
        'completionDate': completionDate!.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }

  // ========== COPY WITH ==========

  /// Create a copy with modified fields
  Project copyWith({
    String? id,
    String? name,
    String? userId,
    String? clientId,
    String? clientName,
    String? location,
    String? personInCharge,
    String? phone,
    String? email,
    List<String>? productLines,
    String? status,
    double? estimatedValue,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? completionDate,
    String? notes,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      location: location ?? this.location,
      personInCharge: personInCharge ?? this.personInCharge,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      productLines: productLines ?? this.productLines,
      status: status ?? this.status,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      completionDate: completionDate ?? this.completionDate,
      notes: notes ?? this.notes,
    );
  }

  // ========== HELPER GETTERS ==========

  /// Human-readable status display
  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'planning':
        return 'Planning';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'on-hold':
        return 'On Hold';
      default:
        return status;
    }
  }

  /// Contact info as single string for display
  /// Example: "Carlos Mendoza • +52-998-123-4567"
  String get contactInfo {
    final parts = <String>[personInCharge];
    if (phone != null && phone!.isNotEmpty) parts.add(phone!);
    if (email != null && email!.isNotEmpty) parts.add(email!);
    return parts.join(' • ');
  }

  /// Project age in days
  int get ageDays => DateTime.now().difference(createdAt).inDays;

  /// Whether project has contact phone
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// Whether project has contact email
  bool get hasEmail => email != null && email!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Project(id: $id, name: $name, status: $status)';
}
