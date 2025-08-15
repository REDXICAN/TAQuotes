// lib/core/services/excel_upload_service.dart
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';
import '../config/env_config.dart';

class ExcelUploadService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if current user is super admin
  static bool get isSuperAdmin {
    final user = _auth.currentUser;
    return user?.email == EnvConfig.adminEmail;
  }

  // Parse Excel and return preview data without saving
  static Future<Map<String, dynamic>> previewExcel(Uint8List bytes) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admin can preview products');
    }

    try {
      var excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> products = [];
      List<String> errors = [];
      
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Get headers from first row
        var headers = sheet.rows.first.map((cell) => cell?.value?.toString() ?? '').toList();
        
        // Map headers to indices
        Map<String, int> headerIndex = {};
        for (int i = 0; i < headers.length; i++) {
          headerIndex[headers[i]] = i;
        }

        // Process each row (skip header)
        for (int i = 1; i < sheet.maxRows; i++) {
          try {
            var row = sheet.rows[i];
            
            // Extract data based on headers
            String sku = _getCellValue(row, headerIndex['SKU']);
            if (sku.isEmpty) continue; // Skip rows without SKU

            String description = _getCellValue(row, headerIndex['Description']);
            String name = description.isEmpty ? sku : description.split(',').first.trim();
            
            Map<String, dynamic> productData = {
              'sku': sku,
              'model': sku, // Use SKU as model
              'name': name, // Required field
              'displayName': name, // Required field
              'category': _getCellValue(row, headerIndex['Category']),
              'subcategory': _getCellValue(row, headerIndex['Subcategory']),
              'product_type': _getCellValue(row, headerIndex['Product Type']),
              'description': description,
              'voltage': _getCellValue(row, headerIndex['Voltage']),
              'amperage': _getCellValue(row, headerIndex['Amperage']),
              'phase': _getCellValue(row, headerIndex['Phase']),
              'frequency': _getCellValue(row, headerIndex['Frequency']),
              'plug_type': _getCellValue(row, headerIndex['Plug Type']),
              'dimensions': _getCellValue(row, headerIndex['Dimensions']),
              'dimensions_metric': _getCellValue(row, headerIndex['Dimensions (Metric)']),
              'weight': _getCellValue(row, headerIndex['Weight']),
              'weight_metric': _getCellValue(row, headerIndex['Weight (Metric)']),
              'temperature_range': _getCellValue(row, headerIndex['Temperature Range']),
              'temperature_range_metric': _getCellValue(row, headerIndex['Temperature Range (Metric)']),
              'refrigerant': _getCellValue(row, headerIndex['Refrigerant']),
              'compressor': _getCellValue(row, headerIndex['Compressor']),
              'capacity': _getCellValue(row, headerIndex['Capacity']),
              'doors': _getCellValue(row, headerIndex['Doors']),
              'shelves': _getCellValue(row, headerIndex['Shelves']),
              'features': _getCellValue(row, headerIndex['Features']),
              'certifications': _getCellValue(row, headerIndex['Certifications']),
              'price': _parsePrice(_getCellValue(row, headerIndex['Price'])),
              'stock': 100, // Default stock value
              'image_url': 'assets/screenshots/$sku/P.1.png',
              'row_number': i + 1,
            };

            // Remove empty fields
            productData.removeWhere((key, value) => 
              value == null || value == '' || (value is String && value.isEmpty));

            products.add(productData);

          } catch (e) {
            errors.add('Row ${i + 1}: ${e.toString()}');
            AppLogger.warning('Error processing row $i: $e', category: LogCategory.excel);
          }
        }
      }

      return {
        'success': true,
        'products': products,
        'total': products.length,
        'errors': errors,
        'hasErrors': errors.isNotEmpty,
      };

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to parse Excel file'
      };
    }
  }

  static Future<Map<String, dynamic>> uploadExcel(Uint8List bytes) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admin can upload products');
    }

    try {
      var excel = Excel.decodeBytes(bytes);
      int totalProducts = 0;
      int successCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      // Clear existing products first (optional - comment out if you want to append)
      // await _db.ref('products').remove();

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Get headers from first row
        var headers = sheet.rows.first.map((cell) => cell?.value?.toString() ?? '').toList();
        
        // Map headers to indices
        Map<String, int> headerIndex = {};
        for (int i = 0; i < headers.length; i++) {
          headerIndex[headers[i]] = i;
        }

        // Process each row (skip header)
        for (int i = 1; i < sheet.maxRows; i++) {
          try {
            var row = sheet.rows[i];
            
            // Extract data based on headers
            String sku = _getCellValue(row, headerIndex['SKU']);
            if (sku.isEmpty) continue; // Skip rows without SKU

            totalProducts++;

            String description = _getCellValue(row, headerIndex['Description']);
            String name = description.isEmpty ? sku : description.split(',').first.trim();
            
            Map<String, dynamic> productData = {
              'sku': sku,
              'model': sku, // Use SKU as model
              'name': name, // Required field
              'displayName': name, // Required field
              'category': _getCellValue(row, headerIndex['Category']),
              'subcategory': _getCellValue(row, headerIndex['Subcategory']),
              'product_type': _getCellValue(row, headerIndex['Product Type']),
              'description': description,
              'voltage': _getCellValue(row, headerIndex['Voltage']),
              'amperage': _getCellValue(row, headerIndex['Amperage']),
              'phase': _getCellValue(row, headerIndex['Phase']),
              'frequency': _getCellValue(row, headerIndex['Frequency']),
              'plug_type': _getCellValue(row, headerIndex['Plug Type']),
              'dimensions': _getCellValue(row, headerIndex['Dimensions']),
              'dimensions_metric': _getCellValue(row, headerIndex['Dimensions (Metric)']),
              'weight': _getCellValue(row, headerIndex['Weight']),
              'weight_metric': _getCellValue(row, headerIndex['Weight (Metric)']),
              'temperature_range': _getCellValue(row, headerIndex['Temperature Range']),
              'temperature_range_metric': _getCellValue(row, headerIndex['Temperature Range (Metric)']),
              'refrigerant': _getCellValue(row, headerIndex['Refrigerant']),
              'compressor': _getCellValue(row, headerIndex['Compressor']),
              'capacity': _getCellValue(row, headerIndex['Capacity']),
              'doors': _getCellValue(row, headerIndex['Doors']),
              'shelves': _getCellValue(row, headerIndex['Shelves']),
              'features': _getCellValue(row, headerIndex['Features']),
              'certifications': _getCellValue(row, headerIndex['Certifications']),
              'price': _parsePrice(_getCellValue(row, headerIndex['Price'])),
              'stock': 100, // Default stock value
              'image_url': 'assets/screenshots/$sku/P.1.png', // Auto-generate image path
              'created_at': ServerValue.timestamp,
              'updated_at': ServerValue.timestamp,
              'uploaded_by': _auth.currentUser?.email,
            };

            // Remove empty fields
            productData.removeWhere((key, value) => 
              value == null || value == '' || (value is String && value.isEmpty));

            // Save to Firebase
            await _db.ref('products').push().set(productData);
            successCount++;

          } catch (e) {
            errorCount++;
            errors.add('Row ${i + 1}: ${e.toString()}');
            AppLogger.warning('Error processing row $i: $e', category: LogCategory.excel);
          }
        }
      }

      // Force sync with all users including demo
      await _syncWithAllUsers();

      final result = {
        'success': true,
        'totalProducts': totalProducts,
        'successCount': successCount,
        'errorCount': errorCount,
        'errors': errors,
        'message': 'Successfully uploaded $successCount products out of $totalProducts'
      };

      // Log the upload
      await logUpload(result);

      return result;

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to upload Excel file'
      };
    }
  }

  static String _getCellValue(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return '';
    return row[index]?.value?.toString() ?? '';
  }

  static double? _parsePrice(String priceStr) {
    if (priceStr.isEmpty) return null;
    
    // Remove currency symbols and commas
    String cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    
    try {
      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _syncWithAllUsers() async {
    try {
      // Update a sync flag to notify all clients
      await _db.ref('app_settings/last_product_sync').set({
        'timestamp': ServerValue.timestamp,
        'synced_by': _auth.currentUser?.email,
      });

      // Clear product caches for all users (they will reload on next access)
      await _db.ref('cache_invalidation/products').set({
        'timestamp': ServerValue.timestamp,
        'reason': 'excel_upload',
      });

      AppLogger.info('Products synced with all users', category: LogCategory.excel);
    } catch (e) {
      AppLogger.error('Error syncing products', error: e, category: LogCategory.excel);
    }
  }

  // Save previewed products to database
  static Future<Map<String, dynamic>> saveProducts(List<Map<String, dynamic>> products, {bool clearExisting = false}) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admin can save products');
    }

    int successCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    try {
      // Clear existing products if requested
      if (clearExisting) {
        await _db.ref('products').remove();
        AppLogger.info('Cleared existing products', category: LogCategory.excel);
      }

      // Save each product
      for (var product in products) {
        try {
          // Remove row_number from product data before saving
          final productData = Map<String, dynamic>.from(product);
          productData.remove('row_number');
          
          // Add timestamps
          productData['created_at'] = ServerValue.timestamp;
          productData['updated_at'] = ServerValue.timestamp;
          productData['uploaded_by'] = _auth.currentUser?.email;

          // Save to Firebase
          await _db.ref('products').push().set(productData);
          successCount++;
        } catch (e) {
          errorCount++;
          final rowNumber = product['row_number'] ?? 'Unknown';
          errors.add('Row $rowNumber: ${e.toString()}');
          AppLogger.error('Error saving product from row $rowNumber', error: e, category: LogCategory.excel);
        }
      }

      // Force sync with all users
      await _syncWithAllUsers();

      final result = {
        'success': true,
        'totalProducts': products.length,
        'successCount': successCount,
        'errorCount': errorCount,
        'errors': errors,
        'message': 'Successfully saved $successCount products out of ${products.length}'
      };

      // Log the upload
      await logUpload(result);

      return result;

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save products to database'
      };
    }
  }

  // Get upload history
  static Future<List<Map<String, dynamic>>> getUploadHistory() async {
    try {
      final snapshot = await _db.ref('upload_history').orderByChild('timestamp').limitToLast(10).once();
      
      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        return data.entries.map((entry) {
          final item = Map<String, dynamic>.from(entry.value);
          item['id'] = entry.key;
          return item;
        }).toList()
          ..sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      }
    } catch (e) {
      AppLogger.error('Error getting upload history', error: e, category: LogCategory.excel);
    }
    return [];
  }

  // Log upload to history
  static Future<void> logUpload(Map<String, dynamic> result) async {
    try {
      await _db.ref('upload_history').push().set({
        'timestamp': ServerValue.timestamp,
        'uploaded_by': _auth.currentUser?.email,
        'success_count': result['successCount'],
        'error_count': result['errorCount'],
        'total_products': result['totalProducts'],
      });
    } catch (e) {
      AppLogger.error('Error logging upload', error: e, category: LogCategory.excel);
    }
  }
}