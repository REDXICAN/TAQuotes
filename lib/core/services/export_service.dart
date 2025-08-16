// lib/core/services/export_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:excel/excel.dart';

class ExportService {
  static final _database = FirebaseDatabase.instance;
  static final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFormat = DateFormat('MMMM dd, yyyy');

  // Generate PDF for a quote
  static Future<Uint8List> generateQuotePDF(String quoteId) async {
    final pdf = pw.Document();
    
    // Fetch quote data
    final quoteSnapshot = await _database.ref('quotes/$quoteId').get();
    if (!quoteSnapshot.exists) {
      throw Exception('Quote not found');
    }
    
    final quoteData = Map<String, dynamic>.from(quoteSnapshot.value as Map);
    
    // Fetch client data
    Map<String, dynamic>? clientData;
    if (quoteData['client_id'] != null) {
      final clientSnapshot = await _database.ref('clients/${quoteData['client_id']}').get();
      if (clientSnapshot.exists) {
        clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
      }
    }
    
    // Fetch quote items
    final itemsSnapshot = await _database
        .ref('quote_items')
        .orderByChild('quote_id')
        .equalTo(quoteId)
        .get();
    
    List<Map<String, dynamic>> items = [];
    if (itemsSnapshot.exists) {
      final itemsData = Map<String, dynamic>.from(itemsSnapshot.value as Map);
      for (var entry in itemsData.entries) {
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
    
    // Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TURBO AIR',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Equipment Quote',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Quote #${quoteData['quote_number']}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _dateFormat.format(
                        DateTime.fromMillisecondsSinceEpoch(quoteData['created_at'] ?? 0),
                      ),
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            
            // Client Information
            if (clientData != null) ...[
              pw.Text(
                'Bill To:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
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
                      clientData['company'] ?? '',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (clientData['contact_name'] != null)
                      pw.Text(clientData['contact_name']),
                    if (clientData['address'] != null)
                      pw.Text(clientData['address']),
                    if (clientData['city'] != null || clientData['state'] != null)
                      pw.Text(
                        '${clientData['city'] ?? ''}, ${clientData['state'] ?? ''} ${clientData['zip_code'] ?? ''}',
                      ),
                    if (clientData['phone'] != null)
                      pw.Text('Phone: ${clientData['phone']}'),
                    if (clientData['email'] != null)
                      pw.Text('Email: ${clientData['email']}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
            ],
            
            // Items Table
            pw.Text(
              'Quote Items',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    _buildTableCell('SKU', isHeader: true),
                    _buildTableCell('Description', isHeader: true),
                    _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('Unit Price', isHeader: true, align: pw.TextAlign.right),
                    _buildTableCell('Total', isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                // Item rows
                ...items.map((item) {
                  final product = item['product'] ?? {};
                  return pw.TableRow(
                    children: [
                      _buildTableCell(product['sku'] ?? ''),
                      _buildTableCell(product['product_type'] ?? ''),
                      _buildTableCell(
                        item['quantity'].toString(),
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        _currencyFormat.format(item['unit_price'] ?? 0),
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        _currencyFormat.format(item['total_price'] ?? 0),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),
              ],
            ),
            
            // Summary section
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${_currencyFormat.format(quoteData['subtotal'] ?? 0)}'),
                    pw.Text('Tax: ${_currencyFormat.format(quoteData['tax'] ?? 0)}'),
                    pw.Text(
                      'Total: ${_currencyFormat.format(quoteData['total'] ?? 0)}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
    
    return await pdf.save();
  }
  
  // Helper method to build table cells
  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
  
  // XLSX Export Functions
  
  /// Export products to XLSX format
  static Future<Uint8List> exportProductsToXLSX() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Products'];
    
    // Remove default sheet
    excel.delete('Sheet1');
    
    // Add headers
    final headers = [
      'SKU',
      'Model',
      'Description',
      'Category',
      'Subcategory',
      'Price',
      'Stock',
      'Dimensions',
      'Weight',
      'Voltage',
      'Amperage',
      'Phase',
      'Frequency',
      'Plug Type',
      'Temperature Range',
      'Refrigerant',
      'Compressor',
      'Capacity',
      'Doors',
      'Shelves',
      'Product Type',
      'Created At',
      'Updated At'
    ];
    
    // Style headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
    
    // Fetch products from Firebase
    final productsSnapshot = await _database.ref('products').get();
    if (productsSnapshot.exists) {
      final productsData = Map<String, dynamic>.from(productsSnapshot.value as Map);
      int rowIndex = 1;
      
      for (var entry in productsData.entries) {
        final product = Map<String, dynamic>.from(entry.value);
        
        final rowData = [
          product['sku'] ?? '',
          product['model'] ?? '',
          product['description'] ?? '',
          product['category'] ?? '',
          product['subcategory'] ?? '',
          product['price']?.toString() ?? '0',
          product['stock']?.toString() ?? '0',
          product['dimensions'] ?? '',
          product['weight'] ?? '',
          product['voltage'] ?? '',
          product['amperage'] ?? '',
          product['phase'] ?? '',
          product['frequency'] ?? '',
          product['plug_type'] ?? '',
          product['temperature_range'] ?? '',
          product['refrigerant'] ?? '',
          product['compressor'] ?? '',
          product['capacity'] ?? '',
          product['doors']?.toString() ?? '',
          product['shelves']?.toString() ?? '',
          product['product_type'] ?? '',
          product['created_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(product['created_at']).toString()
            : '',
          product['updated_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(product['updated_at']).toString()
            : '',
        ];
        
        for (int i = 0; i < rowData.length; i++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
          cell.value = TextCellValue(rowData[i]);
          
          // Alternate row colors
          if (rowIndex % 2 == 0) {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F2F2F2'));
          }
        }
        rowIndex++;
      }
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 15);
    }
    
    return Uint8List.fromList(excel.encode()!);
  }
  
  /// Export clients to XLSX format
  static Future<Uint8List> exportClientsToXLSX(String userId) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Clients'];
    
    // Remove default sheet
    excel.delete('Sheet1');
    
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
      'Country',
      'Notes',
      'Created At',
      'Updated At'
    ];
    
    // Style headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#70AD47'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
    
    // Fetch clients from Firebase
    final clientsSnapshot = await _database.ref('clients/$userId').get();
    if (clientsSnapshot.exists) {
      final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);
      int rowIndex = 1;
      
      for (var entry in clientsData.entries) {
        final client = Map<String, dynamic>.from(entry.value);
        
        final rowData = [
          client['company'] ?? '',
          client['contact_name'] ?? '',
          client['email'] ?? '',
          client['phone'] ?? '',
          client['address'] ?? '',
          client['city'] ?? '',
          client['state'] ?? '',
          client['zip_code'] ?? '',
          client['country'] ?? '',
          client['notes'] ?? '',
          client['created_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(client['created_at']).toString()
            : '',
          client['updated_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(client['updated_at']).toString()
            : '',
        ];
        
        for (int i = 0; i < rowData.length; i++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
          cell.value = TextCellValue(rowData[i]);
          
          // Alternate row colors
          if (rowIndex % 2 == 0) {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F2F2F2'));
          }
        }
        rowIndex++;
      }
    }
    
    // Auto-fit columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 15);
    }
    
    return Uint8List.fromList(excel.encode()!);
  }
  
  /// Export quotes to XLSX format
  static Future<Uint8List> exportQuotesToXLSX(String userId) async {
    final excel = Excel.createExcel();
    final Sheet quotesSheet = excel['Quotes'];
    final Sheet itemsSheet = excel['Quote Items'];
    
    // Remove default sheet
    excel.delete('Sheet1');
    
    // === QUOTES SHEET ===
    final quoteHeaders = [
      'Quote Number',
      'Client Company',
      'Status',
      'Subtotal',
      'Tax Rate (%)',
      'Tax Amount',
      'Total Amount',
      'Created At',
      'Updated At'
    ];
    
    // Style quote headers
    for (int i = 0; i < quoteHeaders.length; i++) {
      final cell = quotesSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(quoteHeaders[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E67E22'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
    
    // === QUOTE ITEMS SHEET ===
    final itemHeaders = [
      'Quote Number',
      'SKU',
      'Product Description',
      'Quantity',
      'Unit Price',
      'Total Price'
    ];
    
    // Style item headers
    for (int i = 0; i < itemHeaders.length; i++) {
      final cell = itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(itemHeaders[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#8E44AD'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
    
    // Fetch quotes from Firebase
    final quotesSnapshot = await _database.ref('quotes/$userId').get();
    if (quotesSnapshot.exists) {
      final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
      int quoteRowIndex = 1;
      int itemRowIndex = 1;
      
      for (var entry in quotesData.entries) {
        final quote = Map<String, dynamic>.from(entry.value);
        
        // Get client info
        String clientCompany = '';
        if (quote['client_id'] != null) {
          final clientSnapshot = await _database.ref('clients/$userId/${quote['client_id']}').get();
          if (clientSnapshot.exists) {
            final clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
            clientCompany = clientData['company'] ?? '';
          }
        }
        
        // Add quote data
        final quoteRowData = [
          quote['quote_number'] ?? '',
          clientCompany,
          quote['status'] ?? '',
          quote['subtotal']?.toString() ?? '0',
          quote['tax_rate']?.toString() ?? '0',
          quote['tax_amount']?.toString() ?? '0',
          quote['total_amount']?.toString() ?? '0',
          quote['created_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(quote['created_at']).toString()
            : '',
          quote['updated_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(quote['updated_at']).toString()
            : '',
        ];
        
        for (int i = 0; i < quoteRowData.length; i++) {
          final cell = quotesSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: quoteRowIndex));
          cell.value = quoteRowData[i];
          
          if (quoteRowIndex % 2 == 0) {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#FDF2E9'));
          }
        }
        
        // Add quote items if they exist
        if (quote['quote_items'] != null) {
          final items = List<Map<String, dynamic>>.from(quote['quote_items']);
          
          for (var item in items) {
            // Get product info
            String sku = '';
            String description = '';
            if (item['product_id'] != null) {
              final productSnapshot = await _database.ref('products/${item['product_id']}').get();
              if (productSnapshot.exists) {
                final productData = Map<String, dynamic>.from(productSnapshot.value as Map);
                sku = productData['sku'] ?? '';
                description = productData['description'] ?? '';
              }
            }
            
            final itemRowData = [
              quote['quote_number'] ?? '',
              sku,
              description,
              item['quantity']?.toString() ?? '0',
              item['unit_price']?.toString() ?? '0',
              item['total_price']?.toString() ?? '0',
            ];
            
            for (int i = 0; i < itemRowData.length; i++) {
              final cell = itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: itemRowIndex));
              cell.value = TextCellValue(itemRowData[i]);
              
              if (itemRowIndex % 2 == 0) {
                cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F4F2F8'));
              }
            }
            itemRowIndex++;
          }
        }
        
        quoteRowIndex++;
      }
    }
    
    // Auto-fit columns for both sheets
    for (int i = 0; i < quoteHeaders.length; i++) {
      quotesSheet.setColumnWidth(i, 15);
    }
    for (int i = 0; i < itemHeaders.length; i++) {
      itemsSheet.setColumnWidth(i, 15);
    }
    
    return Uint8List.fromList(excel.encode()!);
  }
  
  /// Export single quote to XLSX format with detailed information
  static Future<Uint8List> exportQuoteToXLSX(String quoteId) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Quote'];
    
    // Remove default sheet
    excel.delete('Sheet1');
    
    // Fetch quote data
    final quoteSnapshot = await _database.ref('quotes/$quoteId').get();
    if (!quoteSnapshot.exists) {
      throw Exception('Quote not found');
    }
    
    final quoteData = Map<String, dynamic>.from(quoteSnapshot.value as Map);
    
    // Fetch client data
    Map<String, dynamic>? clientData;
    if (quoteData['client_id'] != null) {
      final clientSnapshot = await _database.ref('clients/${quoteData['client_id']}').get();
      if (clientSnapshot.exists) {
        clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
      }
    }
    
    int currentRow = 0;
    
    // Title
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
    titleCell.value = TextCellValue('TURBO AIR QUOTE #${quoteData['quote_number']}');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
    currentRow += 2;
    
    // Quote Information
    final quoteInfoHeaders = ['Field', 'Value'];
    for (int i = 0; i < quoteInfoHeaders.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
      cell.value = TextCellValue(quoteInfoHeaders[i]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D9E2F3'));
    }
    currentRow++;
    
    final quoteInfo = [
      ['Quote Number', quoteData['quote_number'] ?? ''],
      ['Date', quoteData['created_at'] != null 
        ? _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(quoteData['created_at']))
        : ''],
      ['Status', quoteData['status'] ?? ''],
    ];
    
    for (var info in quoteInfo) {
      for (int i = 0; i < info.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(info[i]);
      }
      currentRow++;
    }
    currentRow++;
    
    // Client Information
    if (clientData != null) {
      final clientCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      clientCell.value = TextCellValue('CLIENT INFORMATION');
      clientCell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#70AD47'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                  CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      currentRow++;
      
      final clientInfo = [
        ['Company', clientData['company'] ?? ''],
        ['Contact', clientData['contact_name'] ?? ''],
        ['Email', clientData['email'] ?? ''],
        ['Phone', clientData['phone'] ?? ''],
        ['Address', clientData['address'] ?? ''],
      ];
      
      for (var info in clientInfo) {
        for (int i = 0; i < info.length; i++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
          cell.value = TextCellValue(info[i]);
        }
        currentRow++;
      }
      currentRow++;
    }
    
    // Items Header
    final itemsHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
    itemsHeaderCell.value = TextCellValue('QUOTE ITEMS');
    itemsHeaderCell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#E67E22'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), 
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
    currentRow++;
    
    // Items table headers
    final itemHeaders = ['SKU', 'Description', 'Quantity', 'Unit Price', 'Total Price'];
    for (int i = 0; i < itemHeaders.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
      cell.value = TextCellValue(itemHeaders[i]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#FCF3CF'));
    }
    currentRow++;
    
    // Items data
    if (quoteData['quote_items'] != null) {
      final items = List<Map<String, dynamic>>.from(quoteData['quote_items']);
      
      for (var item in items) {
        // Get product info
        String sku = '';
        String description = '';
        if (item['product_id'] != null) {
          final productSnapshot = await _database.ref('products/${item['product_id']}').get();
          if (productSnapshot.exists) {
            final productData = Map<String, dynamic>.from(productSnapshot.value as Map);
            sku = productData['sku'] ?? '';
            description = productData['description'] ?? '';
          }
        }
        
        final itemRowData = [
          sku,
          description,
          item['quantity']?.toString() ?? '0',
          _currencyFormat.format(item['unit_price'] ?? 0),
          _currencyFormat.format(item['total_price'] ?? 0),
        ];
        
        for (int i = 0; i < itemRowData.length; i++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
          cell.value = TextCellValue(itemRowData[i]);
        }
        currentRow++;
      }
    }
    currentRow++;
    
    // Summary
    final summaryData = [
      ['', '', '', 'Subtotal:', _currencyFormat.format(quoteData['subtotal'] ?? 0)],
      ['', '', '', 'Tax:', _currencyFormat.format(quoteData['tax_amount'] ?? 0)],
      ['', '', '', 'TOTAL:', _currencyFormat.format(quoteData['total_amount'] ?? 0)],
    ];
    
    for (var summary in summaryData) {
      for (int i = 0; i < summary.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(summary[i]);
        if (i >= 3) {
          cell.cellStyle = CellStyle(bold: true);
        }
      }
      currentRow++;
    }
    
    // Auto-fit columns
    for (int i = 0; i < 6; i++) {
      sheet.setColumnWidth(i, 20);
    }
    
    return Uint8List.fromList(excel.encode()!);
  }
  
  /// Export single client to PDF format with optional quote summary
  static Future<Uint8List> exportClientToPDF(String clientId, String userId, {bool includeQuotes = false}) async {
    // Fetch client data
    final clientSnapshot = await _database.ref('clients/$userId/$clientId').get();
    if (!clientSnapshot.exists) {
      throw Exception('Client not found');
    }
    
    final clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
    
    // Fetch quotes if needed
    List<Map<String, dynamic>> clientQuotes = [];
    if (includeQuotes) {
      final quotesSnapshot = await _database.ref('quotes/$userId').get();
      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        clientQuotes = quotesData.entries
            .where((e) => Map<String, dynamic>.from(e.value)['client_id'] == clientId)
            .map((e) => Map<String, dynamic>.from(e.value))
            .toList();
      }
    }
    
    // Build PDF
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          final List<pw.Widget> content = [];
          
          // Header
          content.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                'Client Profile',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
          );
          
          content.add(pw.SizedBox(height: 20));
          
          // Client information
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Company: ${clientData['company'] ?? ''}',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Contact: ${clientData['contact_name'] ?? ''}'),
                  pw.Text('Email: ${clientData['email'] ?? ''}'),
                  pw.Text('Phone: ${clientData['phone'] ?? ''}'),
                  pw.Text('Address: ${clientData['address'] ?? ''}'),
                  if (clientData['city'] != null) pw.Text('City: ${clientData['city']}'),
                  if (clientData['state'] != null) pw.Text('State: ${clientData['state']}'),
                  if (clientData['zip_code'] != null) pw.Text('Zip: ${clientData['zip_code']}'),
                ],
              ),
            ),
          );
          
          // Include quotes if requested
          if (includeQuotes && clientQuotes.isNotEmpty) {
            content.add(pw.SizedBox(height: 30));
            content.add(
              pw.Header(
                level: 1,
                child: pw.Text('Quote History',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
            );
            
            for (var quote in clientQuotes) {
              content.add(pw.SizedBox(height: 10));
              content.add(
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Quote #${quote['quote_number'] ?? 'N/A'}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${quote['created_at'] != null ? _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(quote['created_at'])) : 'N/A'}'),
                      pw.Text('Total: ${_currencyFormat.format(quote['total_amount'] ?? 0)}'),
                      pw.Text('Status: ${quote['status'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              );
            }
          } else if (includeQuotes) {
            content.add(pw.SizedBox(height: 30));
            content.add(pw.Text('No quotes found for this client.'));
          }
          
          return content;
        },
      ),
    );
    
    return pdf.save();
  }
  
  /// Export single client to XLSX format with optional quote summary
  static Future<Uint8List> exportClientToXLSX(String clientId, String userId, {bool includeQuotes = false}) async {
    final excel = Excel.createExcel();
    final Sheet clientSheet = excel['Client Info'];
    
    // Remove default sheet
    excel.delete('Sheet1');
    
    // Fetch client data
    final clientSnapshot = await _database.ref('clients/$userId/$clientId').get();
    if (!clientSnapshot.exists) {
      throw Exception('Client not found');
    }
    
    final clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);
    
    // Add client header
    final titleCell = clientSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('CLIENT PROFILE');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      backgroundColorHex: ExcelColor.fromHexString('#0066cc'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    clientSheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    
    // Add client details
    int currentRow = 2;
    final clientInfo = [
      ['Company', clientData['company'] ?? ''],
      ['Contact Name', clientData['contact_name'] ?? ''],
      ['Email', clientData['email'] ?? ''],
      ['Phone', clientData['phone'] ?? ''],
      ['Address', clientData['address'] ?? ''],
      ['City', clientData['city'] ?? ''],
      ['State', clientData['state'] ?? ''],
      ['Zip Code', clientData['zip_code'] ?? ''],
    ];
    
    for (var info in clientInfo) {
      final labelCell = clientSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      labelCell.value = TextCellValue(info[0]);
      labelCell.cellStyle = CellStyle(bold: true);
      
      final valueCell = clientSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      valueCell.value = TextCellValue(info[1]);
      
      currentRow++;
    }
    
    // Include quotes if requested
    if (includeQuotes) {
      final Sheet quotesSheet = excel['Quote History'];
      
      // Add headers
      final quoteHeaders = ['Quote Number', 'Date', 'Total Amount', 'Status', 'Items'];
      for (int i = 0; i < quoteHeaders.length; i++) {
        final cell = quotesSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(quoteHeaders[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#28a745'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }
      
      // Fetch and add quotes
      final quotesSnapshot = await _database.ref('quotes/$userId').get();
      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        final clientQuotes = quotesData.entries
            .where((e) => Map<String, dynamic>.from(e.value)['client_id'] == clientId)
            .toList();
        
        int quoteRow = 1;
        for (var quoteEntry in clientQuotes) {
          final quote = Map<String, dynamic>.from(quoteEntry.value);
          
          final rowData = [
            quote['quote_number'] ?? 'N/A',
            quote['created_at'] != null 
              ? _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(quote['created_at']))
              : 'N/A',
            _currencyFormat.format(quote['total_amount'] ?? 0),
            quote['status'] ?? 'N/A',
            quote['quote_items'] != null ? '${(quote['quote_items'] as List).length} items' : '0 items',
          ];
          
          for (int i = 0; i < rowData.length; i++) {
            final cell = quotesSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: quoteRow));
            cell.value = TextCellValue(rowData[i]);
            
            if (quoteRow % 2 == 0) {
              cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F2F2F2'));
            }
          }
          quoteRow++;
        }
      }
    }
    
    // Auto-fit columns
    for (int i = 0; i < 5; i++) {
      clientSheet.setColumnWidth(i, 20);
    }
    
    return Uint8List.fromList(excel.encode()!);
  }
}