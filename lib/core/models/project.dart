import 'package:flutter/foundation.dart';
import 'models.dart';

@immutable
class Project {
  final String id;
  final String name;
  final String? clientId;
  final String? clientName;
  final String address;
  final List<String> productLines; // Product categories client is interested in
  final String status; // planning, active, completed, on-hold
  final String? description;
  final double? estimatedValue;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? completionDate;
  final String? salesRepId;
  final String? salesRepName;
  final Map<String, dynamic>? additionalInfo;

  const Project({
    required this.id,
    required this.name,
    this.clientId,
    this.clientName,
    required this.address,
    required this.productLines,
    required this.status,
    this.description,
    this.estimatedValue,
    required this.createdAt,
    this.startDate,
    this.completionDate,
    this.salesRepId,
    this.salesRepName,
    this.additionalInfo,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      clientId: json['clientId'] ?? json['client_id'],
      clientName: json['clientName'] ?? json['client_name'],
      address: json['address'] ?? '',
      productLines: (json['productLines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] ?? 'planning',
      description: json['description'],
      estimatedValue: (json['estimatedValue'] as num?)?.toDouble(),
      createdAt: safeParseDateTimeWithFallback(json['createdAt'] ?? json['created_at']),
      startDate: safeParseDateTimeOrNull(json['startDate'] ?? json['start_date']),
      completionDate: safeParseDateTimeOrNull(json['completionDate'] ?? json['completion_date']),
      salesRepId: json['salesRepId'] ?? json['sales_rep_id'],
      salesRepName: json['salesRepName'] ?? json['sales_rep_name'],
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clientId': clientId,
      'clientName': clientName,
      'address': address,
      'productLines': productLines,
      'status': status,
      'description': description,
      'estimatedValue': estimatedValue,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'completionDate': completionDate?.toIso8601String(),
      'salesRepId': salesRepId,
      'salesRepName': salesRepName,
      'additionalInfo': additionalInfo,
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? clientId,
    String? clientName,
    String? address,
    List<String>? productLines,
    String? status,
    String? description,
    double? estimatedValue,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? completionDate,
    String? salesRepId,
    String? salesRepName,
    Map<String, dynamic>? additionalInfo,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      address: address ?? this.address,
      productLines: productLines ?? this.productLines,
      status: status ?? this.status,
      description: description ?? this.description,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      completionDate: completionDate ?? this.completionDate,
      salesRepId: salesRepId ?? this.salesRepId,
      salesRepName: salesRepName ?? this.salesRepName,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  String get statusDisplay {
    switch (status) {
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
}