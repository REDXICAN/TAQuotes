// lib/core/services/spare_parts_demo_service.dart
// Service to populate demo spare parts data for testing stock management

import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'app_logger.dart';

class SparePartsDemoService {
  static final SparePartsDemoService _instance = SparePartsDemoService._internal();
  factory SparePartsDemoService() => _instance;
  SparePartsDemoService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final Random _random = Random();

  // Sample spare part names and details
  static const List<Map<String, dynamic>> _sparePartsTemplate = [
    {
      'name': 'Compressor Replacement Kit',
      'description': 'Complete compressor assembly with mounting hardware for commercial refrigeration units',
      'category': 'Spare Parts',
      'basePrice': 850.00,
    },
    {
      'name': 'Door Gasket Set',
      'description': 'Replacement door gaskets for walk-in freezer and cooler doors, includes corner pieces',
      'category': 'Spare Parts',
      'basePrice': 125.00,
    },
    {
      'name': 'Temperature Sensor Assembly',
      'description': 'Digital temperature sensor with probe for accurate temperature monitoring',
      'category': 'Spare Parts',
      'basePrice': 95.00,
    },
    {
      'name': 'Evaporator Coil',
      'description': 'High-efficiency evaporator coil for walk-in coolers and freezers',
      'category': 'Spare Parts',
      'basePrice': 650.00,
    },
    {
      'name': 'Defrost Timer Module',
      'description': 'Electronic defrost timer with programmable settings for commercial units',
      'category': 'Spare Parts',
      'basePrice': 180.00,
    },
    {
      'name': 'Fan Motor Assembly',
      'description': 'Variable speed fan motor for efficient air circulation in refrigeration systems',
      'category': 'Spare Parts',
      'basePrice': 320.00,
    },
    {
      'name': 'Control Board PCB',
      'description': 'Main control board for refrigeration unit temperature and operation management',
      'category': 'Spare Parts',
      'basePrice': 450.00,
    },
    {
      'name': 'Thermostat Control Unit',
      'description': 'Digital thermostat with LCD display for precise temperature control',
      'category': 'Spare Parts',
      'basePrice': 220.00,
    },
    {
      'name': 'Refrigerant Line Kit',
      'description': 'Complete refrigerant line set with fittings and insulation',
      'category': 'Spare Parts',
      'basePrice': 275.00,
    },
    {
      'name': 'LED Lighting Strip',
      'description': 'Energy-efficient LED strip lighting for interior refrigeration unit illumination',
      'category': 'Spare Parts',
      'basePrice': 85.00,
    },
    {
      'name': 'Drain Pan Assembly',
      'description': 'Stainless steel drain pan with fitting for defrost water management',
      'category': 'Spare Parts',
      'basePrice': 115.00,
    },
    {
      'name': 'Door Handle Kit',
      'description': 'Heavy-duty door handles with mounting hardware for walk-in cooler doors',
      'category': 'Spare Parts',
      'basePrice': 65.00,
    },
    {
      'name': 'Insulation Panel Set',
      'description': 'High-density polyurethane insulation panels for temperature control',
      'category': 'Spare Parts',
      'basePrice': 380.00,
    },
    {
      'name': 'Pressure Relief Valve',
      'description': 'Safety pressure relief valve for refrigeration system protection',
      'category': 'Spare Parts',
      'basePrice': 145.00,
    },
    {
      'name': 'Air Filter Assembly',
      'description': 'Replaceable air filter system for maintaining clean air circulation',
      'category': 'Spare Parts',
      'basePrice': 55.00,
    },
    {
      'name': 'Condenser Coil',
      'description': 'High-performance condenser coil for heat rejection in refrigeration systems',
      'category': 'Spare Parts',
      'basePrice': 590.00,
    },
    {
      'name': 'Expansion Valve',
      'description': 'Thermostatic expansion valve for precise refrigerant flow control',
      'category': 'Spare Parts',
      'basePrice': 165.00,
    },
    {
      'name': 'Alarm System Module',
      'description': 'Temperature alarm system with audible and visual alerts',
      'category': 'Spare Parts',
      'basePrice': 285.00,
    },
    {
      'name': 'Wire Shelving Unit',
      'description': 'Adjustable stainless steel wire shelving for storage organization',
      'category': 'Spare Parts',
      'basePrice': 140.00,
    },
    {
      'name': 'Floor Drain Cover',
      'description': 'Stainless steel floor drain cover with anti-slip surface',
      'category': 'Spare Parts',
      'basePrice': 75.00,
    },
    {
      'name': 'Caster Wheel Set',
      'description': 'Heavy-duty locking caster wheels for mobile refrigeration units',
      'category': 'Spare Parts',
      'basePrice': 95.00,
    },
    {
      'name': 'Glass Door Panel',
      'description': 'Double-pane glass door panel with anti-fog coating',
      'category': 'Spare Parts',
      'basePrice': 425.00,
    },
    {
      'name': 'Heating Element',
      'description': 'Defrost heating element for ice prevention in freezer units',
      'category': 'Spare Parts',
      'basePrice': 195.00,
    },
    {
      'name': 'Solenoid Valve',
      'description': 'Electronic solenoid valve for automated refrigerant flow control',
      'category': 'Spare Parts',
      'basePrice': 240.00,
    },
    {
      'name': 'Humidity Control Module',
      'description': 'Digital humidity control system for optimal storage conditions',
      'category': 'Spare Parts',
      'basePrice': 310.00,
    },
  ];

