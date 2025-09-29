#!/usr/bin/env dart
/// Import spare parts script for Turbo Air Quotes (TAQ) application
/// This script imports real spare parts data from the extracted JSON into Firebase

import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

// Firebase configuration - using environment variables
class FirebaseConfig {
  static const firebaseOptions = FirebaseOptions(
    apiKey: 'your-api-key-from-env',
    authDomain: 'taquotes.firebaseapp.com',
    databaseURL: 'https://taquotes-default-rtdb.firebaseio.com',
    projectId: 'taquotes',
    storageBucket: 'taquotes.appspot.com',
    messagingSenderId: 'your-sender-id',
    appId: 'your-app-id',
  );
}

class SparePartsImporter {
  late FirebaseDatabase _db;

  Future<void> initialize() async {
    await Firebase.initializeApp(options: FirebaseConfig.firebaseOptions);
    _db = FirebaseDatabase.instance;
    print('Firebase initialized successfully');
  }

  Future<bool> importSparePartsFromJson(String jsonFilePath) async {
    try {
      print('Starting spare parts import from: $jsonFilePath');

      // Read the JSON file
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        print('ERROR: Spare parts JSON file not found: $jsonFilePath');
        return false;
      }

      final jsonString = await file.readAsString();
      final List<dynamic> sparePartsData = jsonDecode(jsonString);

      print('Found ${sparePartsData.length} spare parts to import');

      // Process each spare part
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < sparePartsData.length; i++) {
        final partData = sparePartsData[i];
        try {
          final success = await _importSingleSparePart(partData);
          if (success) {
            successCount++;
            print('✓ Imported ${partData['sku']} (${i + 1}/${sparePartsData.length})');
          } else {
            errorCount++;
            print('✗ Failed to import ${partData['sku']} (${i + 1}/${sparePartsData.length})');
          }
        } catch (e) {
          print('✗ Error importing ${partData['sku']}: $e');
          errorCount++;
        }

        // Add small delay to avoid overwhelming Firebase
        await Future.delayed(Duration(milliseconds: 200));
      }

      print('\n=== Import Summary ===');
      print('Success: $successCount');
      print('Errors: $errorCount');
      print('Total: ${sparePartsData.length}');

      return errorCount == 0;
    } catch (e) {
      print('FATAL ERROR: Failed to import spare parts: $e');
      return false;
    }
  }

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
        'model': sku,
        'isActive': true,
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
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
        final stock = warehouseEntry.value as int;

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

      return true;
    } catch (e) {
      print('Error importing spare part ${partData['sku']}: $e');
      return false;
    }
  }

  Future<void> printImportSummary() async {
    try {
      // Get count of spare parts
      final productsRef = _db.ref('products');
      final query = productsRef.orderByChild('category').equalTo('Spare Parts');
      final snapshot = await query.get();

      int sparePartsCount = 0;
      if (snapshot.exists) {
        final data = snapshot.value as Map<Object?, Object?>;
        sparePartsCount = data.length;
      }

      // Get warehouse stock count
      final warehouseRef = _db.ref('warehouse_stock');
      final warehouseSnapshot = await warehouseRef.get();

      int totalStockEntries = 0;
      if (warehouseSnapshot.exists) {
        final warehouseData = warehouseSnapshot.value as Map<Object?, Object?>;
        warehouseData.forEach((warehouse, stockData) {
          if (stockData is Map) {
            totalStockEntries += stockData.length;
          }
        });
      }

      print('\n=== Firebase Summary ===');
      print('Spare parts in products collection: $sparePartsCount');
      print('Total warehouse stock entries: $totalStockEntries');

    } catch (e) {
      print('Error getting summary: $e');
    }
  }
}

void main(List<String> args) async {
  print('=== Turbo Air Quotes - Spare Parts Import ===\n');

  final importer = SparePartsImporter();

  try {
    // Initialize Firebase
    await importer.initialize();

    // Default JSON file path
    String jsonFile = 'spare_parts_extracted.json';

    // Check if custom path provided
    if (args.isNotEmpty) {
      jsonFile = args[0];
    }

    // Check if file exists
    if (!File(jsonFile).existsSync()) {
      print('ERROR: File not found: $jsonFile');
      print('Usage: dart import_spare_parts.dart [json_file_path]');
      print('Default: spare_parts_extracted.json');
      exit(1);
    }

    // Import spare parts
    print('Importing from: $jsonFile\n');
    final success = await importer.importSparePartsFromJson(jsonFile);

    if (success) {
      print('\n🎉 Spare parts import completed successfully!');
    } else {
      print('\n⚠️ Spare parts import completed with errors');
    }

    // Print summary
    await importer.printImportSummary();

  } catch (e) {
    print('FATAL ERROR: $e');
    exit(1);
  }

  print('\n=== Import Complete ===');
}