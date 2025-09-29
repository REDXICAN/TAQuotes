// lib/core/services/export_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'app_logger.dart';
import '../models/models.dart';

class ExportService {
  static final _database = FirebaseDatabase.instance;
  static final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFormat = DateFormat('MMMM dd, yyyy');

  // Generate PDF for a quote with comprehensive error handling
  static Future<Uint8List> generateQuotePDF(String quoteId) async {
    AppLogger.info('Starting PDF generation for quote: $quoteId', category: LogCategory.business);
    final stopwatch = AppLogger.startTimer();
    
    try {
      if (quoteId.isEmpty) {
        throw Exception('Quote ID cannot be empty');
      }
      
      final pdf = pw.Document();
      
      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Try to get quote from current user's quotes first
      Map<String, dynamic>? quoteData;
      String? userId = currentUser.uid;
      
      final userQuoteSnapshot = await _database.ref('quotes/$userId/$quoteId').get();
      if (userQuoteSnapshot.exists) {
        quoteData = Map<String, dynamic>.from(userQuoteSnapshot.value as Map);
      } else {
        // If not found in user's quotes, check if user is admin
        final userEmail = currentUser.email;
        if (userEmail == 'andres@turboairmexico.com') {
          // Admin can search all quotes
          final usersSnapshot = await _database.ref('quotes').get();
          if (usersSnapshot.exists) {
            final usersData = Map<String, dynamic>.from(usersSnapshot.value as Map);
            for (var userEntry in usersData.entries) {
              final userQuotes = Map<String, dynamic>.from(userEntry.value);
              if (userQuotes.containsKey(quoteId)) {
                quoteData = Map<String, dynamic>.from(userQuotes[quoteId]);
                userId = userEntry.key;
                break;
              }
            }
          }
        }
      }
      
      if (quoteData == null) {
        throw Exception('Quote not found');
      }
      
      // Fetch client data
      Map<String, dynamic>? clientData;
      if (quoteData['client_id'] != null) {
        final clientSnapshot = await _database.ref('clients/$userId/${quoteData['client_id']}').get();
        if (clientSnapshot.exists) {
          clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
        }
      }
      
      // Get quote items from the quote data itself
      List<Map<String, dynamic>> items = [];
      
      // Handle both array and map structures for quote_items
      if (quoteData['quote_items'] != null) {
        if (quoteData['quote_items'] is List) {
          // Items stored as array
          for (var itemData in quoteData['quote_items']) {
            if (itemData != null) {
              final item = Map<String, dynamic>.from(itemData);
              
              // Fetch product details
              if (item['product_id'] != null) {
                final productSnapshot = await _database.ref('products/${item['product_id']}').get();
                if (productSnapshot.exists) {
                  item['product'] = Map<String, dynamic>.from(productSnapshot.value as Map);
                }
              }
              
              items.add(item);
            }
          }
        } else if (quoteData['quote_items'] is Map) {
          // Items stored as map
          final itemsMap = Map<String, dynamic>.from(quoteData['quote_items']);
          for (var entry in itemsMap.entries) {
            if (entry.value != null) {
              final item = Map<String, dynamic>.from(entry.value);
              
              // Fetch product details
              if (item['product_id'] != null) {
                final productSnapshot = await _database.ref('products/${item['product_id']}').get();
                if (productSnapshot.exists) {
                  item['product'] = Map<String, dynamic>.from(productSnapshot.value as Map);
                }
              }
              
              items.add(item);
            }
          }
        }
      }
      
      // Log items found for debugging
      AppLogger.info('PDF Generation: Found ${items.length} items for quote $quoteId', 
        category: LogCategory.business);
    
      // Try to load logo
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logos/turbo_air_logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        // Logo not found, continue without it
        AppLogger.debug('Logo not found, continuing without it', category: LogCategory.business);
      }
    
      // Build PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header with logo
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 50,
                          height: 50,
                          child: pw.Image(logoImage),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TURBO AIR QUOTES',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Professional Equipment Solutions',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Quote #${quoteData!['quote_number'] ?? 'N/A'}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _dateFormat.format(
                          DateTime.fromMillisecondsSinceEpoch(quoteData['created_at'] ?? DateTime.now().millisecondsSinceEpoch),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Client Information
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CLIENT INFORMATION',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    if (clientData != null) ...[
                      pw.Text(
                        clientData['company'] ?? 'Unknown Company',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (clientData['contact_name'] != null && clientData['contact_name'].isNotEmpty)
                        pw.Text(clientData['contact_name']),
                      if (clientData['email'] != null && clientData['email'].isNotEmpty)
                        pw.Text(clientData['email']),
                      if (clientData['phone'] != null && clientData['phone'].isNotEmpty)
                        pw.Text(clientData['phone']),
                      if (clientData['address'] != null && clientData['address'].isNotEmpty)
                        pw.Text(clientData['address']),
                    ] else
                      pw.Text('No client information available'),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Items Table
              pw.Text(
                'QUOTE ITEMS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 8),
              
              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text('SKU', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    pw.Expanded(child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Expanded(child: pw.Text('Disc %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    pw.Expanded(child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),
              
              // Table Items
              ...items.map((item) {
                final product = item['product'] as Map<String, dynamic>?;
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 2, child: pw.Text(product?['sku'] ?? 'N/A')),
                      pw.Expanded(flex: 3, child: pw.Text(product?['name'] ?? 'Unknown Product')),
                      pw.Expanded(child: pw.Text(item['quantity'].toString(), textAlign: pw.TextAlign.center)),
                      pw.Expanded(child: pw.Text(_currencyFormat.format(item['unit_price'] ?? 0), textAlign: pw.TextAlign.right)),
                      pw.Expanded(child: pw.Text(
                        item['discount'] != null && item['discount'] > 0 
                          ? '${item['discount']}%' 
                          : '-',
                        textAlign: pw.TextAlign.center,
                        style: item['discount'] != null && item['discount'] > 0 
                          ? const pw.TextStyle(color: PdfColors.green)
                          : null,
                      )),
                      pw.Expanded(child: pw.Text(_currencyFormat.format(item['total_price'] ?? 0), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),
              
              pw.SizedBox(height: 30),
              
              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:'),
                          pw.Text(_currencyFormat.format(quoteData['subtotal'] ?? 0)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      // Add discount if it exists
                      if (quoteData['discount_amount'] != null && quoteData['discount_amount'] > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Discount:'),
                            pw.Text('-${_currencyFormat.format(quoteData['discount_amount'])}',
                              style: const pw.TextStyle(color: PdfColors.green)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                      ],
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Tax:'),
                          pw.Text(_currencyFormat.format(quoteData['tax_amount'] ?? 0)),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total:',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            _currencyFormat.format(quoteData['total_amount'] ?? quoteData['total'] ?? 0),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              pw.SizedBox(height: 40),
              
              // Comments section if available
              if (quoteData['comments'] != null && quoteData['comments'].toString().isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NOTES / COMMENTS',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        quoteData['comments'].toString(),
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
              ],
              
              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TERMS & CONDITIONS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'This quote is valid for 30 days from the date of issue. Prices are subject to change without notice. Payment terms: Net 30 days.',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );
      
      AppLogger.logTimer('PDF generation completed', stopwatch);
      return pdf.save();
    } catch (e, stackTrace) {
      AppLogger.error('Error generating PDF for quote $quoteId', 
          error: e, stackTrace: stackTrace, category: LogCategory.business);
      
      // Return a detailed error PDF with user-friendly message
      final errorPdf = pw.Document();
      errorPdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Error Generating PDF',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Quote ID: $quoteId',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Please try again or contact support if the issue persists.',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Error details: ${e.toString()}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
      return errorPdf.save();
    }
  }
  
  // Generate Excel file for quotes data
  static Future<Uint8List> generateQuotesExcel(List<Map<String, dynamic>> quotesData) async {
    AppLogger.info('Starting Excel generation for ${quotesData.length} quotes', category: LogCategory.business);
    final stopwatch = AppLogger.startTimer();
    
    try {
      if (quotesData.isEmpty) {
        throw Exception('No quotes data provided for Excel export');
      }
      
      final excel = Excel.createExcel();
      final sheet = excel['Quotes'];
      
      // Remove default sheet if it exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      // Add headers
      final headers = [
        'Quote Number',
        'Client Company',
        'Client Contact',
        'Client Email',
        'Status',
        'Created Date',
        'Items Count',
        'Subtotal',
        'Tax Amount',
        'Total Amount',
      ];
      
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
        );
      }
      
      // Add data rows
      for (int rowIndex = 0; rowIndex < quotesData.length; rowIndex++) {
        final quote = quotesData[rowIndex];
        final dataRowIndex = rowIndex + 1;
        
        final rowData = [
          quote['quote_number'] ?? 'N/A',
          quote['client']?['company'] ?? 'N/A',
          quote['client']?['contact_name'] ?? 'N/A',
          quote['client']?['email'] ?? 'N/A',
          quote['status'] ?? 'draft',
          quote['created_at'] != null 
              ? DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(quote['created_at']))
              : 'N/A',
          quote['items']?.length?.toString() ?? '0',
          quote['subtotal']?.toString() ?? '0.00',
          quote['tax_amount']?.toString() ?? '0.00',
          quote['total_amount']?.toString() ?? '0.00',
        ];
        
        for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: dataRowIndex));
          cell.value = TextCellValue(rowData[colIndex]);
          
          // Apply alternating row colors
          if (rowIndex % 2 == 1) {
            // Skip alternating row colors for now
          }
        }
      }
      
      // Auto-adjust column widths
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15.0);
      }
      
      AppLogger.logTimer('Excel generation completed', stopwatch);
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to encode Excel file');
      return Uint8List.fromList(bytes);
    } catch (e, stackTrace) {
      AppLogger.error('Error generating Excel file', 
          error: e, stackTrace: stackTrace, category: LogCategory.business);
      
      // Create a simple error Excel file
      final errorExcel = Excel.createExcel();
      final errorSheet = errorExcel['Error'];
      
      if (errorExcel.sheets.containsKey('Sheet1')) {
        errorExcel.delete('Sheet1');
      }
      
      final errorCell = errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      errorCell.value = TextCellValue('Error generating Excel: ${e.toString()}');
      errorCell.cellStyle = CellStyle(bold: true);
      
      final errorBytes = errorExcel.save();
      if (errorBytes == null || errorBytes.isEmpty) {
        throw Exception('Failed to encode error Excel');
      }
      return Uint8List.fromList(errorBytes);
    }
  }
  
  // Generate Excel file for single quote with items details
  static Future<Uint8List> generateQuoteExcel(String quoteId) async {
    AppLogger.info('Starting Excel generation for quote: $quoteId', category: LogCategory.business);
    final stopwatch = AppLogger.startTimer();
    
    try {
      if (quoteId.isEmpty) {
        throw Exception('Quote ID cannot be empty');
      }
      
      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Try to get quote from current user's quotes first
      Map<String, dynamic>? quoteData;
      String? userId = currentUser.uid;
      
      final userQuoteSnapshot = await _database.ref('quotes/$userId/$quoteId').get();
      if (userQuoteSnapshot.exists) {
        quoteData = Map<String, dynamic>.from(userQuoteSnapshot.value as Map);
      } else {
        // If not found in user's quotes, check if user is admin
        final userEmail = currentUser.email;
        if (userEmail == 'andres@turboairmexico.com') {
          // Admin can search all quotes
          final usersSnapshot = await _database.ref('quotes').get();
          if (usersSnapshot.exists) {
            final usersData = Map<String, dynamic>.from(usersSnapshot.value as Map);
            for (var userEntry in usersData.entries) {
              final userQuotes = Map<String, dynamic>.from(userEntry.value);
              if (userQuotes.containsKey(quoteId)) {
                quoteData = Map<String, dynamic>.from(userQuotes[quoteId]);
                userId = userEntry.key;
                break;
              }
            }
          }
        }
      }
      
      if (quoteData == null) {
        throw Exception('Quote not found: $quoteId');
      }
      
      // Fetch client data if available
      Map<String, dynamic>? clientData;
      if (quoteData['client_id'] != null && userId != null) {
        final clientSnapshot = await _database.ref('clients/$userId/${quoteData['client_id']}').get();
        if (clientSnapshot.exists) {
          clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
        }
      }
      
      final excel = Excel.createExcel();
      final sheet = excel['Quote Details'];
      
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      int currentRow = 0;
      
      // Title
      final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      titleCell.value = TextCellValue('TURBO AIR QUOTES');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 18,
      );
      
      currentRow++;
      
      final subtitleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      subtitleCell.value = TextCellValue('Professional Equipment Solutions');
      
      currentRow += 2;
      
      // Quote Header Information
      final headerData = [
        ['Quote Number:', quoteData['quote_number'] ?? 'N/A'],
        ['Status:', quoteData['status'] ?? 'draft'],
        ['Created Date:', quoteData['created_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(quoteData['created_at']))
            : 'N/A'],
      ];
      
      for (final row in headerData) {
        final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
        labelCell.value = TextCellValue(row[0]);
        labelCell.cellStyle = CellStyle(bold: true);
        
        final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
        valueCell.value = TextCellValue(row[1]);
        
        currentRow++;
      }
      
      currentRow += 2; // Add spacing
      
      // Client Information Section
      final clientHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      clientHeaderCell.value = TextCellValue('CLIENT INFORMATION');
      clientHeaderCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
      );
      
      currentRow++;
      
      if (clientData != null) {
        final clientInfo = [
          ['Company:', clientData['company'] ?? 'Unknown Company'],
          ['Contact Name:', clientData['contact_name'] ?? 'N/A'],
          ['Email:', clientData['email'] ?? 'N/A'],
          ['Phone:', clientData['phone'] ?? 'N/A'],
          ['Address:', clientData['address'] ?? 'N/A'],
        ];
        
        for (final row in clientInfo) {
          if (row[1] != 'N/A' && row[1].toString().isNotEmpty) {
            final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
            labelCell.value = TextCellValue(row[0]);
            labelCell.cellStyle = CellStyle(bold: true);
            
            final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
            valueCell.value = TextCellValue(row[1]);
            
            currentRow++;
          }
        }
      } else {
        final noClientCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
        noClientCell.value = TextCellValue('No client information available');
        currentRow++;
      }
      
      currentRow += 2; // Add spacing
      
      // Items Header
      final itemsHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      itemsHeaderCell.value = TextCellValue('QUOTE ITEMS');
      itemsHeaderCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
      );
      
      currentRow += 2;
      
      // Items table headers
      final itemHeaders = ['SKU', 'Product Name', 'Quantity', 'Unit Price', 'Discount %', 'Total Price'];
      for (int i = 0; i < itemHeaders.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(itemHeaders[i]);
        cell.cellStyle = CellStyle(
          bold: true,
        );
      }
      
      currentRow++;
      
      // Items data
      if (quoteData['quote_items'] != null) {
        List<dynamic> items = [];
        
        // Handle both array and map structures
        if (quoteData['quote_items'] is List) {
          items = quoteData['quote_items'] as List;
        } else if (quoteData['quote_items'] is Map) {
          items = (quoteData['quote_items'] as Map).values.toList();
        }
        
        AppLogger.info('Excel Generation: Processing ${items.length} items', category: LogCategory.business);
            
        for (final itemData in items) {
          if (itemData is Map) {
            // Fetch product details
            Map<String, dynamic>? productData;
            if (itemData['product_id'] != null) {
              final productSnapshot = await _database.ref('products/${itemData['product_id']}').get();
              if (productSnapshot.exists) {
                productData = Map<String, dynamic>.from(productSnapshot.value as Map);
              }
            }
            
            final itemRowData = [
              productData?['sku'] ?? 'N/A',
              productData?['name'] ?? 'Unknown Product',
              itemData['quantity']?.toString() ?? '1',
              _currencyFormat.format(itemData['unit_price'] ?? 0),
              itemData['discount'] != null && itemData['discount'] > 0 
                ? '${itemData['discount']}%' 
                : '-',
              _currencyFormat.format(itemData['total_price'] ?? 0),
            ];
            
            for (int i = 0; i < itemRowData.length; i++) {
              final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
              cell.value = TextCellValue(itemRowData[i]);
              // Highlight discount cell if there's a discount
              if (i == 4 && itemData['discount'] != null && itemData['discount'] > 0) {
                cell.cellStyle = CellStyle(fontColorHex: ExcelColor.fromHexString('#00AA00'));
              }
            }
            
            currentRow++;
          }
        }
      }
      
      currentRow += 2; // Add spacing
      
      // Financial Summary Section
      final summaryHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      summaryHeaderCell.value = TextCellValue('FINANCIAL SUMMARY');
      summaryHeaderCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
      );
      
      currentRow++;
      
      final financialData = [
        ['Subtotal:', _currencyFormat.format(quoteData['subtotal'] ?? 0)],
      ];
      
      // Add discount if exists
      if (quoteData['discount_amount'] != null && quoteData['discount_amount'] > 0) {
        financialData.add(['Discount:', '-${_currencyFormat.format(quoteData['discount_amount'])}']);
      }
      
      financialData.addAll([
        ['Tax Amount:', _currencyFormat.format(quoteData['tax_amount'] ?? 0)],
        ['Total Amount:', _currencyFormat.format(quoteData['total_amount'] ?? quoteData['total'] ?? 0)],
      ]);
      
      for (final row in financialData) {
        final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
        labelCell.value = TextCellValue(row[0]);
        labelCell.cellStyle = CellStyle(bold: true);
        
        final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
        valueCell.value = TextCellValue(row[1]);
        if (row[0] == 'Total Amount:') {
          valueCell.cellStyle = CellStyle(bold: true, fontSize: 12);
        }
        
        currentRow++;
      }
      
      currentRow += 2; // Add spacing
      
      // Additional Notes/Comments if available
      if (quoteData['comments'] != null && quoteData['comments'].toString().isNotEmpty) {
        final notesHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
        notesHeaderCell.value = TextCellValue('NOTES/COMMENTS');
        notesHeaderCell.cellStyle = CellStyle(
          bold: true,
          fontSize: 14,
        );
        
        currentRow++;
        
        final notesCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
        notesCell.value = TextCellValue(quoteData['comments'].toString());
        
        currentRow++;
      }
      
      // Auto-adjust column widths
      sheet.setColumnWidth(0, 15.0);  // SKU
      sheet.setColumnWidth(1, 30.0);  // Product Name
      sheet.setColumnWidth(2, 10.0);  // Quantity
      sheet.setColumnWidth(3, 15.0);  // Unit Price
      sheet.setColumnWidth(4, 12.0);  // Discount %
      sheet.setColumnWidth(5, 15.0);  // Total Price
      
      AppLogger.logTimer('Quote Excel generation completed', stopwatch);
      
      // Save the Excel file - try with encode if save doesn't work
      List<int>? bytes;
      try {
        bytes = excel.save();
      } catch (e) {
        AppLogger.error('Excel save() failed, trying encode()', error: e, category: LogCategory.business);
        // Fallback to encode method if save fails
        try {
          bytes = excel.encode();
        } catch (encodeError) {
          AppLogger.error('Excel encode() also failed', error: encodeError, category: LogCategory.business);
          throw Exception('Failed to save Excel file: ${e.toString()}');
        }
      }
      
      if (bytes == null) {
        AppLogger.error('Excel save/encode returned null', category: LogCategory.business);
        throw Exception('Excel save returned null');
      }
      
      if (bytes.isEmpty) {
        AppLogger.error('Excel save returned empty bytes', category: LogCategory.business, data: {
          'sheets': excel.sheets.keys.toList(),
          'rowCount': currentRow,
        });
        throw Exception('Excel file is empty');
      }
      
      AppLogger.info('Excel file generated successfully', category: LogCategory.business, data: {
        'size': bytes.length,
        'sheets': excel.sheets.keys.toList(),
        'rowCount': currentRow,
      });
      
      return Uint8List.fromList(bytes);
    } catch (e, stackTrace) {
      AppLogger.error('Error generating quote Excel for $quoteId', 
          error: e, stackTrace: stackTrace, category: LogCategory.business);
      
      // Create error Excel
      final errorExcel = Excel.createExcel();
      final errorSheet = errorExcel['Error'];
      
      if (errorExcel.sheets.containsKey('Sheet1')) {
        errorExcel.delete('Sheet1');
      }
      
      final errorCell = errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      errorCell.value = TextCellValue('Error generating Excel for quote $quoteId: ${e.toString()}');
      errorCell.cellStyle = CellStyle(bold: true);
      
      final errorBytes = errorExcel.save();
      if (errorBytes == null || errorBytes.isEmpty) {
        throw Exception('Failed to encode error Excel');
      }
      return Uint8List.fromList(errorBytes);
    }
  }

  static Future<Uint8List> generateClientsExcel(List<Client> clients) async {
    AppLogger.info('Starting Excel generation for ${clients.length} clients', category: LogCategory.business);
    final stopwatch = AppLogger.startTimer();
    
    try {
      final excel = Excel.createExcel();
      
      // Delete default sheet and create new one
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      final sheet = excel['Clients'];
      
      // Header style
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
      
      // Regular cell style
      final cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
      );
      
      // Add headers
      final headers = [
        'Company',
        'Contact Name',
        'Email',
        'Phone',
        'Address',
        'City',
        'State',
        'Zip Code',
        'Notes',
        'Created Date'
      ];
      
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }
      
      // Add client data
      for (var rowIndex = 0; rowIndex < clients.length; rowIndex++) {
        final client = clients[rowIndex];
        final row = rowIndex + 1; // +1 for header row
        
        // Company
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          ..value = TextCellValue(client.company)
          ..cellStyle = cellStyle;
        
        // Contact Name
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          ..value = TextCellValue(client.contactName)
          ..cellStyle = cellStyle;
        
        // Email
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          ..value = TextCellValue(client.email)
          ..cellStyle = cellStyle;
        
        // Phone
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          ..value = TextCellValue(client.phone)
          ..cellStyle = cellStyle;
        
        // Address
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          ..value = TextCellValue(client.address ?? '')
          ..cellStyle = cellStyle;
        
        // City
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          ..value = TextCellValue(client.city ?? '')
          ..cellStyle = cellStyle;
        
        // State
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          ..value = TextCellValue(client.state ?? '')
          ..cellStyle = cellStyle;
        
        // Zip Code
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          ..value = TextCellValue(client.zipCode ?? '')
          ..cellStyle = cellStyle;
        
        // Notes
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          ..value = TextCellValue(client.notes ?? '')
          ..cellStyle = cellStyle;
        
        // Created Date
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
          ..value = TextCellValue(_dateFormat.format(client.createdAt))
          ..cellStyle = cellStyle;
      }
      
      // Auto-fit columns
      for (var i = 0; i < headers.length; i++) {
        // Auto-fit columns not available in this version
      }
      
      // Save and return bytes
      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('Failed to generate Excel file');
      }
      
      final duration = stopwatch.elapsedMilliseconds;
      AppLogger.info('Excel generated successfully', category: LogCategory.business, data: {
        'clients': clients.length,
        'duration': duration,
        'size': bytes.length,
      });
      
      return Uint8List.fromList(bytes);
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to generate clients Excel', 
        error: e, 
        stackTrace: stackTrace,
        category: LogCategory.business
      );
      
      // Return error Excel
      final errorExcel = Excel.createExcel();
      final errorSheet = errorExcel['Error'];
      if (errorExcel.sheets.containsKey('Sheet1')) {
        errorExcel.delete('Sheet1');
      }
      errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('Error generating Excel file')
        ..cellStyle = CellStyle(bold: true);
      errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = TextCellValue(e.toString());
      
      final errorBytes = errorExcel.save();
      return Uint8List.fromList(errorBytes ?? []);
    }
  }

  // Generate Excel file for products with all specifications
  static Future<Uint8List> generateProductsExcel(List<Product> products) async {
    AppLogger.info('Starting Excel generation for ${products.length} products', category: LogCategory.business);
    final stopwatch = AppLogger.startTimer();
    
    try {
      final excel = Excel.createExcel();
      
      // Delete default sheet and create new one
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      final sheet = excel['Products'];
      
      // Headers for all product specifications
      final headers = [
        'SKU',
        'Model',
        'Name',
        'Description',
        'Category',
        'Subcategory',
        'Product Type',
        'Price',
        'Stock',
        'Voltage',
        'Amperage',
        'Phase',
        'Frequency',
        'Plug Type',
        'Dimensions',
        'Dimensions (Metric)',
        'Weight',
        'Weight (Metric)',
        'Temperature Range',
        'Temperature Range (Metric)',
        'Refrigerant',
        'Compressor',
        'Capacity',
        'Doors',
        'Shelves',
        'Features',
        'Certifications',
      ];
      
      // Add headers with styling
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
        );
      }
      
      // Add product data
      int currentRow = 1;
      for (final product in products) {
        final rowData = [
          product.sku ?? '',
          product.model,
          product.name,
          product.description,
          product.category,
          product.subcategory ?? '',
          product.productType ?? '',
          _currencyFormat.format(product.price),
          product.stock.toString(),
          product.voltage ?? '',
          product.amperage ?? '',
          product.phase ?? '',
          product.frequency ?? '',
          product.plugType ?? '',
          product.dimensions ?? '',
          product.dimensionsMetric ?? '',
          product.weight ?? '',
          product.weightMetric ?? '',
          product.temperatureRange ?? '',
          product.temperatureRangeMetric ?? '',
          product.refrigerant ?? '',
          product.compressor ?? '',
          product.capacity ?? '',
          product.doors?.toString() ?? '',
          product.shelves?.toString() ?? '',
          product.features ?? '',
          product.certifications ?? '',
        ];
        
        for (int i = 0; i < rowData.length; i++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
          cell.value = TextCellValue(rowData[i]);
        }
        
        currentRow++;
      }
      
      // Auto-adjust column widths
      sheet.setColumnWidth(0, 15.0);  // SKU
      sheet.setColumnWidth(1, 15.0);  // Model
      sheet.setColumnWidth(2, 25.0);  // Name
      sheet.setColumnWidth(3, 35.0);  // Description
      sheet.setColumnWidth(4, 15.0);  // Category
      sheet.setColumnWidth(5, 15.0);  // Subcategory
      sheet.setColumnWidth(6, 15.0);  // Product Type
      sheet.setColumnWidth(7, 12.0);  // Price
      sheet.setColumnWidth(8, 10.0);  // Stock
      sheet.setColumnWidth(9, 12.0);  // Voltage
      sheet.setColumnWidth(10, 12.0); // Amperage
      sheet.setColumnWidth(11, 10.0); // Phase
      sheet.setColumnWidth(12, 12.0); // Frequency
      sheet.setColumnWidth(13, 15.0); // Plug Type
      sheet.setColumnWidth(14, 20.0); // Dimensions
      sheet.setColumnWidth(15, 20.0); // Dimensions Metric
      sheet.setColumnWidth(16, 12.0); // Weight
      sheet.setColumnWidth(17, 12.0); // Weight Metric
      sheet.setColumnWidth(18, 20.0); // Temperature Range
      sheet.setColumnWidth(19, 20.0); // Temperature Range Metric
      sheet.setColumnWidth(20, 15.0); // Refrigerant
      sheet.setColumnWidth(21, 15.0); // Compressor
      sheet.setColumnWidth(22, 15.0); // Capacity
      sheet.setColumnWidth(23, 10.0); // Doors
      sheet.setColumnWidth(24, 10.0); // Shelves
      sheet.setColumnWidth(25, 30.0); // Features
      sheet.setColumnWidth(26, 25.0); // Certifications
      
      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('Failed to generate Excel file');
      }
      
      final duration = stopwatch.elapsedMilliseconds;
      AppLogger.info('Excel generated successfully', category: LogCategory.business, data: {
        'products': products.length,
        'duration': duration,
        'size': bytes.length,
      });
      
      return Uint8List.fromList(bytes);
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to generate products Excel', 
        error: e, 
        stackTrace: stackTrace,
        category: LogCategory.business
      );
      
      // Return error Excel
      final errorExcel = Excel.createExcel();
      final errorSheet = errorExcel['Error'];
      if (errorExcel.sheets.containsKey('Sheet1')) {
        errorExcel.delete('Sheet1');
      }
      errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('Error generating Excel file')
        ..cellStyle = CellStyle(bold: true);
      errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = TextCellValue(e.toString());
      
      final errorBytes = errorExcel.save();
      return Uint8List.fromList(errorBytes ?? []);
    }
  }

  // Export all quotes to Excel
  static Future<Uint8List> exportAllQuotesToExcel() async {
    AppLogger.info('Starting bulk Excel export for all quotes', category: LogCategory.business);
    final stopwatch = AppLogger.startTimer();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      // Create main sheet
      final sheet = excel['Quotes'];

      // Add headers
      final headers = [
        'Quote Number',
        'Date',
        'Status',
        'Client Company',
        'Contact Name',
        'Email',
        'Phone',
        'Total Items',
        'Subtotal',
        'Tax',
        'Total',
        'Comments'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(headers[i]);
      }

      // Style headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.blue400,
          fontColorHex: ExcelColor.white,
          bold: true,
        );
      }

      // Fetch quotes based on user role
      Map<String, dynamic> quotesData = {};
      final userEmail = currentUser.email;

      if (userEmail == 'andres@turboairmexico.com') {
        // Admin can export all quotes
        final allQuotesSnapshot = await _database.ref('quotes').get();
        if (allQuotesSnapshot.exists) {
          final allUsersQuotes = Map<String, dynamic>.from(allQuotesSnapshot.value as Map);
          for (var userQuotes in allUsersQuotes.values) {
            if (userQuotes is Map) {
              quotesData.addAll(Map<String, dynamic>.from(userQuotes));
            }
          }
        }
      } else {
        // Regular users export only their quotes
        final userQuotesSnapshot = await _database.ref('quotes/${currentUser.uid}').get();
        if (userQuotesSnapshot.exists) {
          quotesData = Map<String, dynamic>.from(userQuotesSnapshot.value as Map);
        }
      }

      // Process each quote
      int rowIndex = 1;
      for (var entry in quotesData.entries) {
        final quoteId = entry.key;
        final quoteData = Map<String, dynamic>.from(entry.value);

        // Fetch client data if available
        String clientCompany = 'N/A';
        String contactName = 'N/A';
        String email = 'N/A';
        String phone = 'N/A';

        if (quoteData['client_id'] != null) {
          // Try to fetch client from the quote owner's clients
          final userId = quoteData['user_id'] ?? currentUser.uid;
          final clientSnapshot = await _database.ref('clients/$userId/${quoteData['client_id']}').get();
          if (clientSnapshot.exists) {
            final clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
            clientCompany = clientData['company'] ?? 'N/A';
            contactName = clientData['contact_name'] ?? 'N/A';
            email = clientData['email'] ?? 'N/A';
            phone = clientData['phone'] ?? 'N/A';
          }
        }

        // Calculate totals
        int totalItems = 0;
        double subtotal = 0;

        if (quoteData['quote_items'] != null) {
          if (quoteData['quote_items'] is List) {
            totalItems = (quoteData['quote_items'] as List).length;
            for (var item in quoteData['quote_items']) {
              if (item != null) {
                final quantity = (item['quantity'] ?? 0).toDouble();
                final price = (item['price'] ?? 0).toDouble();
                subtotal += quantity * price;
              }
            }
          } else if (quoteData['quote_items'] is Map) {
            final itemsMap = Map<String, dynamic>.from(quoteData['quote_items']);
            totalItems = itemsMap.length;
            for (var item in itemsMap.values) {
              if (item != null) {
                final quantity = (item['quantity'] ?? 0).toDouble();
                final price = (item['price'] ?? 0).toDouble();
                subtotal += quantity * price;
              }
            }
          }
        }

        final tax = subtotal * 0.0825; // 8.25% tax
        final total = subtotal + tax;

        // Add data row
        final rowData = [
          quoteData['quote_number'] ?? quoteId,
          _dateFormat.format(safeParseDateTimeWithFallback(quoteData['created_at'] ?? quoteData['createdAt'])),
          quoteData['status'] ?? 'draft',
          clientCompany,
          contactName,
          email,
          phone,
          totalItems.toString(),
          _currencyFormat.format(subtotal),
          _currencyFormat.format(tax),
          _currencyFormat.format(total),
          quoteData['comments'] ?? ''
        ];

        for (int i = 0; i < rowData.length; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
            .value = TextCellValue(rowData[i]);
        }

        rowIndex++;
      }

      // Auto-size columns
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      AppLogger.stopTimer(stopwatch, 'Bulk quotes Excel export completed', category: LogCategory.performance);
      return Uint8List.fromList(bytes);

    } catch (e, stackTrace) {
      AppLogger.error('Error generating bulk quotes Excel',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.business
      );

      // Return error Excel
      final errorExcel = Excel.createExcel();
      errorExcel.delete('Sheet1');
      final errorSheet = errorExcel['Error'];
      errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = TextCellValue('Error generating quotes export');
      errorSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = TextCellValue(e.toString());

      final errorBytes = errorExcel.save();
      return Uint8List.fromList(errorBytes ?? []);
    }
  }
}