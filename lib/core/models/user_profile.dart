// lib/core/models/user_profile.dart

import 'user_role.dart';

class UserProfile {
  final String id;
  final String email;
  final String role;
  final String? company;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool _isAdminField;

  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.company,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
    bool isAdminField = false,
  }) : _isAdminField = isAdminField;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Parse timestamps - check both camelCase and snake_case
    DateTime parseTimestamp(dynamic value, String altKey) {
      // Try the primary key
      if (value != null) {
        if (value is DateTime) return value;
        if (value is String) return DateTime.parse(value);
        if (value is int || value is double) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
        if (value.runtimeType.toString().contains('Timestamp')) {
          return (value.toDate());
        }
      }
      // Try alternative key
      final altValue = json[altKey];
      if (altValue != null) {
        if (altValue is DateTime) return altValue;
        if (altValue is String) return DateTime.parse(altValue);
        if (altValue is int || altValue is double) return DateTime.fromMillisecondsSinceEpoch(altValue.toInt());
        if (altValue.runtimeType.toString().contains('Timestamp')) {
          return (altValue.toDate());
        }
      }
      return DateTime.now();
    }
    
    return UserProfile(
      id: json['id'] ?? json['uid'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'distributor',
      company: json['company'],
      phone: json['phone'] ?? json['phoneNumber'],
      createdAt: parseTimestamp(json['created_at'], 'createdAt'),
      updatedAt: parseTimestamp(json['updated_at'], 'updatedAt'),
      isAdminField: json['isAdmin'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'company': company,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'isAdmin': _isAdminField,
    };
  }

  /// Get UserRole enum from string role
  UserRole get userRole => UserRole.fromString(role);

  // Backward compatibility methods
  bool get isSuperAdmin => userRole.isSuperAdmin;
  bool get isAdmin => userRole.isAdminOrAbove || _isAdminField;
  bool get isSales => userRole == UserRole.sales || userRole.isAdminOrAbove;
  bool get isDistributor => userRole == UserRole.distributor;

  String get displayRole => userRole.displayName;

  UserProfile copyWith({
    String? id,
    String? email,
    String? role,
    String? company,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdminField,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdminField: isAdminField ?? this._isAdminField,
    );
  }
}
