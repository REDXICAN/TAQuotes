// lib/core/services/client_demo_data_service.dart
// Service to populate demo client data for TurboAir equipment company

import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';
import '../utils/safe_type_converter.dart';

class ClientDemoDataService {
  static final ClientDemoDataService _instance = ClientDemoDataService._internal();
  factory ClientDemoDataService() => _instance;
  ClientDemoDataService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  // Auth and random kept for potential future demo data features
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ignore: unused_field
  final Random _random = Random();

  // Demo client data for commercial kitchen equipment companies
  static const List<Map<String, dynamic>> _demoClients = [
    {
      'company': 'Grand Palace Hotel Group',
      'contactName': 'Maria Rodriguez',
      'email': 'maria.rodriguez@grandpalacehotels.com',
      'phone': '+1 (555) 234-5678',
      'address': '1234 Luxury Avenue, Miami Beach, FL 33139',
      'city': 'Miami Beach',
      'state': 'FL',
      'zipCode': '33139',
      'country': 'USA',
      'notes': 'High-end hotel chain with 15 locations. Interested in energy-efficient refrigeration units for their restaurants.',
    },
    {
      'company': 'La Cocina Mexicana Restaurant',
      'contactName': 'Carlos Mendez',
      'email': 'carlos@lacocina-mx.com',
      'phone': '+52 998 123 4567',
      'address': 'Av. Tulum 245, Centro, Cancún, Q.R. 77500',
      'city': 'Cancún',
      'state': 'Quintana Roo',
      'zipCode': '77500',
      'country': 'Mexico',
      'notes': 'Authentic Mexican restaurant chain. Needs walk-in coolers and freezers for their 8 locations.',
    },
    {
      'company': 'Fresh Market Distributors',
      'contactName': 'Jennifer Smith',
      'email': 'j.smith@freshmarket-dist.com',
      'phone': '+1 (713) 456-7890',
      'address': '789 Commerce Drive, Houston, TX 77002',
      'city': 'Houston',
      'state': 'TX',
      'zipCode': '77002',
      'country': 'USA',
      'notes': 'Food distribution company serving restaurants across Texas. Looking for reliable refrigeration transport units.',
    },
    {
      'company': 'Seaside Seafood Company',
      'contactName': 'Antonio Morales',
      'email': 'antonio@seaside-seafood.mx',
      'phone': '+52 984 567 8901',
      'address': 'Muelle Fiscal s/n, Playa del Carmen, Q.R. 77710',
      'city': 'Playa del Carmen',
      'state': 'Quintana Roo',
      'zipCode': '77710',
      'country': 'Mexico',
      'notes': 'Fresh seafood supplier to luxury resorts. Requires blast chillers and display cases.',
    },
    {
      'company': 'Metro Cafeteria Services',
      'contactName': 'Lisa Johnson',
      'email': 'lisa.johnson@metrocafeteria.com',
      'phone': '+1 (214) 789-0123',
      'address': '456 Industrial Blvd, Dallas, TX 75201',
      'city': 'Dallas',
      'state': 'TX',
      'zipCode': '75201',
      'country': 'USA',
      'notes': 'Corporate cafeteria management company. Interested in bulk cooling solutions for office buildings.',
    },
    {
      'company': 'Tropical Ice Cream Factory',
      'contactName': 'Roberto Villareal',
      'email': 'roberto@tropicalice.com.mx',
      'phone': '+52 999 234 5678',
      'address': 'Calle 60 #485, Centro Histórico, Mérida, Yuc. 97000',
      'city': 'Mérida',
      'state': 'Yucatán',
      'zipCode': '97000',
      'country': 'Mexico',
      'notes': 'Artisanal ice cream manufacturer. Needs specialized freezer units for production and storage.',
    },
    {
      'company': 'Golden Gate Catering',
      'contactName': 'Michelle Wong',
      'email': 'michelle@ggcatering.com',
      'phone': '+1 (415) 345-6789',
      'address': '890 Mission Street, San Francisco, CA 94103',
      'city': 'San Francisco',
      'state': 'CA',
      'zipCode': '94103',
      'country': 'USA',
      'notes': 'High-volume catering company serving Silicon Valley events. Looking for mobile refrigeration units.',
    },
    {
      'company': 'Beachfront Resort & Spa',
      'contactName': 'David Thompson',
      'email': 'david.thompson@beachfrontresort.com',
      'phone': '+1 (305) 567-8901',
      'address': '2000 Ocean Drive, Key Largo, FL 33037',
      'city': 'Key Largo',
      'state': 'FL',
      'zipCode': '33037',
      'country': 'USA',
      'notes': 'Luxury resort with multiple restaurants. Needs comprehensive kitchen cooling systems for renovation project.',
    },
    {
      'company': 'Mercado Central Wholesale',
      'contactName': 'Ana Gutierrez',
      'email': 'ana@mercadocentral.mx',
      'phone': '+52 55 8901 2345',
      'address': 'Av. Central de Abastos 1234, Iztapalapa, CDMX 09040',
      'city': 'Mexico City',
      'state': 'Ciudad de México',
      'zipCode': '09040',
      'country': 'Mexico',
      'notes': 'Large wholesale food market. Requires industrial-scale refrigeration for fresh produce storage.',
    },
    {
      'company': 'Campus Dining Solutions',
      'contactName': 'Michael Brown',
      'email': 'michael.brown@campusdining.edu',
      'phone': '+1 (512) 678-9012',
      'address': '1500 University Drive, Austin, TX 78712',
      'city': 'Austin',
      'state': 'TX',
      'zipCode': '78712',
      'country': 'USA',
      'notes': 'University dining services provider. Interested in energy-efficient solutions for multiple campus locations.',
    }
  ];

