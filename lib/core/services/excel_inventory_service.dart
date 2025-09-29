import 'dart:io';
import 'package:excel/excel.dart';
import '../models/models.dart';
import 'app_logger.dart';

/// Service to read inventory data from Excel file
class ExcelInventoryService {
  static const String excelPath = r"O:\OneDrive\Documentos\-- TurboAir\7 Bots\09.12.25 INVENTARIO MEXICO.xlsx";

  // Cached data
  static Map<String, dynamic>? _cachedData;
  static DateTime? _lastUpdate;
  static Map<String, Map<String, dynamic>>? _cachedProductStock;
  static List<Map<String, String>>? _cachedWarehouses;
  static Map<String, int>? _cachedWarehouseTotals;

  /// Load inventory data from the Excel file
  static Future<Map<String, dynamic>> loadInventoryData() async {
    try {
      // Check if we have cached data and it's recent (less than 30 minutes old)
      if (_cachedData != null && _lastUpdate != null) {
        final timeDiff = DateTime.now().difference(_lastUpdate!);
        if (timeDiff.inMinutes < 30) {
          return _cachedData!;
        }
      }

      AppLogger.info('Loading inventory data from Excel file: $excelPath', category: LogCategory.business);

      // Read and parse the Excel file
      final excelData = await _parseExcelFile();

      if (excelData.isEmpty) {
        AppLogger.warning('Failed to parse Excel file, using fallback data', category: LogCategory.business);
        return _getFallbackData();
      }

      _cachedData = excelData;
      _lastUpdate = DateTime.now();

      AppLogger.info('Successfully loaded inventory data', data: {
        'total_products': excelData['summary']['total_products'],
        'total_inventory': excelData['summary']['total_inventory'],
        'warehouses': excelData['warehouses'].length,
      }, category: LogCategory.business);

      return excelData;
    } catch (e) {
      AppLogger.error('Error loading inventory data', error: e, category: LogCategory.business);
      return _getFallbackData();
    }
  }

