// lib/core/services/sample_data_initializer.dart
import 'package:firebase_database/firebase_database.dart';
import 'app_logger.dart';

class SampleDataInitializer {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  static Future<void> initializeSampleProducts() async {
    try {
      // Check if products already exist
      final snapshot = await _database.child('products').once();
      if (snapshot.snapshot.value != null) {
        AppLogger.info('Products already exist in database', category: LogCategory.database);
        return;
      }

      // Add sample products
      final sampleProducts = [
        {
          'sku': 'DEMO-001',
          'name': 'Demo Refrigerator',
          'description': 'Sample commercial refrigerator for testing',
          'price': 2999.99,
          'category': 'Refrigeration',
          'subcategory': 'Reach-In',
          'dimensions': '27"W x 32"D x 78"H',
          'weight': '450 lbs',
          'capacity': '23 cu. ft.',
          'doors': 1,
          'shelves': 4,
        },
        {
          'sku': 'DEMO-002',
          'name': 'Demo Freezer',
          'description': 'Sample commercial freezer for testing',
          'price': 3499.99,
          'category': 'Refrigeration',
          'subcategory': 'Reach-In',
          'dimensions': '27"W x 32"D x 78"H',
          'weight': '500 lbs',
          'capacity': '23 cu. ft.',
          'doors': 1,
          'shelves': 4,
        },
        {
          'sku': 'DEMO-003',
          'name': 'Demo Prep Table',
          'description': 'Sample prep table for testing',
          'price': 1899.99,
          'category': 'Prep Tables',
          'subcategory': 'Sandwich/Salad',
          'dimensions': '48"W x 30"D x 44"H',
          'weight': '250 lbs',
          'capacity': '12 cu. ft.',
          'doors': 2,
          'shelves': 2,
        },
      ];

      for (final product in sampleProducts) {
        await _database.child('products').push().set(product);
      }

      AppLogger.info('Sample products initialized successfully', category: LogCategory.database);
    } catch (e) {
      AppLogger.error('Failed to initialize sample products', error: e, category: LogCategory.database);
    }
  }

  static Future<void> initializeSampleClients() async {
    try {
      // For clients, we need authentication, so we'll skip if not authenticated
      AppLogger.info('Sample clients initialization skipped (requires auth)', category: LogCategory.database);
    } catch (e) {
      AppLogger.error('Failed to initialize sample clients', error: e, category: LogCategory.database);
    }
  }

  static Future<void> initializeAll() async {
    await initializeSampleProducts();
    await initializeSampleClients();
  }
}