  // Available warehouses for stock distribution
  static const List<String> _warehouses = [
    '999', 'CA1', 'CA2', 'CA3', 'CA4', 'COCZ', 'COPZ', 'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU', 'XZRE', 'ZRE'
  ];

  /// Generate spare parts products and stock data
  Future<void> populateSparePartsData({int numberOfParts = 25}) async {
    try {
      AppLogger.info('Starting spare parts data population', category: LogCategory.system);

      final spareParts = <Map<String, dynamic>>[];
      final stockData = <Map<String, dynamic>>[];

      for (int i = 0; i < numberOfParts; i++) {
        // Select a spare part template (with repetition allowed)
        final template = _sparePartsTemplate[i % _sparePartsTemplate.length];

        // Generate unique SKU for this spare part
        final skuSuffix = i < _sparePartsTemplate.length ? '' : '-${(i ~/ _sparePartsTemplate.length) + 1}';
        final sku = 'SP${(i + 1).toString().padLeft(3, '0')}$skuSuffix';

        // Price variation (+/- 20%)
        final priceVariation = 1.0 + ((_random.nextDouble() - 0.5) * 0.4);
        final price = (template['basePrice'] as double) * priceVariation;

        // Create spare part product
        final sparePart = {
          'sku': sku,
          'name': template['name'],
          'description': template['description'],
          'category': template['category'],
          'price': double.parse(price.toStringAsFixed(2)),
          'model': sku,
          'displayName': '${template['name']} ($sku)',
          'thumbnailUrl': '', // No images for spare parts demo
          'imageUrl': '',
          'imageUrl2': '',
          'created_at': ServerValue.timestamp,
          'updated_at': ServerValue.timestamp,
          'isSparePart': true, // Mark as spare part
        };

        spareParts.add(sparePart);

        // Generate stock data for random warehouses
        final numWarehouses = _random.nextInt(5) + 3; // 3-7 warehouses per part
        final selectedWarehouses = _warehouses.toList()..shuffle(_random);

        for (int w = 0; w < numWarehouses; w++) {
          final warehouse = selectedWarehouses[w];
          final stock = _random.nextInt(45) + 5; // 5-50 units
          final reserved = _random.nextInt(stock ~/ 3); // Some reserved stock

          stockData.add({
            'sku': sku,
            'warehouse': warehouse,
            'stock': stock,
            'reserved': reserved,
            'available': stock - reserved,
            'last_updated': ServerValue.timestamp,
          });
        }
      }

      // Save spare parts to Firebase
      AppLogger.info('Saving ${spareParts.length} spare parts to Firebase', category: LogCategory.system);

      for (final sparePart in spareParts) {
        final productRef = _db.ref('products').push();
        await productRef.set(sparePart);
      }

      // Save stock data to Firebase
      AppLogger.info('Saving ${stockData.length} stock entries to Firebase', category: LogCategory.system);

      for (final stock in stockData) {
        final stockRef = _db.ref('warehouse_stock').push();
        await stockRef.set(stock);
      }

      AppLogger.info(
        'Successfully populated ${spareParts.length} spare parts with ${stockData.length} stock entries',
        category: LogCategory.system,
      );

    } catch (e) {
      AppLogger.error('Failed to populate spare parts data', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Update existing products to be identified as spare parts
  Future<void> convertExistingProductsToSpareParts({int numberOfProducts = 10}) async {
    try {
      AppLogger.info('Converting existing products to spare parts', category: LogCategory.system);

      // Get existing products
      final snapshot = await _db.ref('products').get();
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('No products found to convert');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final productEntries = data.entries.toList();
      productEntries.shuffle(_random);

      int converted = 0;
      for (final entry in productEntries) {
        if (converted >= numberOfProducts) break;

        final productId = entry.key;
        final product = Map<String, dynamic>.from(entry.value);

        // Skip if already a spare part
        if (product['isSparePart'] == true) continue;

        // Update product to be a spare part
        final updates = <String, dynamic>{
          'isSparePart': true,
          'category': 'Spare Parts',
          'name': '${product['name'] ?? product['sku']} - Spare Part',
          'description': '${product['description'] ?? ''} (Replacement Part)',
          'updated_at': ServerValue.timestamp,
        };

        await _db.ref('products/$productId').update(updates);

        // Add some stock data for this converted spare part
        final sku = product['sku'] ?? productId;
        final numWarehouses = _random.nextInt(3) + 2; // 2-4 warehouses
        final selectedWarehouses = _warehouses.toList()..shuffle(_random);

        for (int w = 0; w < numWarehouses; w++) {
          final warehouse = selectedWarehouses[w];
          final stock = _random.nextInt(30) + 5; // 5-35 units
          final reserved = _random.nextInt(stock ~/ 4); // Some reserved stock

          final stockRef = _db.ref('warehouse_stock').push();
          await stockRef.set({
            'sku': sku,
            'warehouse': warehouse,
            'stock': stock,
            'reserved': reserved,
            'available': stock - reserved,
            'last_updated': ServerValue.timestamp,
          });
        }

        converted++;
      }

      AppLogger.info('Successfully converted $converted existing products to spare parts', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to convert existing products to spare parts', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Clear all spare parts demo data
  Future<void> clearSparePartsData() async {
    try {
      AppLogger.info('Clearing spare parts demo data', category: LogCategory.system);

      // Remove spare parts products
      final productsSnapshot = await _db.ref('products').get();
      if (productsSnapshot.exists && productsSnapshot.value != null) {
        final data = Map<String, dynamic>.from(productsSnapshot.value as Map);

        for (final entry in data.entries) {
          final product = Map<String, dynamic>.from(entry.value);
          if (product['isSparePart'] == true) {
            await _db.ref('products/${entry.key}').remove();
          }
        }
      }

      // Remove stock data for spare parts
      final stockSnapshot = await _db.ref('warehouse_stock').get();
      if (stockSnapshot.exists && stockSnapshot.value != null) {
        final data = Map<String, dynamic>.from(stockSnapshot.value as Map);

        for (final entry in data.entries) {
          final stock = Map<String, dynamic>.from(entry.value);
          final sku = stock['sku'];

          // Check if this SKU belongs to a spare part
          if (sku != null && sku.toString().startsWith('SP')) {
            await _db.ref('warehouse_stock/${entry.key}').remove();
          }
        }
      }

      AppLogger.info('Spare parts demo data cleared successfully', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to clear spare parts demo data', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Add stock to existing spare parts
  Future<void> addStockToExistingSpareParts() async {
    try {
      AppLogger.info('Adding stock to existing spare parts', category: LogCategory.system);

      // Get existing spare parts
      final productsSnapshot = await _db.ref('products').get();
      if (!productsSnapshot.exists || productsSnapshot.value == null) {
        throw Exception('No products found');
      }

      final data = Map<String, dynamic>.from(productsSnapshot.value as Map);
      final sparePartsSkus = <String>[];

      // Find spare parts SKUs
      for (final entry in data.entries) {
        final product = Map<String, dynamic>.from(entry.value);
        if (product['isSparePart'] == true) {
          final sku = product['sku'] ?? entry.key;
          sparePartsSkus.add(sku);
        }
      }

      if (sparePartsSkus.isEmpty) {
        AppLogger.info('No spare parts found to add stock to', category: LogCategory.system);
        return;
      }

      // Add stock data for each spare part
      int stockEntriesAdded = 0;
      for (final sku in sparePartsSkus) {
        final numWarehouses = _random.nextInt(4) + 2; // 2-5 warehouses
        final selectedWarehouses = _warehouses.toList()..shuffle(_random);

        for (int w = 0; w < numWarehouses; w++) {
          final warehouse = selectedWarehouses[w];
          final stock = _random.nextInt(40) + 10; // 10-50 units
          final reserved = _random.nextInt(stock ~/ 3); // Some reserved stock

          final stockRef = _db.ref('warehouse_stock').push();
          await stockRef.set({
            'sku': sku,
            'warehouse': warehouse,
            'stock': stock,
            'reserved': reserved,
            'available': stock - reserved,
            'last_updated': ServerValue.timestamp,
          });

          stockEntriesAdded++;
        }
      }

      AppLogger.info(
        'Successfully added $stockEntriesAdded stock entries for ${sparePartsSkus.length} spare parts',
        category: LogCategory.system,
      );

    } catch (e) {
      AppLogger.error('Failed to add stock to existing spare parts', error: e, category: LogCategory.system);
      rethrow;
    }
  }

  /// Generate a quick test spare part for immediate verification
  Future<void> generateTestSparePart() async {
    try {
      final testPart = _sparePartsTemplate[_random.nextInt(_sparePartsTemplate.length)];
      final sku = 'TEST-SP-${DateTime.now().millisecondsSinceEpoch}';

      final sparePartData = {
        'sku': sku,
        'name': '${testPart['name']} (Test)',
        'description': '${testPart['description']} - Generated for testing',
        'category': 'Spare Parts',
        'price': testPart['basePrice'],
        'model': sku,
        'displayName': '${testPart['name']} (Test) ($sku)',
        'isSparePart': true,
        'created_at': ServerValue.timestamp,
        'updated_at': ServerValue.timestamp,
      };

      // Save to Firebase
      final productRef = _db.ref('products').push();
      await productRef.set(sparePartData);

      // Add stock in 2-3 warehouses
      final numWarehouses = _random.nextInt(2) + 2;
      final selectedWarehouses = _warehouses.take(numWarehouses).toList();

      for (final warehouse in selectedWarehouses) {
        final stock = _random.nextInt(20) + 5;
        final stockRef = _db.ref('warehouse_stock').push();
        await stockRef.set({
          'sku': sku,
          'warehouse': warehouse,
          'stock': stock,
          'reserved': 0,
          'available': stock,
          'last_updated': ServerValue.timestamp,
        });
      }

      AppLogger.info('Test spare part generated: $sku', category: LogCategory.system);

    } catch (e) {
      AppLogger.error('Failed to generate test spare part', error: e, category: LogCategory.system);
      rethrow;
    }
  }
}