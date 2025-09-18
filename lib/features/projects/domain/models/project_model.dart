class Project {
  final String? id;
  final String projectName;
  final String clientId;
  final String? clientName; // For display purposes
  final List<String> productLines;
  final String address;
  final String status; // planning, active, completed, on-hold
  final double estimatedValue;
  final DateTime startDate;
  final DateTime? completionDate;
  final String salesRepId;
  final String? salesRepName; // For display purposes
  final String? description;
  final DateTime createdAt;
  final String createdBy;

  Project({
    this.id,
    required this.projectName,
    required this.clientId,
    this.clientName,
    required this.productLines,
    required this.address,
    required this.status,
    required this.estimatedValue,
    required this.startDate,
    this.completionDate,
    required this.salesRepId,
    this.salesRepName,
    this.description,
    required this.createdAt,
    required this.createdBy,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      projectName: json['projectName'] ?? '',
      clientId: json['clientId'] ?? '',
      clientName: json['clientName'],
      productLines: List<String>.from(json['productLines'] ?? []),
      address: json['address'] ?? '',
      status: json['status'] ?? 'planning',
      estimatedValue: (json['estimatedValue'] ?? 0).toDouble(),
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      completionDate: json['completionDate'] != null
          ? DateTime.parse(json['completionDate'])
          : null,
      salesRepId: json['salesRepId'] ?? '',
      salesRepName: json['salesRepName'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      createdBy: json['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'projectName': projectName,
      'clientId': clientId,
      'clientName': clientName,
      'productLines': productLines,
      'address': address,
      'status': status,
      'estimatedValue': estimatedValue,
      'startDate': startDate.toIso8601String(),
      'completionDate': completionDate?.toIso8601String(),
      'salesRepId': salesRepId,
      'salesRepName': salesRepName,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  Project copyWith({
    String? id,
    String? projectName,
    String? clientId,
    String? clientName,
    List<String>? productLines,
    String? address,
    String? status,
    double? estimatedValue,
    DateTime? startDate,
    DateTime? completionDate,
    String? salesRepId,
    String? salesRepName,
    String? description,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Project(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      productLines: productLines ?? this.productLines,
      address: address ?? this.address,
      status: status ?? this.status,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      startDate: startDate ?? this.startDate,
      completionDate: completionDate ?? this.completionDate,
      salesRepId: salesRepId ?? this.salesRepId,
      salesRepName: salesRepName ?? this.salesRepName,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}