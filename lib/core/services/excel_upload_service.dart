// lib/core/services/excel_upload_service.dart
import 'dart:typed_data';
import 'dart:async';
import 'package:excel/excel.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_logger.dart';
import '../config/env_config.dart';

// Import progress tracking class
class ImportProgress {
  final int processedCount;
  final int successCount;
  final int errorCount;
  final List<String> errors;
  final String currentItem;
  final bool isCompleted;
  final bool hasError;

  const ImportProgress({
    required this.processedCount,
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.currentItem,
    required this.isCompleted,
    this.hasError = false,
  });

  ImportProgress copyWith({
    int? processedCount,
    int? successCount,
    int? errorCount,
    List<String>? errors,
    String? currentItem,
    bool? isCompleted,
    bool? hasError,
  }) {
    return ImportProgress(
      processedCount: processedCount ?? this.processedCount,
      successCount: successCount ?? this.successCount,
      errorCount: errorCount ?? this.errorCount,
      errors: errors ?? this.errors,
      currentItem: currentItem ?? this.currentItem,
      isCompleted: isCompleted ?? this.isCompleted,
      hasError: hasError ?? this.hasError,
    );
  }
}

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
              // Add warehouse stock data
              '999': _parseStock(_getCellValue(row, headerIndex['999'])),
              'CA': _parseStock(_getCellValue(row, headerIndex['CA'])),
              'CA1': _parseStock(_getCellValue(row, headerIndex['CA1'])),
              'CA2': _parseStock(_getCellValue(row, headerIndex['CA2'])),
              'CA3': _parseStock(_getCellValue(row, headerIndex['CA3'])),
              'CA4': _parseStock(_getCellValue(row, headerIndex['CA4'])),
              'COCZ': _parseStock(_getCellValue(row, headerIndex['COCZ'])),
              'COPZ': _parseStock(_getCellValue(row, headerIndex['COPZ'])),
              'INT': _parseStock(_getCellValue(row, headerIndex['INT'])),
              'MEE': _parseStock(_getCellValue(row, headerIndex['MEE'])),
              'PU': _parseStock(_getCellValue(row, headerIndex['PU'])),
              'SI': _parseStock(_getCellValue(row, headerIndex['SI'])),
              'XCA': _parseStock(_getCellValue(row, headerIndex['XCA'])),
              'XPU': _parseStock(_getCellValue(row, headerIndex['XPU'])),
              'XZRE': _parseStock(_getCellValue(row, headerIndex['XZRE'])),
              'ZRE': _parseStock(_getCellValue(row, headerIndex['ZRE'])),
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
              // Add warehouse stock data
              '999': _parseStock(_getCellValue(row, headerIndex['999'])),
              'CA': _parseStock(_getCellValue(row, headerIndex['CA'])),
              'CA1': _parseStock(_getCellValue(row, headerIndex['CA1'])),
              'CA2': _parseStock(_getCellValue(row, headerIndex['CA2'])),
              'CA3': _parseStock(_getCellValue(row, headerIndex['CA3'])),
              'CA4': _parseStock(_getCellValue(row, headerIndex['CA4'])),
              'COCZ': _parseStock(_getCellValue(row, headerIndex['COCZ'])),
              'COPZ': _parseStock(_getCellValue(row, headerIndex['COPZ'])),
              'INT': _parseStock(_getCellValue(row, headerIndex['INT'])),
              'MEE': _parseStock(_getCellValue(row, headerIndex['MEE'])),
              'PU': _parseStock(_getCellValue(row, headerIndex['PU'])),
              'SI': _parseStock(_getCellValue(row, headerIndex['SI'])),
              'XCA': _parseStock(_getCellValue(row, headerIndex['XCA'])),
              'XPU': _parseStock(_getCellValue(row, headerIndex['XPU'])),
              'XZRE': _parseStock(_getCellValue(row, headerIndex['XZRE'])),
              'ZRE': _parseStock(_getCellValue(row, headerIndex['ZRE'])),
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

  static int? _parseStock(String stockStr) {
    if (stockStr.isEmpty) return null;
    // Remove any non-numeric characters and parse
    final cleanStr = stockStr.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanStr.isEmpty) return null;
    return int.tryParse(cleanStr);
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

  // Enhanced save products with progress streaming and batch processing
  static Future<Map<String, dynamic>> saveProductsWithProgress(
    List<Map<String, dynamic>> products, {
    bool clearExisting = false,
    String duplicateHandling = 'update', // 'update', 'skip', 'error'
    StreamController<ImportProgress>? progressController,
  }) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admin can save products');
    }

    // Validate product limit (10,000 as mentioned in docs)
    if (products.length > 10000) {
      throw Exception('Product import limit exceeded. Maximum 10,000 products allowed per import.');
    }

    int successCount = 0;
    int errorCount = 0;
    int skippedCount = 0;
    int updatedCount = 0;
    List<String> errors = [];
    List<String> detailedErrors = [];
    Map<String, String>? rollbackData;

    try {
      // Create rollback snapshot if clearing existing data
      if (clearExisting) {
        rollbackData = await _createRollbackSnapshot();
        await _db.ref('products').remove();
        AppLogger.info('Cleared existing products for import', category: LogCategory.excel);

        progressController?.add(ImportProgress(
          processedCount: 0,
          successCount: 0,
          errorCount: 0,
          errors: [],
          currentItem: 'Cleared existing products. Starting import...',
          isCompleted: false,
        ));
      }

      // Get existing products for duplicate checking
      Map<String, String> existingSkus = {};
      if (!clearExisting && duplicateHandling != 'error') {
        final existingSnapshot = await _db.ref('products').once();
        if (existingSnapshot.snapshot.exists) {
          final existingData = Map<String, dynamic>.from(
            existingSnapshot.snapshot.value as Map
          );
          existingData.forEach((key, value) {
            final productData = Map<String, dynamic>.from(value);
            if (productData['sku'] != null) {
              existingSkus[productData['sku']] = key;
            }
          });
        }
      }

      // Process products in batches for better performance
      const batchSize = 50;
      for (int batchStart = 0; batchStart < products.length; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize).clamp(0, products.length);
        final batch = products.sublist(batchStart, batchEnd);

        // Process current batch
        final batchUpdates = <String, dynamic>{};

        for (int i = 0; i < batch.length; i++) {
          final product = batch[i];
          final globalIndex = batchStart + i;

          try {
            // Update progress
            progressController?.add(ImportProgress(
              processedCount: globalIndex + 1,
              successCount: successCount,
              errorCount: errorCount,
              errors: errors.take(5).toList(), // Show only last 5 errors
              currentItem: 'Processing: ${product['sku'] ?? 'Unknown SKU'}',
              isCompleted: false,
            ));

            // Validate required fields
            final validationResult = _validateProduct(product, globalIndex + 1);
            if (!validationResult['isValid']) {
              errorCount++;
              final error = 'Row ${globalIndex + 1}: ${validationResult['error']}';
              errors.add(error);
              detailedErrors.add(error);
              continue;
            }

            // Prepare product data
            final productData = _prepareProductData(product);
            final sku = productData['sku'];

            // Handle duplicates
            if (!clearExisting && existingSkus.containsKey(sku)) {
              switch (duplicateHandling) {
                case 'skip':
                  skippedCount++;
                  continue;
                case 'update':
                  // Update existing product
                  final existingId = existingSkus[sku]!;
                  productData['updated_at'] = ServerValue.timestamp;
                  batchUpdates['products/$existingId'] = productData;
                  updatedCount++;
                  break;
                case 'error':
                  errorCount++;
                  final error = 'Row ${globalIndex + 1}: Duplicate SKU found: $sku';
                  errors.add(error);
                  detailedErrors.add(error);
                  continue;
              }
            } else {
              // Create new product
              final newProductKey = _db.ref('products').push().key!;
              productData['created_at'] = ServerValue.timestamp;
              productData['updated_at'] = ServerValue.timestamp;
              batchUpdates['products/$newProductKey'] = productData;
            }

            successCount++;

          } catch (e) {
            errorCount++;
            final rowNumber = globalIndex + 1;
            final error = 'Row $rowNumber: ${e.toString()}';
            errors.add(error);
            detailedErrors.add(error);
            AppLogger.error('Error processing product from row $rowNumber',
              error: e, category: LogCategory.excel);
          }
        }

        // Execute batch update
        if (batchUpdates.isNotEmpty) {
          try {
            await _db.ref().update(batchUpdates);
            AppLogger.info(
              'Batch ${(batchStart / batchSize + 1).toInt()} completed: ${batchUpdates.length} products',
              category: LogCategory.excel,
            );
          } catch (e) {
            // If batch fails, try individual updates
            AppLogger.warning('Batch update failed, trying individual updates',
              category: LogCategory.excel);
            for (final entry in batchUpdates.entries) {
              try {
                await _db.ref(entry.key).set(entry.value);
              } catch (individualError) {
                errorCount++;
                errors.add('Batch item failed: ${individualError.toString()}');
              }
            }
          }
        }

        // Small delay between batches to prevent overwhelming Firebase
        if (batchEnd < products.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Force sync with all users
      await _syncWithAllUsers();

      // Final progress update
      progressController?.add(ImportProgress(
        processedCount: products.length,
        successCount: successCount,
        errorCount: errorCount,
        errors: errors.take(5).toList(),
        currentItem: 'Import completed successfully!',
        isCompleted: true,
      ));

      final result = {
        'success': true,
        'totalProducts': products.length,
        'successCount': successCount,
        'errorCount': errorCount,
        'skippedCount': skippedCount,
        'updatedCount': updatedCount,
        'errors': detailedErrors,
        'duplicateHandling': duplicateHandling,
        'message': _buildSuccessMessage(products.length, successCount, errorCount,
                   skippedCount, updatedCount, duplicateHandling),
        'rollbackData': rollbackData, // For potential rollback
      };

      // Log the upload
      await logUpload(result);

      return result;

    } catch (e) {
      // Handle catastrophic failure with rollback
      if (rollbackData != null) {
        try {
          await _performRollback(rollbackData);
          AppLogger.info('Rollback completed due to import failure',
            category: LogCategory.excel);
        } catch (rollbackError) {
          AppLogger.error('Rollback failed', error: rollbackError,
            category: LogCategory.excel);
        }
      }

      progressController?.add(ImportProgress(
        processedCount: products.length,
        successCount: successCount,
        errorCount: errorCount + 1,
        errors: [...errors, e.toString()],
        currentItem: 'Import failed: ${e.toString()}',
        isCompleted: true,
        hasError: true,
      ));

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Import failed: ${e.toString()}',
        'rollbackPerformed': rollbackData != null,
      };
    }
  }

  // Backward compatibility - delegate to new method
  static Future<Map<String, dynamic>> saveProducts(
    List<Map<String, dynamic>> products, {
    bool clearExisting = false,
  }) async {
    return saveProductsWithProgress(
      products,
      clearExisting: clearExisting,
      duplicateHandling: 'update',
    );
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
        'skipped_count': result['skippedCount'] ?? 0,
        'updated_count': result['updatedCount'] ?? 0,
        'duplicate_handling': result['duplicateHandling'] ?? 'update',
        'has_errors': (result['errorCount'] ?? 0) > 0,
        'import_method': 'excel_preview',
      });
    } catch (e) {
      AppLogger.error('Error logging upload', error: e, category: LogCategory.excel);
    }
  }

  // Helper methods for enhanced functionality

  static Map<String, dynamic> _validateProduct(Map<String, dynamic> product, int rowNumber) {
    final List<String> errors = [];

    // Required field validation
    if (product['sku'] == null || product['sku'].toString().trim().isEmpty) {
      errors.add('SKU is required');
    }

    // SKU format validation (basic)
    final sku = product['sku']?.toString().trim() ?? '';
    if (sku.length > 50) {
      errors.add('SKU too long (max 50 characters)');
    }

    if (sku.contains(RegExp(r'[^a-zA-Z0-9\\-_]'))) {
      errors.add('SKU contains invalid characters (only letters, numbers, hyphens, and underscores allowed)');
    }

    // Price validation
    final priceStr = product['price']?.toString() ?? '';
    if (priceStr.isNotEmpty) {
      final price = _parsePrice(priceStr);
      if (price == null) {
        errors.add('Invalid price format');
      } else if (price < 0) {
        errors.add('Price cannot be negative');
      } else if (price > 999999.99) {
        errors.add('Price too large (max \$999,999.99)');
      }
    }

    // Stock validation
    for (final warehouse in ['999', 'CA', 'CA1', 'CA2', 'CA3', 'CA4', 'COCZ', 'COPZ', 'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU', 'XZRE', 'ZRE']) {
      if (product[warehouse] != null) {
        final stockStr = product[warehouse].toString();
        final stock = _parseStock(stockStr);
        if (stock != null && stock < 0) {
          errors.add('$warehouse stock cannot be negative');
        }
      }
    }

    // Description length validation
    final description = product['description']?.toString() ?? '';
    if (description.length > 1000) {
      errors.add('Description too long (max 1000 characters)');
    }

    return {
      'isValid': errors.isEmpty,
      'error': errors.join(', '),
      'errors': errors,
    };
  }

  static Map<String, dynamic> _prepareProductData(Map<String, dynamic> product) {
    final productData = Map<String, dynamic>.from(product);
    productData.remove('row_number');
    productData['uploaded_by'] = _auth.currentUser?.email;

    // Ensure required fields have defaults
    if (productData['name'] == null || productData['name'].toString().trim().isEmpty) {
      final sku = productData['sku']?.toString() ?? 'Unknown';
      final description = productData['description']?.toString() ?? '';
      productData['name'] = description.isEmpty
        ? sku
        : description.split(',').first.trim();
    }

    if (productData['displayName'] == null || productData['displayName'].toString().trim().isEmpty) {
      productData['displayName'] = productData['name'];
    }

    // Set default stock if not provided
    if (productData['stock'] == null) {
      productData['stock'] = 0;
    }

    // Set image URLs based on SKU
    final sku = productData['sku']?.toString() ?? '';
    if (sku.isNotEmpty) {
      productData['image_url'] = 'assets/screenshots/$sku/$sku P.1.png';
      productData['thumbnailUrl'] = 'assets/thumbnails/$sku/$sku.jpg';
    }

    return productData;
  }

  static String _buildSuccessMessage(
    int total, int success, int errors, int skipped, int updated, String duplicateHandling
  ) {
    final parts = <String>[];

    if (success > 0) {
      if (updated > 0) {
        parts.add('$updated products updated');
      }
      final newCount = success - updated;
      if (newCount > 0) {
        parts.add('$newCount new products created');
      }
    }

    if (skipped > 0) {
      parts.add('$skipped duplicates skipped');
    }

    if (errors > 0) {
      parts.add('$errors errors occurred');
    }

    final mainMessage = parts.isEmpty
      ? 'No products were processed'
      : parts.join(', ');

    return 'Import completed: $mainMessage (Total: $total products)';
  }

  static Future<Map<String, String>?> _createRollbackSnapshot() async {
    try {
      final snapshot = await _db.ref('products').once();
      if (snapshot.snapshot.exists && snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        final rollbackData = <String, String>{};

        // Store JSON representation of each product
        data.forEach((key, value) {
          rollbackData[key] = value.toString();
        });

        AppLogger.info('Created rollback snapshot with ${rollbackData.length} products',
          category: LogCategory.excel);
        return rollbackData;
      }
    } catch (e) {
      AppLogger.error('Failed to create rollback snapshot', error: e,
        category: LogCategory.excel);
    }
    return null;
  }

  static Future<void> _performRollback(Map<String, String> rollbackData) async {
    await _db.ref('products').remove();

    final updates = <String, dynamic>{};
    rollbackData.forEach((key, valueStr) {
      // This is a simplified rollback - in production you'd want to properly
      // deserialize the JSON string back to Map<String, dynamic>
      updates['products/$key'] = valueStr;
    });

    await _db.ref().update(updates);
  }
}

// Enhanced error categories for better reporting
enum ImportErrorType {
  validation,
  duplicate,
  firebase,
  format,
  system,
}

class ImportError {
  final int rowNumber;
  final String message;
  final ImportErrorType type;
  final String? field;

  const ImportError({
    required this.rowNumber,
    required this.message,
    required this.type,
    this.field,
  });

  @override
  String toString() {
    return 'Row $rowNumber: $message${field != null ? ' (Field: $field)' : ''}';
  }
}