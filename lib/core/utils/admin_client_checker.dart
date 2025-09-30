// lib/core/utils/admin_client_checker.dart
// Utility to check if admin user has clients and populate demo data if needed

import 'package:firebase_auth/firebase_auth.dart';
import '../services/client_demo_data_service.dart';
import '../services/app_logger.dart';

class AdminClientChecker {
  static const String adminEmail = 'andres@turboairmexico.com';

  /// Check if the admin user has clients and populate demo data if needed
  static Future<Map<String, dynamic>> checkAndSetupAdminClients() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return {
          'success': false,
          'message': 'No user is currently logged in',
          'action': 'none',
        };
      }

      // Check if this is the admin user
      if (user.email != adminEmail) {
        return {
          'success': true,
          'message': 'User is not admin, no action needed',
          'action': 'none',
          'userEmail': user.email,
        };
      }

      final demoService = ClientDemoDataService();
      final adminUserId = user.uid;

      // Check if admin has existing clients
      final hasClients = await demoService.hasExistingClients(adminUserId);
      final clientCount = await demoService.getClientCount(adminUserId);

      if (hasClients) {
        return {
          'success': true,
          'message': 'Admin user already has $clientCount clients',
          'action': 'none',
          'clientCount': clientCount,
          'userEmail': user.email,
        };
      }

      // Admin has no clients, populate demo data
      AppLogger.info('Admin user has no clients. Populating demo data...',
                     category: LogCategory.system);

      await demoService.populateDemoClientData(adminUserId);

      final newClientCount = await demoService.getClientCount(adminUserId);

      return {
        'success': true,
        'message': 'Demo clients created successfully',
        'action': 'demo_data_populated',
        'clientCount': newClientCount,
        'demoClientCount': ClientDemoDataService.demoClientCount,
        'userEmail': user.email,
        'companies': ClientDemoDataService.demoCompanies,
      };

    } catch (e) {
      AppLogger.error('Error checking and setting up admin clients',
                      error: e, category: LogCategory.system);

      return {
        'success': false,
        'message': 'Error: $e',
        'action': 'error',
      };
    }
  }

  /// Force populate demo data (even if clients exist)
  static Future<Map<String, dynamic>> forcePopulateDemoClients() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return {
          'success': false,
          'message': 'No user is currently logged in',
        };
      }

      if (user.email != adminEmail) {
        return {
          'success': false,
          'message': 'Only admin user can populate demo data',
          'userEmail': user.email,
        };
      }

      final demoService = ClientDemoDataService();
      await demoService.populateDemoClientData(user.uid);

      final clientCount = await demoService.getClientCount(user.uid);

      return {
        'success': true,
        'message': 'Demo clients populated successfully',
        'clientCount': clientCount,
        'demoClientCount': ClientDemoDataService.demoClientCount,
        'companies': ClientDemoDataService.demoCompanies,
      };

    } catch (e) {
      AppLogger.error('Error force populating demo clients',
                      error: e, category: LogCategory.system);

      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Clear all clients for admin user
  static Future<Map<String, dynamic>> clearAdminClients() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return {
          'success': false,
          'message': 'No user is currently logged in',
        };
      }

      if (user.email != adminEmail) {
        return {
          'success': false,
          'message': 'Only admin user can clear client data',
          'userEmail': user.email,
        };
      }

      final demoService = ClientDemoDataService();
      await demoService.clearDemoClientData(user.uid);

      return {
        'success': true,
        'message': 'All client data cleared successfully',
        'clientCount': 0,
      };

    } catch (e) {
      AppLogger.error('Error clearing admin clients',
                      error: e, category: LogCategory.system);

      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Get current client status for admin user
  static Future<Map<String, dynamic>> getAdminClientStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return {
          'success': false,
          'message': 'No user is currently logged in',
        };
      }

      if (user.email != adminEmail) {
        return {
          'success': true,
          'message': 'User is not admin',
          'userEmail': user.email,
          'isAdmin': false,
        };
      }

      final demoService = ClientDemoDataService();
      final clientCount = await demoService.getClientCount(user.uid);
      final hasClients = clientCount > 0;

      return {
        'success': true,
        'isAdmin': true,
        'hasClients': hasClients,
        'clientCount': clientCount,
        'userEmail': user.email,
        'adminUserId': user.uid,
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
}