// lib/core/services/spare_parts_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'app_logger.dart';

class SparePartsImportService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Import spare parts from the extracted JSON file into Firebase
  Future<bool> importSparePartsFromJson(String jsonFilePath) async {
    try {
      AppLogger.info('Starting spare parts import from: $jsonFilePath',
                    category: LogCategory.database);

      // Read the JSON file
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        AppLogger.error('Spare parts JSON file not found: $jsonFilePath',
                       category: LogCategory.database);
        return false;
      }

      final jsonString = await file.readAsString();
      final List<dynamic> sparePartsData = jsonDecode(jsonString);

      AppLogger.info('Found ${sparePartsData.length} spare parts to import',
                    category: LogCategory.database);

      // Process each spare part
      int successCount = 0;
      int errorCount = 0;

      for (var partData in sparePartsData) {
        try {
          final success = await _importSingleSparePart(partData);
          if (success) {
            successCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          AppLogger.error('Failed to import spare part: ${partData['sku']}',
                         error: e, category: LogCategory.database);
          errorCount++;
        }

        // Add small delay to avoid overwhelming Firebase
        await Future.delayed(Duration(milliseconds: 100));
      }

      AppLogger.info('Spare parts import completed. Success: $successCount, Errors: $errorCount',
                    category: LogCategory.database);

      return errorCount == 0;
    } catch (e) {
      AppLogger.error('Failed to import spare parts', error: e, category: LogCategory.database);
      return false;
    }
  }

  /// Import a single spare part into Firebase
  Future<bool> _importSingleSparePart(Map<String, dynamic> partData) async {
    try {
      final sku = partData['sku'] as String;

      // Create the product data structure for Firebase
      final productData = {
        'sku': sku,
        'name': partData['name'],
        'category': 'Spare Parts',
        'subcategory': 'Components',
        'price': partData['price'] ?? 0.0,
        'description': partData['description'],
        'brand': 'TurboAir',
        'model': sku, // Use SKU as model for spare parts
        'isActive': true,
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        // Additional spare parts specific fields
        'isSparepart': true,
        'originalRow': partData['original_row'],
        'warehouseStock': partData['warehouse_stock'],
      };

      // Import to products collection
      final productRef = _db.ref('products').child(sku);
      await productRef.set(productData);

      // Import warehouse stock data
      final warehouseStock = partData['warehouse_stock'] as Map<String, dynamic>;
      for (var warehouseEntry in warehouseStock.entries) {
        final warehouse = warehouseEntry.key;
        final stock = warehouseEntry.value;

        if (stock > 0) { // Only import non-zero stock
          final stockRef = _db.ref('warehouse_stock')
                              .child(warehouse)
                              .child(sku);

          await stockRef.set({
            'available': stock,
            'reserved': 0,
            'total': stock,
            'lastUpdated': ServerValue.timestamp,
            'location': warehouse,
            'sku': sku,
            'productName': partData['name'],
            'category': 'Spare Parts',
          });
        }
      }

      AppLogger.debug('Successfully imported spare part: $sku',
                     category: LogCategory.database);
      return true;

    } catch (e) {
      AppLogger.error('Failed to import spare part: ${partData['sku']}',
                     error: e, category: LogCategory.database);
      return false;
    }
  }

  /// Import spare parts data directly from Map (for testing)
  Future<bool> importSparePartsFromData(List<Map<String, dynamic>> sparePartsData) async {
    try {
      AppLogger.info('Starting spare parts import from data (${sparePartsData.length} items)',
                    category: LogCategory.database);

      int successCount = 0;
      int errorCount = 0;

      for (var partData in sparePartsData) {
        try {
          final success = await _importSingleSparePart(partData);
          if (success) {
            successCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          AppLogger.error('Failed to import spare part: ${partData['sku']}',
                         error: e, category: LogCategory.database);
          errorCount++;
        }

        // Add small delay to avoid overwhelming Firebase
        await Future.delayed(Duration(milliseconds: 100));
      }

      AppLogger.info('Spare parts import completed. Success: $successCount, Errors: $errorCount',
                    category: LogCategory.database);

      return errorCount == 0;

    } catch (e) {
      AppLogger.error('Failed to import spare parts from data', error: e, category: LogCategory.database);
      return false;
    }
  }

  /// Get all spare parts from Firebase
  Future<List<Map<String, dynamic>>> getSparePartsFromFirebase() async {
    try {
      final productsRef = _db.ref('products');
      final query = productsRef.orderByChild('category').equalTo('Spare Parts');

      final snapshot = await query.get();

      if (!snapshot.exists) {
        return [];
      }

      final List<Map<String, dynamic>> spareParts = [];
      final data = snapshot.value as Map<Object?, Object?>;

      data.forEach((key, value) {
        if (value is Map<Object?, Object?>) {
          final partData = Map<String, dynamic>.from(value);
          partData['key'] = key.toString();
          spareParts.add(partData);
        }
      });

      AppLogger.info('Retrieved ${spareParts.length} spare parts from Firebase',
                    category: LogCategory.database);

      return spareParts;

    } catch (e) {
      AppLogger.error('Failed to retrieve spare parts from Firebase',
                     error: e, category: LogCategory.database);
      return [];
    }
  }

  /// Update warehouse stock for a specific spare part
  Future<bool> updateSparePartStock(String sku, String warehouse, int stock) async {
    try {
      final stockRef = _db.ref('warehouse_stock')
                          .child(warehouse)
                          .child(sku);

      await stockRef.update({
        'available': stock,
        'total': stock,
        'lastUpdated': ServerValue.timestamp,
      });

      AppLogger.info('Updated stock for $sku in $warehouse: $stock',
                    category: LogCategory.database);
      return true;

    } catch (e) {
      AppLogger.error('Failed to update stock for $sku in $warehouse',
                     error: e, category: LogCategory.database);
      return false;
    }
  }

  /// Delete all spare parts (for cleanup/reimport)
  Future<bool> deleteAllSpareParts() async {
    try {
      AppLogger.warning('Starting deletion of all spare parts',
                       category: LogCategory.database);

      // Get all spare parts first
      final spareParts = await getSparePartsFromFirebase();

      int deleteCount = 0;
      for (var part in spareParts) {
        final sku = part['sku'] as String;

        // Delete from products
        await _db.ref('products').child(sku).remove();

        // Delete from warehouse stock
        final warehouseStock = part['warehouseStock'] as Map<String, dynamic>?;
        if (warehouseStock != null) {
          for (var warehouse in warehouseStock.keys) {
            await _db.ref('warehouse_stock').child(warehouse).child(sku).remove();
          }
        }

        deleteCount++;
      }

      AppLogger.warning('Deleted $deleteCount spare parts from Firebase',
                       category: LogCategory.database);
      return true;

    } catch (e) {
      AppLogger.error('Failed to delete spare parts', error: e, category: LogCategory.database);
      return false;
    }
  }
}