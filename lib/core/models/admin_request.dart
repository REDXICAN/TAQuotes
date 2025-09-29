import 'package:flutter/foundation.dart';
import 'models.dart';

@immutable
class AdminRequest {
  final String id;
  final String userId;
  final String email;
  final String name;
  final String requestedRole;
  final DateTime requestedAt;
  final String status; // 'pending', 'approved', 'rejected'
  final String? processedBy;
  final DateTime? processedAt;
  final String? rejectionReason;
  final String? approvalToken; // Unique token for email approval

  const AdminRequest({
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
  });

  factory AdminRequest.fromJson(Map<String, dynamic> json) {
    return AdminRequest(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      requestedRole: json['requestedRole'] ?? 'admin',
      requestedAt: safeParseDateTimeWithFallback(json['requestedAt'] ?? json['requested_at']),
      status: json['status'] ?? 'pending',
      processedBy: json['processedBy'] ?? json['processed_by'],
      processedAt: safeParseDateTimeOrNull(json['processedAt'] ?? json['processed_at']),
      rejectionReason: json['rejectionReason'] ?? json['rejection_reason'],
      approvalToken: json['approvalToken'] ?? json['approval_token'],
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
    };
  }

  AdminRequest copyWith({
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
  }) {
    return AdminRequest(
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
    );
  }
}