// lib/core/services/export_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'app_logger.dart';

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
      
      // Find the quote in the user's quotes
      final usersSnapshot = await _database.ref('quotes').get();
      if (!usersSnapshot.exists) {
        throw Exception('No quotes found');
      }
      
      Map<String, dynamic>? quoteData;
      String? userId;
      
      // Search through all users' quotes
      final usersData = Map<String, dynamic>.from(usersSnapshot.value as Map);
      for (var userEntry in usersData.entries) {
        final userQuotes = Map<String, dynamic>.from(userEntry.value);
        if (userQuotes.containsKey(quoteId)) {
          quoteData = Map<String, dynamic>.from(userQuotes[quoteId]);
          userId = userEntry.key;
          break;
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
                            _currencyFormat.format(quoteData['total_amount'] ?? 0),
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
      
      // Find the quote data (similar logic to PDF generation)
      final usersSnapshot = await _database.ref('quotes').get();
      if (!usersSnapshot.exists) {
        throw Exception('No quotes found in database');
      }
      
      Map<String, dynamic>? quoteData;
      String? userId;
      
      final usersData = Map<String, dynamic>.from(usersSnapshot.value as Map);
      for (var userEntry in usersData.entries) {
        final userQuotes = Map<String, dynamic>.from(userEntry.value);
        if (userQuotes.containsKey(quoteId)) {
          quoteData = Map<String, dynamic>.from(userQuotes[quoteId]);
          userId = userEntry.key;
          break;
        }
      }
      
      if (quoteData == null) {
        throw Exception('Quote not found: $quoteId');
      }
      
      final excel = Excel.createExcel();
      final sheet = excel['Quote Details'];
      
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      int currentRow = 0;
      
      // Quote Header Information
      final headerData = [
        ['Quote Number:', quoteData['quote_number'] ?? 'N/A'],
        ['Status:', quoteData['status'] ?? 'draft'],
        ['Created Date:', quoteData['created_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(quoteData['created_at']))
            : 'N/A'],
        ['Subtotal:', _currencyFormat.format(quoteData['subtotal'] ?? 0)],
        ['Tax Amount:', _currencyFormat.format(quoteData['tax_amount'] ?? 0)],
        ['Total Amount:', _currencyFormat.format(quoteData['total_amount'] ?? 0)],
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
      
      // Items Header
      final itemsHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      itemsHeaderCell.value = TextCellValue('QUOTE ITEMS');
      itemsHeaderCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
      );
      
      currentRow += 2;
      
      // Items table headers
      final itemHeaders = ['SKU', 'Product Name', 'Quantity', 'Unit Price', 'Total Price'];
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
              _currencyFormat.format(itemData['total_price'] ?? 0),
            ];
            
            for (int i = 0; i < itemRowData.length; i++) {
              final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
              cell.value = TextCellValue(itemRowData[i]);
            }
            
            currentRow++;
          }
        }
      }
      
      // Auto-adjust column widths
      sheet.setColumnWidth(0, 15.0);
      sheet.setColumnWidth(1, 30.0);
      sheet.setColumnWidth(2, 10.0);
      sheet.setColumnWidth(3, 15.0);
      sheet.setColumnWidth(4, 15.0);
      
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
}