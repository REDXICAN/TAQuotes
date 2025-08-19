// lib/core/services/export_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart' show rootBundle;

class ExportService {
  static final _database = FirebaseDatabase.instance;
  static final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateFormat = DateFormat('MMMM dd, yyyy');

  // Generate PDF for a quote
  static Future<Uint8List> generateQuotePDF(String quoteId) async {
    try {
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
      if (quoteData['quote_items'] != null) {
        for (var itemData in quoteData['quote_items']) {
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
    
      // Try to load logo
      pw.ImageProvider? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/app_logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        // Logo not found, continue without it
        print('Logo not found: $e');
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
                            style: pw.TextStyle(
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
                          DateTime.fromMillisecondsSinceEpoch(quoteData!['created_at'] ?? DateTime.now().millisecondsSinceEpoch),
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
                  decoration: pw.BoxDecoration(
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
              }).toList(),
              
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
                          pw.Text(_currencyFormat.format(quoteData!['subtotal'] ?? 0)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Tax:'),
                          pw.Text(_currencyFormat.format(quoteData!['tax_amount'] ?? 0)),
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
                            _currencyFormat.format(quoteData!['total_amount'] ?? 0),
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
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
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
      
      return pdf.save();
    } catch (e) {
      print('Error generating PDF: $e');
      // Return a simple error PDF
      final errorPdf = pw.Document();
      errorPdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('Error generating PDF: ${e.toString()}'),
          ),
        ),
      );
      return errorPdf.save();
    }
  }
}