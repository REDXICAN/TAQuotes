// lib/core/services/legal_documents_service.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';
import 'rbac_service.dart';
import '../utils/safe_type_converter.dart';

enum DocumentType { terms_of_service, privacy_policy, user_agreement, data_processing, cookie_policy }
enum DocumentStatus { draft, published, archived, expired }

class LegalDocument {
  final String id;
  final DocumentType type;
  final String title;
  final String content;
  final String version;
  final DocumentStatus status;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String createdBy;
  final String? updatedBy;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  LegalDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.version,
    required this.status,
    required this.createdAt,
    this.publishedAt,
    this.expiresAt,
    required this.createdBy,
    this.updatedBy,
    this.updatedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'content': content,
      'version': version,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdAtIso': createdAt.toIso8601String(),
      'publishedAt': publishedAt?.millisecondsSinceEpoch,
      'publishedAtIso': publishedAt?.toIso8601String(),
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'expiresAtIso': expiresAt?.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'updatedAtIso': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory LegalDocument.fromMap(Map<String, dynamic> map) {
    return LegalDocument(
      id: map['id'] ?? '',
      type: DocumentType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => DocumentType.terms_of_service,
      ),
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      version: map['version'] ?? '1.0',
      status: DocumentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => DocumentStatus.draft,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      publishedAt: map['publishedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['publishedAt'])
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'])
          : null,
      createdBy: map['createdBy'] ?? '',
      updatedBy: map['updatedBy'],
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
      metadata: map['metadata'] != null
          ? SafeTypeConverter.toMap(map['metadata'])
          : {},
    );
  }
}

class UserAcceptance {
  final String id;
  final String userId;
  final String userEmail;
  final String documentId;
  final DocumentType documentType;
  final String documentVersion;
  final DateTime acceptedAt;
  final String ipAddress;
  final String userAgent;
  final Map<String, dynamic> metadata;

  UserAcceptance({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.documentId,
    required this.documentType,
    required this.documentVersion,
    required this.acceptedAt,
    required this.ipAddress,
    required this.userAgent,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'documentId': documentId,
      'documentType': documentType.toString().split('.').last,
      'documentVersion': documentVersion,
      'acceptedAt': acceptedAt.millisecondsSinceEpoch,
      'acceptedAtIso': acceptedAt.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'metadata': metadata,
    };
  }

  factory UserAcceptance.fromMap(Map<String, dynamic> map) {
    return UserAcceptance(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      documentId: map['documentId'] ?? '',
      documentType: DocumentType.values.firstWhere(
        (e) => e.toString().split('.').last == map['documentType'],
        orElse: () => DocumentType.terms_of_service,
      ),
      documentVersion: map['documentVersion'] ?? '1.0',
      acceptedAt: map['acceptedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['acceptedAt'])
          : DateTime.now(),
      ipAddress: map['ipAddress'] ?? '',
      userAgent: map['userAgent'] ?? '',
      metadata: map['metadata'] != null
          ? SafeTypeConverter.toMap(map['metadata'])
          : {},
    );
  }
}

class LegalDocumentsService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;
  String? get userEmail => _auth.currentUser?.email;

