// lib/core/models/user_profile.dart

import 'models.dart';

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
    return UserProfile(
      id: json['id'] ?? json['uid'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'distributor',
      company: json['company'],
      phone: json['phone'] ?? json['phoneNumber'],
      createdAt: safeParseDateTimeWithFallback(json['created_at'] ?? json['createdAt']),
      updatedAt: safeParseDateTimeWithFallback(json['updated_at'] ?? json['updatedAt']),
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
      isAdminField: isAdminField ?? _isAdminField,
    );
  }
}
