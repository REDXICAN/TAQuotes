import 'dart:io';
import 'package:excel/excel.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_logger.dart';

class UpdateSpecsFromExcel {
  static final _database = FirebaseDatabase.instance;
  
  /// Read the Excel file and update database with real specifications
  static Future<Map<String, dynamic>> updateFromExcel({
    required String excelPath,
    bool dryRun = true, // Set to false to actually update the database
  }) async {
    try {
      // Read the Excel file
      final file = File(excelPath);
      if (!file.existsSync()) {
        return {
          'success': false,
          'error': 'Excel file not found at: $excelPath',
        };
      }
      
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      
      // Get the first sheet (or specific sheet if you know the name)
      Sheet? sheet;
      for (var table in excel.tables.keys) {
        sheet = excel.tables[table];
        break; // Use first sheet
      }
      
      if (sheet == null) {
        return {
          'success': false,
          'error': 'No sheets found in Excel file',
        };
      }
      
      // Get headers from first row
      final headers = <String, int>{};
      final firstRow = sheet.rows.first;
      for (int i = 0; i < firstRow.length; i++) {
        final cell = firstRow[i];
        if (cell?.value != null) {
          headers[cell!.value.toString().trim()] = i;
        }
      }
      
      AppLogger.debug('Found headers', metadata: {'headers': headers.keys.toList()});
      
      // Map Excel headers to database fields
      final fieldMapping = {
        'SKU': 'sku',
        'Model': 'model',
        'Name': 'name',
        'Description': 'description',
        'Category': 'category',
        'Subcategory': 'subcategory',
        'Product Type': 'productType',
        'Price': 'price',
        'Voltage': 'voltage',
        'Amperage': 'amperage',
        'Amps': 'amperage', // Alternative name
        'Phase': 'phase',
        'Frequency': 'frequency',
        'Plug Type': 'plugType',
        'Dimensions': 'dimensions',
        'Dimensions (Metric)': 'dimensionsMetric',
        'Weight': 'weight',
        'Weight (Metric)': 'weightMetric',
        'Temperature Range': 'temperatureRange',
        'Temperature Range (Metric)': 'temperatureRangeMetric',
        'Refrigerant': 'refrigerant',
        'Compressor': 'compressor',
        'Capacity': 'capacity',
        'Doors': 'doors',
        'Shelves': 'shelves',
        'Features': 'features',
        'Certifications': 'certifications',
      };
      
      int updatedCount = 0;
      int totalRows = 0;
      List<Map<String, dynamic>> updates = [];
      List<String> errors = [];
      
      // Process each row (skip header row)
      for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        if (row.isEmpty) continue;
        
        totalRows++;
        
        // Get SKU or Model to identify the product
        String? productIdentifier;
        if (headers.containsKey('SKU')) {
          final skuCell = row[headers['SKU']!];
          if (skuCell?.value != null) {
            productIdentifier = skuCell!.value.toString().trim();
          }
        }
        if (productIdentifier == null && headers.containsKey('Model')) {
          final modelCell = row[headers['Model']!];
          if (modelCell?.value != null) {
            productIdentifier = modelCell!.value.toString().trim();
          }
        }
        
        if (productIdentifier == null || productIdentifier.isEmpty) {
          continue; // Skip rows without SKU or Model
        }
        
        // Build update data from Excel row
        final updateData = <String, dynamic>{};
        
        for (var entry in fieldMapping.entries) {
          final excelHeader = entry.key;
          final dbField = entry.value;
          
          if (headers.containsKey(excelHeader)) {
            final cellIndex = headers[excelHeader]!;
            if (cellIndex < row.length) {
              final cell = row[cellIndex];
              if (cell?.value != null) {
                var value = cell!.value.toString().trim();
                
                // Handle special fields that might be numbers
                if (dbField == 'doors' || dbField == 'shelves') {
                  // Try to parse as integer
                  final intValue = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (intValue != null) {
                    updateData[dbField] = intValue;
                  } else if (value.isNotEmpty) {
                    updateData[dbField] = value;
                  }
                } else if (dbField == 'price') {
                  // Try to parse as double
                  final doubleValue = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
                  if (doubleValue != null) {
                    updateData[dbField] = doubleValue;
                  }
                } else if (value.isNotEmpty && value != 'N/A' && value != 'n/a') {
                  updateData[dbField] = value;
                }
              }
            }
          }
        }
        
        if (updateData.isNotEmpty) {
          updates.add({
            'identifier': productIdentifier,
            'fields': updateData,
          });
          
          if (!dryRun) {
            // Find product in database by SKU or model
            try {
              // First try to find by SKU
              final snapshot = await _database.ref('products')
                  .orderByChild('sku')
                  .equalTo(productIdentifier)
                  .get();
              
              if (snapshot.exists) {
                final products = Map<String, dynamic>.from(snapshot.value as Map);
                for (var productId in products.keys) {
                  await _database.ref('products/$productId').update(updateData);
                  updatedCount++;
                  AppLogger.info('Updated product', metadata: {'identifier': productIdentifier});
                }
              } else {
                // Try to find by model
                final modelSnapshot = await _database.ref('products')
                    .orderByChild('model')
                    .equalTo(productIdentifier)
                    .get();
                
                if (modelSnapshot.exists) {
                  final products = Map<String, dynamic>.from(modelSnapshot.value as Map);
                  for (var productId in products.keys) {
                    await _database.ref('products/$productId').update(updateData);
                    updatedCount++;
                    AppLogger.info('Updated product by model', metadata: {'identifier': productIdentifier});
                  }
                } else {
                  errors.add('Product not found in database: $productIdentifier');
                }
              }
            } catch (e) {
              errors.add('Error updating $productIdentifier: $e');
            }
          } else {
            updatedCount++;
          }
        }
      }
      
      return {
        'success': true,
        'dryRun': dryRun,
        'totalRowsInExcel': totalRows,
        'productsToUpdate': updatedCount,
        'updates': updates.take(10).toList(), // Show first 10 for preview
        'errors': errors,
        'headers': headers.keys.toList(),
        'message': dryRun 
            ? 'Dry run complete. Set dryRun=false to actually update database.'
            : 'Database updated successfully!',
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get a preview of what will be updated
  static Future<Map<String, dynamic>> previewExcelData({
    required String excelPath,
    int previewRows = 5,
  }) async {
    try {
      final file = File(excelPath);
      if (!file.existsSync()) {
        return {
          'success': false,
          'error': 'Excel file not found at: $excelPath',
        };
      }
      
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      
      Sheet? sheet;
      for (var table in excel.tables.keys) {
        sheet = excel.tables[table];
        break;
      }
      
      if (sheet == null) {
        return {
          'success': false,
          'error': 'No sheets found in Excel file',
        };
      }
      
      // Get headers
      final headers = <String>{};
      final firstRow = sheet.rows.first;
      for (var cell in firstRow) {
        if (cell?.value != null) {
          headers.add(cell!.value.toString());
        }
      }
      
      // Get preview data
      final previewData = <Map<String, String>>[];
      for (int i = 1; i <= previewRows && i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final rowData = <String, String>{};
        
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final cell = row[j];
          rowData[headers.elementAt(j)] = cell?.value?.toString() ?? '';
        }
        
        previewData.add(rowData);
      }
      
      return {
        'success': true,
        'headers': headers.toList(),
        'totalRows': sheet.rows.length - 1, // Exclude header row
        'preview': previewData,
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}