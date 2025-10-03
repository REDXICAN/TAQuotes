// lib/core/services/database_backup_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'app_logger.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

/// Service for creating full database backups in Excel format
class DatabaseBackupService {
  static final DatabaseBackupService _instance = DatabaseBackupService._internal();
  factory DatabaseBackupService() => _instance;
  DatabaseBackupService._internal();

  final _database = FirebaseDatabase.instance;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _shortDateFormat = DateFormat('MM/dd/yyyy');

  /// Create a full database backup as Excel file
  Future<Uint8List> createFullBackup() async {
    try {
      AppLogger.info('Starting full database backup...', category: LogCategory.database);

      // Create Excel workbook
      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // Export all collections
      await _exportProducts(excel);
      await _exportClients(excel);
      await _exportQuotes(excel);
      await _exportUsers(excel);
      await _exportProjects(excel);
      await _exportWarehouseStock(excel);
      await _exportBackupMetadata(excel);

      // Encode to bytes
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      AppLogger.info('Database backup created successfully', category: LogCategory.database);
      return Uint8List.fromList(bytes);
    } catch (e) {
      AppLogger.error('Error creating database backup', error: e);
      rethrow;
    }
  }

  /// Export products collection to Excel sheet
  Future<void> _exportProducts(Excel excel) async {
    try {
      final sheet = excel['Products'];

      // Add headers
      final headers = [
        'ID', 'SKU', 'Model', 'Display Name', 'Name', 'Description',
        'Category', 'Price', 'Stock', 'Image URL', 'Thumbnail URL',
        'Spec Sheet URL', 'Manual URL', 'Is Top Seller', 'Is Featured',
        'Created At', 'Updated At'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue300);
      }

      // Fetch products
      final snapshot = await _database.ref('products').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final products = Map<String, dynamic>.from(snapshot.value as Map);
      int rowIndex = 1;

      for (final entry in products.entries) {
        final productData = Map<String, dynamic>.from(entry.value);
        productData['id'] = entry.key;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(entry.key);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(productData['sku'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(productData['model'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(productData['displayName'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(productData['name'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(productData['description'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(productData['category'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(productData['price']?.toDouble() ?? 0.0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = IntCellValue(productData['stock'] ?? 0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue(productData['imageUrl'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = TextCellValue(productData['thumbnailUrl'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = TextCellValue(productData['specSheetUrl'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value = TextCellValue(productData['manualUrl'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex)).value = TextCellValue(productData['isTopSeller'] == true ? 'Yes' : 'No');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIndex)).value = TextCellValue(productData['isFeatured'] == true ? 'Yes' : 'No');

        // Format dates
        if (productData['createdAt'] != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(productData['createdAt']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
        }

        if (productData['updatedAt'] != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(productData['updatedAt']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
        }

        rowIndex++;
      }

      AppLogger.info('Exported ${rowIndex - 1} products to Excel');
    } catch (e) {
      AppLogger.error('Error exporting products', error: e);
    }
  }

  /// Export clients collection to Excel sheet
  Future<void> _exportClients(Excel excel) async {
    try {
      final sheet = excel['Clients'];

      // Add headers
      final headers = [
        'ID', 'User ID', 'Company', 'Contact Name', 'Email', 'Phone',
        'Address', 'City', 'State', 'Zip', 'Country', 'Tax ID',
        'Created At', 'Updated At', 'Last Contact Date', 'Notes'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.green300);
      }

      // Fetch all clients from all users
      final snapshot = await _database.ref('clients').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final allClients = Map<String, dynamic>.from(snapshot.value as Map);
      int rowIndex = 1;

      for (final userEntry in allClients.entries) {
        final userId = userEntry.key;
        final userClients = Map<String, dynamic>.from(userEntry.value);

        for (final clientEntry in userClients.entries) {
          final clientData = Map<String, dynamic>.from(clientEntry.value);

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(clientEntry.key);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(userId);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(clientData['company'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(clientData['contactName'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(clientData['email'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(clientData['phone'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(clientData['address'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = TextCellValue(clientData['city'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = TextCellValue(clientData['state'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue(clientData['zip'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = TextCellValue(clientData['country'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = TextCellValue(clientData['taxId'] ?? '');

          if (clientData['createdAt'] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(clientData['createdAt']);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
          }

          if (clientData['updatedAt'] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(clientData['updatedAt']);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
          }

          if (clientData['lastContactDate'] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(clientData['lastContactDate']);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIndex)).value = TextCellValue(_shortDateFormat.format(date));
          }

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: rowIndex)).value = TextCellValue(clientData['notes'] ?? '');

          rowIndex++;
        }
      }

      AppLogger.info('Exported ${rowIndex - 1} clients to Excel');
    } catch (e) {
      AppLogger.error('Error exporting clients', error: e);
    }
  }

  /// Export quotes collection to Excel sheet
  Future<void> _exportQuotes(Excel excel) async {
    try {
      final sheet = excel['Quotes'];

      // Add headers
      final headers = [
        'ID', 'Quote Number', 'User ID', 'Client ID', 'Company Name',
        'Status', 'Total Amount', 'Tax Amount', 'Discount Amount',
        'Items Count', 'Created Date', 'Updated Date', 'Valid Until',
        'Notes', 'Terms', 'Project ID'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.orange300);
      }

      // Fetch all quotes from all users
      final snapshot = await _database.ref('quotes').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final allQuotes = Map<String, dynamic>.from(snapshot.value as Map);
      int rowIndex = 1;

      for (final userEntry in allQuotes.entries) {
        final userId = userEntry.key;
        final userQuotes = Map<String, dynamic>.from(userEntry.value);

        for (final quoteEntry in userQuotes.entries) {
          final quoteData = Map<String, dynamic>.from(quoteEntry.value);

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(quoteEntry.key);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(quoteData['quoteNumber'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(userId);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(quoteData['clientId'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(quoteData['clientCompany'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(quoteData['status'] ?? 'draft');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(quoteData['total']?.toDouble() ?? 0.0);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(quoteData['taxAmount']?.toDouble() ?? 0.0);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(quoteData['discountAmount']?.toDouble() ?? 0.0);

          final items = quoteData['items'] as List? ?? [];
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = IntCellValue(items.length);

          if (quoteData['createdAt'] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(quoteData['createdAt']);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
          }

          if (quoteData['updatedAt'] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(quoteData['updatedAt']);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
          }

          if (quoteData['validUntil'] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(quoteData['validUntil']);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value = TextCellValue(_shortDateFormat.format(date));
          }

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex)).value = TextCellValue(quoteData['notes'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIndex)).value = TextCellValue(quoteData['terms'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: rowIndex)).value = TextCellValue(quoteData['projectId'] ?? '');

          rowIndex++;
        }
      }

      // Add Quote Items sheet
      await _exportQuoteItems(excel, allQuotes);

      AppLogger.info('Exported ${rowIndex - 1} quotes to Excel');
    } catch (e) {
      AppLogger.error('Error exporting quotes', error: e);
    }
  }

  /// Export quote items to separate sheet
  Future<void> _exportQuoteItems(Excel excel, Map<String, dynamic> allQuotes) async {
    try {
      final sheet = excel['Quote Items'];

      // Add headers
      final headers = [
        'Quote ID', 'Quote Number', 'Product ID', 'Product SKU', 'Product Name',
        'Quantity', 'Unit Price', 'Total Price', 'Discount', 'Notes'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.purple300);
      }

      int rowIndex = 1;

      for (final userQuotes in allQuotes.values) {
        final quotes = Map<String, dynamic>.from(userQuotes);

        for (final quoteEntry in quotes.entries) {
          final quoteData = Map<String, dynamic>.from(quoteEntry.value);
          final items = quoteData['items'] as List? ?? [];

          for (final item in items) {
            final itemData = Map<String, dynamic>.from(item);

            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(quoteEntry.key);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(quoteData['quoteNumber'] ?? '');
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(itemData['productId'] ?? '');
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(itemData['productSku'] ?? '');
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(itemData['productName'] ?? '');
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = IntCellValue(itemData['quantity'] ?? 0);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(itemData['unitPrice']?.toDouble() ?? 0.0);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(itemData['total']?.toDouble() ?? 0.0);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(itemData['discount']?.toDouble() ?? 0.0);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue(itemData['notes'] ?? '');

            rowIndex++;
          }
        }
      }

      AppLogger.info('Exported ${rowIndex - 1} quote items to Excel');
    } catch (e) {
      AppLogger.error('Error exporting quote items', error: e);
    }
  }

  /// Export users collection to Excel sheet
  Future<void> _exportUsers(Excel excel) async {
    try {
      final sheet = excel['Users'];

      // Add headers
      final headers = [
        'User ID', 'Email', 'Display Name', 'Role', 'Status',
        'Last Login', 'Created At', 'Phone', 'Department',
        'Manager ID', 'Is Active'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.red300);
      }

      // Fetch users
      final snapshot = await _database.ref('users').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final users = Map<String, dynamic>.from(snapshot.value as Map);
      int rowIndex = 1;

      for (final entry in users.entries) {
        final userData = Map<String, dynamic>.from(entry.value);

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(entry.key);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(userData['email'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(userData['displayName'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(userData['role'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(userData['status'] ?? 'active');

        if (userData['lastLogin'] != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(userData['lastLogin']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
        }

        if (userData['createdAt'] != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(userData['createdAt']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
        }

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = TextCellValue(userData['phone'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = TextCellValue(userData['department'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue(userData['managerId'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = TextCellValue(userData['isActive'] == true ? 'Yes' : 'No');

        rowIndex++;
      }

      AppLogger.info('Exported ${rowIndex - 1} users to Excel');
    } catch (e) {
      AppLogger.error('Error exporting users', error: e);
    }
  }

  /// Export projects collection to Excel sheet
  Future<void> _exportProjects(Excel excel) async {
    try {
      final sheet = excel['Projects'];

      // Add headers
      final headers = [
        'Project ID', 'Name', 'Client ID', 'Company', 'Status',
        'Start Date', 'End Date', 'Total Value', 'Description',
        'Created By', 'Assigned To', 'Quote Count'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.yellow300);
      }

      // Fetch projects
      final snapshot = await _database.ref('projects').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final projects = Map<String, dynamic>.from(snapshot.value as Map);
      int rowIndex = 1;

      for (final entry in projects.entries) {
        final projectData = Map<String, dynamic>.from(entry.value);

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(entry.key);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(projectData['name'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(projectData['clientId'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(projectData['clientCompany'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(projectData['status'] ?? '');

        if (projectData['startDate'] != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(projectData['startDate']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(_shortDateFormat.format(date));
        }

        if (projectData['endDate'] != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(projectData['endDate']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(_shortDateFormat.format(date));
        }

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(projectData['totalValue']?.toDouble() ?? 0.0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = TextCellValue(projectData['description'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue(projectData['createdBy'] ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = TextCellValue(projectData['assignedTo'] ?? '');

        final quotes = projectData['quotes'] as List? ?? [];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = IntCellValue(quotes.length);

        rowIndex++;
      }

      AppLogger.info('Exported ${rowIndex - 1} projects to Excel');
    } catch (e) {
      AppLogger.error('Error exporting projects', error: e);
    }
  }

  /// Export warehouse stock data to Excel sheet
  Future<void> _exportWarehouseStock(Excel excel) async {
    try {
      final sheet = excel['Warehouse Stock'];

      // Add headers
      final headers = [
        'Product SKU', 'Product Name', 'Warehouse', 'Available', 'Reserved',
        'Total', 'Last Updated', 'Min Stock Level', 'Max Stock Level'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.teal300);
      }

      // Fetch products with warehouse stock
      final snapshot = await _database.ref('products').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final products = Map<String, dynamic>.from(snapshot.value as Map);
      int rowIndex = 1;

      for (final entry in products.entries) {
        final productData = Map<String, dynamic>.from(entry.value);
        final warehouseStock = productData['warehouseStock'] as Map<dynamic, dynamic>? ?? {};

        for (final stockEntry in warehouseStock.entries) {
          final warehouse = stockEntry.key.toString();
          final stock = Map<String, dynamic>.from(stockEntry.value);

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(productData['sku'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(productData['name'] ?? '');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(warehouse);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = IntCellValue(stock['available'] ?? 0);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = IntCellValue(stock['reserved'] ?? 0);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = IntCellValue((stock['available'] ?? 0) + (stock['reserved'] ?? 0));

          if (stock['lastUpdated'] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(stock['lastUpdated']);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(_dateFormat.format(date));
          }

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = IntCellValue(stock['minStockLevel'] ?? 0);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = IntCellValue(stock['maxStockLevel'] ?? 0);

          rowIndex++;
        }
      }

      AppLogger.info('Exported ${rowIndex - 1} warehouse stock records to Excel');
    } catch (e) {
      AppLogger.error('Error exporting warehouse stock', error: e);
    }
  }

  /// Export backup metadata
  Future<void> _exportBackupMetadata(Excel excel) async {
    try {
      final sheet = excel['Backup Info'];

      // Add metadata
      sheet.cell(CellIndex.indexByString('A1'))
        ..value = TextCellValue('Backup Date:')
        ..cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(_dateFormat.format(DateTime.now()));

      sheet.cell(CellIndex.indexByString('A2'))
        ..value = TextCellValue('Database:')
        ..cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue('TAQuotes Firebase Database');

      sheet.cell(CellIndex.indexByString('A3'))
        ..value = TextCellValue('Version:')
        ..cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('1.0.0');

      // Add sheet summary
      sheet.cell(CellIndex.indexByString('A5'))
        ..value = TextCellValue('Sheets Included:')
        ..cellStyle = CellStyle(bold: true);

      final sheets = [
        'Products - All product catalog data',
        'Clients - Customer information',
        'Quotes - Quote records and details',
        'Quote Items - Individual line items from quotes',
        'Users - User accounts and roles',
        'Projects - Project management data',
        'Warehouse Stock - Inventory levels by location',
      ];

      for (int i = 0; i < sheets.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6 + i)).value = TextCellValue(sheets[i]);
      }

      AppLogger.info('Added backup metadata to Excel');
    } catch (e) {
      AppLogger.error('Error adding backup metadata', error: e);
    }
  }
}