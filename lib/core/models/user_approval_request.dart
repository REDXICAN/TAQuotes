import 'package:flutter/foundation.dart';
import 'models.dart';

@immutable
class UserApprovalRequest {
  final String id;
  final String userId;
  final String email;
  final String name;
  final String requestedRole; // 'admin', 'sales', 'distributor'
  final DateTime requestedAt;
  final String status; // 'pending', 'approved', 'rejected'
  final String? processedBy;
  final DateTime? processedAt;
  final String? rejectionReason;
  final String? approvalToken; // Unique token for email approval
  final String? company;
  final String? phone;

  const UserApprovalRequest({
    required this.id,
    required this.userId,
    required this.email,
    required this.name,
    required this.requestedRole,
    required this.requestedAt,
    required this.status,
    this.processedBy,
    this.processedAt,
    this.rejectionReason,
    this.approvalToken,
    this.company,
    this.phone,
  });

  factory UserApprovalRequest.fromJson(Map<String, dynamic> json) {
    return UserApprovalRequest(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      requestedRole: json['requestedRole'] ?? 'distributor',
      requestedAt: safeParseDateTimeWithFallback(json['requestedAt'] ?? json['requested_at']),
      status: json['status'] ?? 'pending',
      processedBy: json['processedBy'] ?? json['processed_by'],
      processedAt: safeParseDateTimeOrNull(json['processedAt'] ?? json['processed_at']),
      rejectionReason: json['rejectionReason'] ?? json['rejection_reason'],
      approvalToken: json['approvalToken'] ?? json['approval_token'],
      company: json['company'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'email': email,
      'name': name,
      'requestedRole': requestedRole,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status,
      'processedBy': processedBy,
      'processedAt': processedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'approvalToken': approvalToken,
      'company': company,
      'phone': phone,
    };
  }

  String get displayRole {
    switch (requestedRole.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return 'Administrator';
      case 'sales':
        return 'Sales Representative';
      case 'distribution':
      case 'distributor':
        return 'Distributor';
      default:
        return requestedRole;
    }
  }

  UserApprovalRequest copyWith({
    String? id,
    String? userId,
    String? email,
    String? name,
    String? requestedRole,
    DateTime? requestedAt,
    String? status,
    String? processedBy,
    DateTime? processedAt,
    String? rejectionReason,
    String? approvalToken,
    String? company,
    String? phone,
  }) {
    return UserApprovalRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      requestedRole: requestedRole ?? this.requestedRole,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      processedBy: processedBy ?? this.processedBy,
      processedAt: processedAt ?? this.processedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvalToken: approvalToken ?? this.approvalToken,
      company: company ?? this.company,
      phone: phone ?? this.phone,
    );
  }
}