  /// Parse the Excel file and extract inventory data
  static Future<Map<String, dynamic>> _parseExcelFile() async {
    try {
      final file = File(excelPath);
      if (!file.existsSync()) {
        AppLogger.warning('Excel file not found at: $excelPath', category: LogCategory.business);
        return {};
      }

      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Get the first sheet
      Sheet? sheet;
      for (var table in excel.tables.keys) {
        sheet = excel.tables[table];
        break;
      }

      if (sheet == null) {
        AppLogger.warning('No sheets found in Excel file', category: LogCategory.business);
        return {};
      }

      AppLogger.info('Found Excel sheet with ${sheet.rows.length} rows', category: LogCategory.business);

      // Parse headers from first row
      final headers = <String, int>{};
      final firstRow = sheet.rows.first;
      for (int i = 0; i < firstRow.length; i++) {
        final cell = firstRow[i];
        if (cell?.value != null) {
          final headerName = cell!.value.toString().trim().toUpperCase();
          headers[headerName] = i;
        }
      }

      AppLogger.debug('Excel headers found', data: {'headers': headers.keys.toList()});

      // Expected column mappings (based on actual Excel structure)
      final columnMappings = {
        'sku': ['CÓDIGO', 'SKU', 'CODIGO', 'MODEL', 'MODELO'],
        'name': ['NOMBRE (PRODUCTO)', 'NAME', 'NOMBRE', 'DESCRIPCION', 'DESCRIPCIÓN', 'DESCRIPTION', 'PRODUCTO'],
        'warehouse': ['WAREHOUSE', 'ALMACEN', 'ALMACÉN', 'BODEGA', 'SUCURSAL'],
        'stock': ['EXISTENCIA', 'STOCK', 'CANTIDAD', 'QTY', 'QUANTITY', 'INVENTARIO'],
      };

      // Find actual column indices
      final columnIndices = <String, int>{};
      for (var mapping in columnMappings.entries) {
        for (var possibleHeader in mapping.value) {
          if (headers.containsKey(possibleHeader)) {
            columnIndices[mapping.key] = headers[possibleHeader]!;
            break;
          }
        }
      }

      AppLogger.debug('Column mappings', data: {'mappings': columnIndices});

      // Parse data rows based on actual Excel structure
      final warehouses = <String, Map<String, String>>{};
      final warehouseTotals = <String, int>{};
      final productStock = <String, Map<String, dynamic>>{};
      int totalProducts = 0;
      int totalInventory = 0;

      // Find header row first
      int headerRowIndex = -1;
      for (int i = 0; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isNotEmpty && row[0]?.value?.toString().toUpperCase().contains('CÓDIGO') == true) {
          headerRowIndex = i;
          break;
        }
      }

      if (headerRowIndex == -1) {
        AppLogger.warning('Header row not found in Excel file', category: LogCategory.business);
        return {};
      }

      AppLogger.info('Header found at row $headerRowIndex', category: LogCategory.business);

      // Default warehouse (based on Excel structure)
      String currentWarehouse = '999';
      warehouses[currentWarehouse] = {
        'code': currentWarehouse,
        'name': 'MERCANCIA APARTADA',
      };
      warehouseTotals[currentWarehouse] = 0;

      // Parse data rows starting after header
      for (int rowIndex = headerRowIndex + 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        if (row.isEmpty) continue;

        try {
          // Check if this row defines a warehouse
          final firstCell = row[0]?.value?.toString().trim();
          if (firstCell != null && firstCell.startsWith('\'') && row.isNotEmpty) {
            // This is a warehouse definition row
            final warehouseCode = firstCell.substring(1).trim();
            final warehouseName = row.length > 1 ? (row[1]?.value?.toString().trim() ?? warehouseCode) : warehouseCode;
            currentWarehouse = warehouseCode;

            if (!warehouses.containsKey(currentWarehouse)) {
              warehouses[currentWarehouse] = {
                'code': currentWarehouse,
                'name': warehouseName,
              };
              warehouseTotals[currentWarehouse] = 0;
            }
            continue;
          }

          // Extract SKU (column 0)
          String? sku;
          if (row.isNotEmpty && row[0]?.value != null) {
            sku = row[0]!.value.toString().trim();
          }

          // Extract product name (column 1)
          String? productName;
          if (row.length > 1 && row[1]?.value != null) {
            productName = row[1]!.value.toString().trim();
          }

          // Extract stock quantity (column 2)
          int stockQty = 0;
          if (row.length > 2 && row[2]?.value != null) {
            final stockValue = row[2]!.value.toString().trim();
            stockQty = int.tryParse(stockValue.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          }

          // Only process rows with valid SKU and stock
          if (sku != null && sku.isNotEmpty && stockQty > 0 && !sku.startsWith('Almacén')) {
            // Update warehouse totals
            warehouseTotals[currentWarehouse] = (warehouseTotals[currentWarehouse] ?? 0) + stockQty;
            totalInventory += stockQty;

            // Add to product stock
            if (!productStock.containsKey(sku)) {
              productStock[sku] = {
                'name': productName ?? sku,
                'stock': <String, int>{},
              };
              totalProducts++;
            }

            final currentStock = productStock[sku]!['stock'] as Map<String, int>;
            currentStock[currentWarehouse] = (currentStock[currentWarehouse] ?? 0) + stockQty;
          }
        } catch (e) {
          AppLogger.warning('Error parsing row $rowIndex', error: e, category: LogCategory.business);
          continue;
        }
      }

      // Cache the parsed data
      _cachedProductStock = productStock;
      _cachedWarehouses = warehouses.values.toList();
      _cachedWarehouseTotals = warehouseTotals;

      return {
        'warehouses': warehouses.values.toList(),
        'warehouse_totals': warehouseTotals,
        'products': productStock,
        'summary': {
          'total_warehouses': warehouses.length,
          'total_products': totalProducts,
          'total_inventory': totalInventory,
        }
      };
    } catch (e) {
      AppLogger.error('Error parsing Excel file', error: e, category: LogCategory.business);
      return {};
    }
  }