  /// Create a new legal document (admin only)
  Future<String> createDocument({
    required DocumentType type,
    required String title,
    required String content,
    String? version,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can create legal documents');
    }

    try {
      final documentId = _db.ref().push().key!;
      final now = DateTime.now();

      final document = LegalDocument(
        id: documentId,
        type: type,
        title: title,
        content: content,
        version: version ?? '1.0',
        status: DocumentStatus.draft,
        createdAt: now,
        createdBy: userEmail ?? userId ?? 'unknown',
        metadata: metadata ?? {},
      );

      await _db.ref('legal_documents/$documentId').set(document.toMap());

      AppLogger.info(
        'Legal document created: $title (${type.toString().split('.').last})',
        category: LogCategory.business,
      );

      return documentId;

    } catch (e) {
      AppLogger.error('Error creating legal document', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Update a legal document (admin only)
  Future<void> updateDocument({
    required String documentId,
    String? title,
    String? content,
    String? version,
    DocumentStatus? status,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can update legal documents');
    }

    try {
      final updates = <String, dynamic>{
        'updatedBy': userEmail ?? userId ?? 'unknown',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAtIso': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (version != null) updates['version'] = version;
      if (status != null) {
        updates['status'] = status.toString().split('.').last;

        // Set publish date when publishing
        if (status == DocumentStatus.published) {
          updates['publishedAt'] = DateTime.now().millisecondsSinceEpoch;
          updates['publishedAtIso'] = DateTime.now().toIso8601String();
        }
      }
      if (expiresAt != null) {
        updates['expiresAt'] = expiresAt.millisecondsSinceEpoch;
        updates['expiresAtIso'] = expiresAt.toIso8601String();
      }
      if (metadata != null) updates['metadata'] = metadata;

      await _db.ref('legal_documents/$documentId').update(updates);

      AppLogger.info('Legal document updated: $documentId', category: LogCategory.business);

    } catch (e) {
      AppLogger.error('Error updating legal document', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Publish a document (admin only)
  Future<void> publishDocument(String documentId) async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can publish legal documents');
    }

    try {
      // First archive any existing published document of the same type
      final document = await getDocument(documentId);
      if (document != null) {
        await _archiveExistingPublishedDocuments(document.type);
      }

      // Publish the new document
      await updateDocument(
        documentId: documentId,
        status: DocumentStatus.published,
      );

      AppLogger.info('Legal document published: $documentId', category: LogCategory.business);

    } catch (e) {
      AppLogger.error('Error publishing legal document', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Archive existing published documents of the same type
  Future<void> _archiveExistingPublishedDocuments(DocumentType type) async {
    try {
      final snapshot = await _db.ref('legal_documents')
          .orderByChild('type')
          .equalTo(type.toString().split('.').last)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = SafeTypeConverter.toMap(snapshot.value as Map);
        final updates = <String, dynamic>{};

        for (final entry in data.entries) {
          final doc = LegalDocument.fromMap(SafeTypeConverter.toMap(entry.value));
          if (doc.status == DocumentStatus.published) {
            updates['legal_documents/${entry.key}/status'] = DocumentStatus.archived.toString().split('.').last;
            updates['legal_documents/${entry.key}/updatedAt'] = DateTime.now().millisecondsSinceEpoch;
            updates['legal_documents/${entry.key}/updatedBy'] = userEmail ?? userId ?? 'system';
          }
        }

        if (updates.isNotEmpty) {
          await _db.ref().update(updates);
        }
      }

    } catch (e) {
      AppLogger.error('Error archiving existing documents', error: e, category: LogCategory.business);
    }
  }

  /// Get a specific document
  Future<LegalDocument?> getDocument(String documentId) async {
    try {
      final snapshot = await _db.ref('legal_documents/$documentId').get();

      if (snapshot.exists && snapshot.value != null) {
        return LegalDocument.fromMap(SafeTypeConverter.toMap(snapshot.value as Map));
      }

      return null;

    } catch (e) {
      AppLogger.error('Error getting legal document', error: e, category: LogCategory.business);
      return null;
    }
  }

  /// Get all documents (admin) or published documents (users)
  Stream<List<LegalDocument>> getDocuments({
    DocumentType? type,
    DocumentStatus? status,
    bool adminView = false,
  }) {
    Query query = _db.ref('legal_documents');

    // If not admin and not specifically requesting admin view, only show published
    if (!_isCurrentUserAdminOrSuperAdmin() && !adminView) {
      query = query.orderByChild('status').equalTo(DocumentStatus.published.toString().split('.').last);
    } else if (type != null) {
      query = query.orderByChild('type').equalTo(type.toString().split('.').last);
    } else {
      query = query.orderByChild('createdAt');
    }

    return query.onValue.map((event) {
      final List<LegalDocument> documents = [];

      if (event.snapshot.value != null) {
        final data = SafeTypeConverter.toMap(event.snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final document = LegalDocument.fromMap(
              SafeTypeConverter.toMap(entry.value),
            );

            // Apply additional filters
            if (type != null && document.type != type) continue;
            if (status != null && document.status != status) continue;

            // For non-admin users, only show published documents
            if (!_isCurrentUserAdminOrSuperAdmin() && !adminView) {
              if (document.status != DocumentStatus.published) continue;
            }

            documents.add(document);
          } catch (e) {
            AppLogger.error('Error parsing legal document', error: e, category: LogCategory.business);
          }
        }
      }

      // Sort by creation date (newest first)
      documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return documents;
    });
  }

  /// Get the current published version of a document type
  Future<LegalDocument?> getCurrentDocument(DocumentType type) async {
    try {
      final snapshot = await _db.ref('legal_documents')
          .orderByChild('type')
          .equalTo(type.toString().split('.').last)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = SafeTypeConverter.toMap(snapshot.value as Map);

        // Find the published document
        for (final entry in data.entries) {
          final doc = LegalDocument.fromMap(SafeTypeConverter.toMap(entry.value));
          if (doc.status == DocumentStatus.published) {
            return doc;
          }
        }
      }

      return null;

    } catch (e) {
      AppLogger.error('Error getting current document', error: e, category: LogCategory.business);
      return null;
    }
  }

  /// Record user acceptance of a document
  Future<String> recordUserAcceptance({
    required String documentId,
    required String ipAddress,
    required String userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get the document details
      final document = await getDocument(documentId);
      if (document == null) {
        throw Exception('Document not found');
      }

      final acceptanceId = _db.ref().push().key!;
      final now = DateTime.now();

      final acceptance = UserAcceptance(
        id: acceptanceId,
        userId: userId!,
        userEmail: userEmail ?? '',
        documentId: documentId,
        documentType: document.type,
        documentVersion: document.version,
        acceptedAt: now,
        ipAddress: ipAddress,
        userAgent: userAgent,
        metadata: metadata ?? {},
      );

      // Store in user-specific path and global path
      await _db.ref('user_acceptances/$userId/$acceptanceId').set(acceptance.toMap());
      await _db.ref('global_acceptances/$acceptanceId').set(acceptance.toMap());

      AppLogger.info(
        'User acceptance recorded: ${document.type.toString().split('.').last} v${document.version}',
        category: LogCategory.business,
      );

      return acceptanceId;

    } catch (e) {
      AppLogger.error('Error recording user acceptance', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Check if user has accepted a document type
  Future<UserAcceptance?> getUserAcceptance(DocumentType type) async {
    if (userId == null) return null;

    try {
      final snapshot = await _db.ref('user_acceptances/$userId').get();

      if (snapshot.exists && snapshot.value != null) {
        final data = SafeTypeConverter.toMap(snapshot.value as Map);

        // Find the most recent acceptance for this document type
        UserAcceptance? latestAcceptance;

        for (final entry in data.entries) {
          final acceptance = UserAcceptance.fromMap(
            SafeTypeConverter.toMap(entry.value),
          );

          if (acceptance.documentType == type) {
            if (latestAcceptance == null ||
                acceptance.acceptedAt.isAfter(latestAcceptance.acceptedAt)) {
              latestAcceptance = acceptance;
            }
          }
        }

        return latestAcceptance;
      }

      return null;

    } catch (e) {
      AppLogger.error('Error getting user acceptance', error: e, category: LogCategory.business);
      return null;
    }
  }

  /// Check if user needs to accept updated documents
  Future<List<LegalDocument>> getDocumentsRequiringAcceptance() async {
    if (userId == null) return [];

    try {
      final requiredDocs = <LegalDocument>[];

      // Check each document type
      for (final type in DocumentType.values) {
        final currentDoc = await getCurrentDocument(type);
        if (currentDoc == null) continue;

        final userAcceptance = await getUserAcceptance(type);

        // User needs to accept if:
        // 1. They haven't accepted this document type at all
        // 2. They have accepted an older version
        if (userAcceptance == null ||
            _isVersionNewer(currentDoc.version, userAcceptance.documentVersion)) {
          requiredDocs.add(currentDoc);
        }
      }

      return requiredDocs;

    } catch (e) {
      AppLogger.error('Error checking required acceptances', error: e, category: LogCategory.business);
      return [];
    }
  }

  /// Get all user acceptances (admin only)
  Stream<List<UserAcceptance>> getAllUserAcceptances({
    String? targetUserId,
    DocumentType? documentType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      return Stream.value([]);
    }

    Query query = _db.ref('global_acceptances');
    query = query.orderByChild('acceptedAt');

    return query.onValue.map((event) {
      final List<UserAcceptance> acceptances = [];

      if (event.snapshot.value != null) {
        final data = SafeTypeConverter.toMap(event.snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final acceptance = UserAcceptance.fromMap(
              SafeTypeConverter.toMap(entry.value),
            );

            // Apply filters
            if (targetUserId != null && acceptance.userId != targetUserId) continue;
            if (documentType != null && acceptance.documentType != documentType) continue;
            if (startDate != null && acceptance.acceptedAt.isBefore(startDate)) continue;
            if (endDate != null && acceptance.acceptedAt.isAfter(endDate)) continue;

            acceptances.add(acceptance);
          } catch (e) {
            AppLogger.error('Error parsing user acceptance', error: e, category: LogCategory.business);
          }
        }
      }

      // Sort by acceptance date (newest first)
      acceptances.sort((a, b) => b.acceptedAt.compareTo(a.acceptedAt));

      return acceptances;
    });
  }

  /// Delete a document (admin only)
  Future<void> deleteDocument(String documentId) async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can delete legal documents');
    }

    try {
      await _db.ref('legal_documents/$documentId').remove();

      AppLogger.info('Legal document deleted: $documentId', category: LogCategory.business);

    } catch (e) {
      AppLogger.error('Error deleting legal document', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Create default legal documents
  Future<void> createDefaultDocuments() async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can create default documents');
    }

    try {
      AppLogger.info('Creating default legal documents', category: LogCategory.business);

      // Terms of Service
      await createDocument(
        type: DocumentType.terms_of_service,
        title: 'Terms of Service',
        content: _getDefaultTermsOfService(),
        version: '1.0',
        metadata: {'isDefault': true},
      );

      // Privacy Policy
      await createDocument(
        type: DocumentType.privacy_policy,
        title: 'Privacy Policy',
        content: _getDefaultPrivacyPolicy(),
        version: '1.0',
        metadata: {'isDefault': true},
      );

      // User Agreement
      await createDocument(
        type: DocumentType.user_agreement,
        title: 'User Agreement',
        content: _getDefaultUserAgreement(),
        version: '1.0',
        metadata: {'isDefault': true},
      );

      AppLogger.info('Default legal documents created', category: LogCategory.business);

    } catch (e) {
      AppLogger.error('Error creating default documents', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Get acceptance statistics (admin only)
  Future<Map<String, dynamic>> getAcceptanceStats() async {
    if (!_isCurrentUserAdminOrSuperAdmin()) {
      throw Exception('Only admin users can view acceptance statistics');
    }

    try {
      final snapshot = await _db.ref('global_acceptances').get();

      if (!snapshot.exists) {
        return {
          'totalAcceptances': 0,
          'documentTypeBreakdown': {},
          'dailyAcceptances': {},
          'uniqueUsers': 0,
        };
      }

      final data = SafeTypeConverter.toMap(snapshot.value as Map);
      final documentTypeBreakdown = <String, int>{};
      final dailyAcceptances = <String, int>{};
      final uniqueUsers = <String>{};

      for (final entry in data.values) {
        final acceptance = UserAcceptance.fromMap(
          SafeTypeConverter.toMap(entry),
        );

        // Document type breakdown
        final typeKey = acceptance.documentType.toString().split('.').last;
        documentTypeBreakdown[typeKey] = (documentTypeBreakdown[typeKey] ?? 0) + 1;

        // Daily acceptances
        final dateKey = '${acceptance.acceptedAt.year}-${acceptance.acceptedAt.month.toString().padLeft(2, '0')}-${acceptance.acceptedAt.day.toString().padLeft(2, '0')}';
        dailyAcceptances[dateKey] = (dailyAcceptances[dateKey] ?? 0) + 1;

        // Unique users
        uniqueUsers.add(acceptance.userId);
      }

      return {
        'totalAcceptances': data.length,
        'documentTypeBreakdown': documentTypeBreakdown,
        'dailyAcceptances': dailyAcceptances,
        'uniqueUsers': uniqueUsers.length,
      };

    } catch (e) {
      AppLogger.error('Error getting acceptance stats', error: e, category: LogCategory.business);
      return {'error': e.toString()};
    }
  }

  /// Helper methods
  Future<bool> _isCurrentUserAdminOrSuperAdmin() async {
    return await RBACService.isAdminOrAbove();
  }

  bool _isVersionNewer(String currentVersion, String acceptedVersion) {
    // Simple version comparison (assumes semantic versioning)
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final acceptedParts = acceptedVersion.split('.').map(int.parse).toList();

    // Pad shorter version with zeros
    while (currentParts.length < acceptedParts.length) {
      currentParts.add(0);
    }
    while (acceptedParts.length < currentParts.length) {
      acceptedParts.add(0);
    }

    for (int i = 0; i < currentParts.length; i++) {
      if (currentParts[i] > acceptedParts[i]) return true;
      if (currentParts[i] < acceptedParts[i]) return false;
    }

    return false; // Versions are equal
  }

  /// Default document templates
  String _getDefaultTermsOfService() {
    return '''
# Terms of Service

## 1. Acceptance of Terms
By accessing and using Turbo Air Quotes (TAQ), you accept and agree to be bound by the terms and provision of this agreement.

## 2. Description of Service
TAQ is an internal business tool for managing equipment quotes, client relationships, and sales operations for Turbo Air Mexico and its authorized distributors.

## 3. User Responsibilities
- Users must maintain the confidentiality of their login credentials
- Users are responsible for all activities under their account
- Users must use the service in compliance with applicable laws and regulations

## 4. Data and Privacy
- User data is stored securely and used solely for business operations
- Data access is restricted to authorized personnel only
- Users may request data export or deletion as permitted by law

## 5. Service Availability
- We strive to maintain high service availability but do not guarantee uninterrupted access
- Scheduled maintenance may require temporary service interruptions
- Users will be notified of planned maintenance when possible

## 6. Modifications
- These terms may be updated from time to time
- Users will be notified of material changes
- Continued use constitutes acceptance of updated terms

## 7. Contact
For questions about these terms, contact: andres@turboairmexico.com

Last updated: ${DateTime.now().toIso8601String().split('T')[0]}
''';
  }

  String _getDefaultPrivacyPolicy() {
    return '''
# Privacy Policy

## 1. Information We Collect
- Account information (name, email, role)
- Business data (clients, quotes, products)
- Usage data (login times, feature usage)
- Technical data (IP address, browser information)

## 2. How We Use Information
- To provide and maintain our service
- To authenticate users and ensure security
- To generate reports and analytics
- To communicate important updates

## 3. Information Sharing
- Data is not shared with third parties except as required by law
- Internal data access is limited to authorized personnel
- Data may be shared within the Turbo Air organization for business purposes

## 4. Data Security
- Data is encrypted in transit and at rest
- Access controls limit data access to authorized users
- Regular security audits and updates are performed
- Backup systems ensure data protection and recovery

## 5. Data Retention
- User data is retained while accounts remain active
- Inactive accounts may have data archived or deleted
- Users may request data deletion subject to business requirements

## 6. User Rights
- Access to personal data
- Correction of inaccurate data
- Data portability where technically feasible
- Deletion of data subject to legal and business requirements

## 7. Changes to Policy
We may update this policy from time to time. Users will be notified of significant changes.

## 8. Contact
For privacy questions, contact: andres@turboairmexico.com

Last updated: ${DateTime.now().toIso8601String().split('T')[0]}
''';
  }

  String _getDefaultUserAgreement() {
    return '''
# User Agreement

## 1. Account Access
- This system is for authorized business use only
- Users must be employees or authorized partners of Turbo Air Mexico
- Account access may be revoked at any time

## 2. Appropriate Use
- Use the system only for legitimate business purposes
- Do not share account credentials with others
- Report security concerns immediately
- Respect confidentiality of client and business data

## 3. Data Handling
- Client data must be handled according to privacy policies
- Do not export or share confidential information without authorization
- Maintain accuracy of data entered into the system
- Follow company data retention policies

## 4. System Behavior
- Do not attempt to circumvent security measures
- Report bugs or issues to technical support
- Use features as intended
- Do not overload the system with excessive requests

## 5. Compliance
- Follow all applicable laws and regulations
- Comply with company policies and procedures
- Maintain professional conduct when using the system

## 6. Support
For technical support or questions about this agreement, contact: andres@turboairmexico.com

I acknowledge that I have read, understood, and agree to comply with this User Agreement.

Last updated: ${DateTime.now().toIso8601String().split('T')[0]}
''';
  }
}