  /// Check if the admin user has any existing clients
  Future<bool> hasExistingClients(String adminUserId) async {
    try {
      final snapshot = await _db.ref('clients/$adminUserId').get();

      if (snapshot.exists && snapshot.value != null) {
        final data = SafeTypeConverter.toMap(snapshot.value as Map);
        return data.isNotEmpty;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error checking existing clients', error: e, category: LogCategory.database);
      return false;
    }
  }

  /// Get the count of existing clients for the admin user
  Future<int> getClientCount(String adminUserId) async {
    try {
      final snapshot = await _db.ref('clients/$adminUserId').get();

      if (snapshot.exists && snapshot.value != null) {
        final data = SafeTypeConverter.toMap(snapshot.value as Map);
        return data.length;
      }

      return 0;
    } catch (e) {
      AppLogger.error('Error getting client count', error: e, category: LogCategory.database);
      return 0;
    }
  }

  /// Populate demo client data for the admin user
  Future<void> populateDemoClientData(String adminUserId) async {
    try {
      AppLogger.info('Starting demo client data population for admin user: $adminUserId',
                     category: LogCategory.system);

      int successCount = 0;
      final List<String> errors = [];

      for (final clientData in _demoClients) {
        try {
          // Create a new client reference
          final newClientRef = _db.ref('clients/$adminUserId').push();

          // Prepare client data with timestamps
          final clientWithTimestamps = SafeTypeConverter.toMap(clientData)
            ..addAll({
              'id': newClientRef.key,
              'created_at': ServerValue.timestamp,
              'updated_at': ServerValue.timestamp,
            });

          // Save to Firebase
          await newClientRef.set(clientWithTimestamps);
          successCount++;

          AppLogger.info('Demo client created: ${clientData['company']}',
                         category: LogCategory.system);

        } catch (e) {
          final errorMsg = 'Failed to create demo client ${clientData['company']}: $e';
          errors.add(errorMsg);
          AppLogger.error(errorMsg, error: e, category: LogCategory.database);
        }
      }

      AppLogger.info('Demo client data population completed: $successCount/${_demoClients.length} clients created',
                     category: LogCategory.system);

      if (errors.isNotEmpty) {
        AppLogger.warning('Some demo clients failed to create',
                         data: {'errors': errors},
                         category: LogCategory.system);
      }

    } catch (e) {
      AppLogger.error('Failed to populate demo client data', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Clear all demo client data for the admin user
  Future<void> clearDemoClientData(String adminUserId) async {
    try {
      AppLogger.info('Clearing demo client data for admin user: $adminUserId',
                     category: LogCategory.system);

      // Get all clients for the user
      final snapshot = await _db.ref('clients/$adminUserId').get();

      if (!snapshot.exists || snapshot.value == null) {
        AppLogger.info('No client data found to clear', category: LogCategory.system);
        return;
      }

      final data = SafeTypeConverter.toMap(snapshot.value as Map);
      int deleteCount = 0;

      // Delete each client individually to avoid affecting other data
      for (final clientId in data.keys) {
        try {
          await _db.ref('clients/$adminUserId/$clientId').remove();
          deleteCount++;
        } catch (e) {
          AppLogger.error('Failed to delete client $clientId', error: e, category: LogCategory.database);
        }
      }

      AppLogger.info('Demo client data cleared: $deleteCount clients removed',
                     category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to clear demo client data', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Check if admin user needs demo data and populate it if necessary
  Future<bool> checkAndPopulateDemoDataIfNeeded(String adminUserId) async {
    try {
      final hasClients = await hasExistingClients(adminUserId);

      if (!hasClients) {
        AppLogger.info('No existing clients found for admin user. Populating demo data...',
                       category: LogCategory.system);

        await populateDemoClientData(adminUserId);
        return true;
      } else {
        final clientCount = await getClientCount(adminUserId);
        AppLogger.info('Admin user already has $clientCount clients. Demo data not needed.',
                       category: LogCategory.system);
        return false;
      }
    } catch (e) {
      AppLogger.error('Error checking and populating demo data', error: e, category: LogCategory.system);
      return false;
    }
  }

  /// Get demo client data count
  static int get demoClientCount => _demoClients.length;

  /// Get demo client companies list
  static List<String> get demoCompanies =>
    _demoClients.map((client) => client['company'] as String).toList();
}