  /// Get warehouse name based on code
  static String _getWarehouseName(String code) {
    switch (code) {
      case '999':
        return 'MERCANCIA APARTADA';
      case 'CA':
        return 'CALIFORNIA';
      case 'CA1':
        return 'CALIFORNIA 1';
      case 'CA2':
        return 'CALIFORNIA 2';
      case 'CA3':
        return 'CALIFORNIA 3';
      case 'CA4':
        return 'CALIFORNIA 4';
      case 'COCZ':
        return 'COZUMEL';
      case 'COPZ':
        return 'PLAYA DEL CARMEN';
      case 'INT':
        return 'INTERNATIONAL';
      case 'MEE':
        return 'MERIDA';
      case 'PU':
        return 'PUERTO';
      case 'SI':
        return 'SISTEMA INTEGRAL';
      case 'XCA':
        return 'CANCUN';
      case 'XPU':
        return 'PLAYA DEL CARMEN';
      case 'XZRE':
        return 'ZONA RURAL ESTE';
      case 'ZRE':
        return 'ZONA RURAL ESTE';
      default:
        return code.toUpperCase();
    }
  }

  /// Get fallback data when Excel file is not available
  static Map<String, dynamic> _getFallbackData() {
    return {
      'warehouses': [{'code': '999', 'name': 'MERCANCIA APARTADA'}],
      'warehouse_totals': {'999': 0},
      'products': <String, dynamic>{},
      'summary': {
        'total_warehouses': 1,
        'total_products': 0,
        'total_inventory': 0,
      }
    };
  }

  /// Get stock for a specific product SKU
  static Map<String, int> getProductStock(String sku) {
    if (_cachedProductStock != null && _cachedProductStock!.containsKey(sku)) {
      final stockData = _cachedProductStock![sku]!['stock'] as Map<String, int>;
      return Map<String, int>.from(stockData);
    }
    return {};
  }

  /// Get total stock for a product across all warehouses
  static int getTotalStock(String sku) {
    final stock = getProductStock(sku);
    return stock.values.fold(0, (sum, count) => sum + count);
  }

  /// Get products sorted by stock volume (highest first)
  static Future<List<Product>> getProductsSortedByStock() async {
    // Ensure data is loaded
    await loadInventoryData();

    final List<Product> products = [];

    if (_cachedProductStock != null) {
      for (final entry in _cachedProductStock!.entries) {
        final sku = entry.key;
        final productData = entry.value;
        final stockData = productData['stock'] as Map<String, int>;
        final totalStock = stockData.values.fold(0, (sum, stock) => sum + stock);

        final product = Product(
          sku: sku,
          name: productData['name'] as String,
          displayName: productData['name'] as String,
          model: sku,
          price: 0, // Price not available in inventory file
          description: '',
          category: 'Inventory',
          stock: totalStock,
          createdAt: DateTime.now(),
        );

        products.add(product);
      }
    }

    // Sort by stock volume (highest first)
    products.sort((a, b) => (b.stock ?? 0).compareTo(a.stock ?? 0));
    return products;
  }

  /// Get warehouse names list
  static List<String> getWarehouseNames() {
    if (_cachedWarehouses != null) {
      return _cachedWarehouses!.map((wh) => wh['name']!).toList();
    }
    return ['MERCANCIA APARTADA'];
  }

  /// Get warehouse codes list
  static List<String> getWarehouseCodes() {
    if (_cachedWarehouses != null) {
      return _cachedWarehouses!.map((wh) => wh['code']!).toList();
    }
    return ['999'];
  }

  /// Get warehouse totals from cached data
  static Map<String, int> get warehouseTotals {
    return _cachedWarehouseTotals ?? <String, int>{'999': 0};
  }

  /// Force refresh of Excel data
  static Future<void> refreshData() async {
    _cachedData = null;
    _lastUpdate = null;
    _cachedProductStock = null;
    _cachedWarehouses = null;
    _cachedWarehouseTotals = null;
    await loadInventoryData();
  }

  /// Get summary of inventory data for debugging
  static Future<Map<String, dynamic>> getInventorySummary() async {
    try {
      final data = await loadInventoryData();
      return {
        'excel_file_path': excelPath,
        'file_exists': File(excelPath).existsSync(),
        'last_updated': _lastUpdate?.toIso8601String(),
        'cache_age_minutes': _lastUpdate != null
            ? DateTime.now().difference(_lastUpdate!).inMinutes
            : null,
        'summary': data['summary'],
        'warehouses': data['warehouses'],
        'warehouse_totals': data['warehouse_totals'],
        'sample_products': _cachedProductStock?.keys.take(10).toList(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'excel_file_path': excelPath,
        'file_exists': File(excelPath).existsSync(),
      };
    }
  }
}