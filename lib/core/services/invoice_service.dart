// lib/core/services/invoice_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_service.dart';
import 'app_logger.dart';

enum InvoiceStatus { draft, sent, paid, overdue, cancelled }
enum PaymentTerms { net15, net30, net45, net60, cash_on_delivery, advance_payment }

class Invoice {
  final String id;
  final String quoteId;
  final String clientId;
  final String invoiceNumber;
  final DateTime createdAt;
  final DateTime dueDate;
  final InvoiceStatus status;
  final PaymentTerms paymentTerms;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final String userId;
  final String userEmail;
  final List<InvoiceItem> items;
  final Map<String, dynamic> clientInfo;
  final String? notes;
  final DateTime? sentAt;
  final DateTime? paidAt;
  final Map<String, dynamic> metadata;

  Invoice({
    required this.id,
    required this.quoteId,
    required this.clientId,
    required this.invoiceNumber,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.paymentTerms,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.totalAmount,
    required this.userId,
    required this.userEmail,
    required this.items,
    required this.clientInfo,
    this.notes,
    this.sentAt,
    this.paidAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quoteId': quoteId,
      'clientId': clientId,
      'invoiceNumber': invoiceNumber,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdAtIso': createdAt.toIso8601String(),
      'dueDate': dueDate.millisecondsSinceEpoch,
      'dueDateIso': dueDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'paymentTerms': paymentTerms.toString().split('.').last,
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'userId': userId,
      'userEmail': userEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'clientInfo': clientInfo,
      'notes': notes,
      'sentAt': sentAt?.millisecondsSinceEpoch,
      'sentAtIso': sentAt?.toIso8601String(),
      'paidAt': paidAt?.millisecondsSinceEpoch,
      'paidAtIso': paidAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] ?? '',
      quoteId: map['quoteId'] ?? '',
      clientId: map['clientId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'])
          : DateTime.now(),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      paymentTerms: PaymentTerms.values.firstWhere(
        (e) => e.toString().split('.').last == map['paymentTerms'],
        orElse: () => PaymentTerms.net30,
      ),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      taxRate: (map['taxRate'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) => InvoiceItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      clientInfo: Map<String, dynamic>.from(map['clientInfo'] ?? {}),
      notes: map['notes'],
      sentAt: map['sentAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['sentAt'])
          : null,
      paidAt: map['paidAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['paidAt'])
          : null,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

class InvoiceItem {
  final String sku;
  final String description;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? notes;

  InvoiceItem({
    required this.sku,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'sku': sku,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
      'notes': notes,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      sku: map['sku'] ?? '',
      description: map['description'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      lineTotal: (map['lineTotal'] ?? 0).toDouble(),
      notes: map['notes'],
    );
  }
}

class InvoiceResult {
  final bool success;
  final String? invoiceId;
  final String? error;
  final Uint8List? pdfBytes;
  final Uint8List? excelBytes;

  InvoiceResult({
    required this.success,
    this.invoiceId,
    this.error,
    this.pdfBytes,
    this.excelBytes,
  });
}

class InvoiceService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EmailService _emailService = EmailService();

  String? get userId => _auth.currentUser?.uid;
  String? get userEmail => _auth.currentUser?.email;

  static int _invoiceCounter = 1;

  /// Create invoice from quote
  Future<InvoiceResult> createInvoiceFromQuote({
    required String quoteId,
    required PaymentTerms paymentTerms,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      AppLogger.info('Creating invoice from quote: $quoteId', category: LogCategory.business);

      // Get quote data
      final quoteSnapshot = await _db.ref('quotes/$userId/$quoteId').get();
      if (!quoteSnapshot.exists) {
        throw Exception('Quote not found');
      }

      final quoteData = Map<String, dynamic>.from(quoteSnapshot.value as Map);

      // Get client data
      final clientId = quoteData['client_id'] ?? '';
      final clientSnapshot = await _db.ref('clients/$userId/$clientId').get();
      if (!clientSnapshot.exists) {
        throw Exception('Client not found');
      }

      final clientData = Map<String, dynamic>.from(clientSnapshot.value as Map);

      // Generate invoice number
      final invoiceNumber = await _generateInvoiceNumber();

      // Calculate due date based on payment terms
      final dueDate = _calculateDueDate(paymentTerms);

      // Convert quote items to invoice items
      final quoteItems = quoteData['quote_items'] as List<dynamic>? ?? [];
      final invoiceItems = quoteItems.map((item) {
        final itemData = Map<String, dynamic>.from(item);
        return InvoiceItem(
          sku: itemData['sku'] ?? '',
          description: itemData['description'] ?? itemData['model'] ?? '',
          quantity: itemData['quantity'] ?? 1,
          unitPrice: (itemData['price'] ?? 0).toDouble(),
          lineTotal: ((itemData['quantity'] ?? 1) * (itemData['price'] ?? 0)).toDouble(),
          notes: itemData['note'],
        );
      }).toList();

      // Create invoice
      final invoiceId = _db.ref().push().key!;
      final invoice = Invoice(
        id: invoiceId,
        quoteId: quoteId,
        clientId: clientId,
        invoiceNumber: invoiceNumber,
        createdAt: DateTime.now(),
        dueDate: dueDate,
        status: InvoiceStatus.draft,
        paymentTerms: paymentTerms,
        subtotal: (quoteData['subtotal'] ?? 0).toDouble(),
        taxRate: (quoteData['tax_rate'] ?? 0).toDouble(),
        taxAmount: (quoteData['tax_amount'] ?? 0).toDouble(),
        totalAmount: (quoteData['total_amount'] ?? 0).toDouble(),
        userId: userId!,
        userEmail: userEmail ?? '',
        items: invoiceItems,
        clientInfo: {
          'company': clientData['company'] ?? '',
          'contactName': clientData['contact_name'] ?? '',
          'email': clientData['email'] ?? '',
          'phone': clientData['phone'] ?? '',
          'address': clientData['address'] ?? '',
        },
        notes: notes,
        metadata: metadata ?? {},
      );

      // Save to database
      await _db.ref('invoices/$userId/$invoiceId').set(invoice.toMap());

      AppLogger.info('Invoice created: $invoiceNumber', category: LogCategory.business);

      return InvoiceResult(
        success: true,
        invoiceId: invoiceId,
      );

    } catch (e) {
      AppLogger.error('Error creating invoice', error: e, category: LogCategory.business);
      return InvoiceResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Generate PDF invoice
  Future<Uint8List> generateInvoicePDF(String invoiceId) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get invoice data
      final snapshot = await _db.ref('invoices/$userId/$invoiceId').get();
      if (!snapshot.exists) {
        throw Exception('Invoice not found');
      }

      final invoice = Invoice.fromMap(Map<String, dynamic>.from(snapshot.value as Map));

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPDFHeader(invoice),
              pw.SizedBox(height: 20),
              _buildPDFClientInfo(invoice),
              pw.SizedBox(height: 20),
              _buildPDFItemsTable(invoice),
              pw.SizedBox(height: 20),
              _buildPDFTotals(invoice),
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _buildPDFNotes(invoice),
              ],
              pw.SizedBox(height: 20),
              _buildPDFFooter(invoice),
            ];
          },
        ),
      );

      return await pdf.save();

    } catch (e) {
      AppLogger.error('Error generating invoice PDF', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Generate Excel invoice
  Future<Uint8List> generateInvoiceExcel(String invoiceId) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get invoice data
      final snapshot = await _db.ref('invoices/$userId/$invoiceId').get();
      if (!snapshot.exists) {
        throw Exception('Invoice not found');
      }

      final invoice = Invoice.fromMap(Map<String, dynamic>.from(snapshot.value as Map));

      final excel = Excel.createExcel();
      final sheet = excel['Invoice'];

      // Remove default sheet
      excel.delete('Sheet1');

      // Header
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('INVOICE');
      sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
        fontSize: 18,
        bold: true,
      );

      // Company info
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Turbo Air Mexico');
      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('turboairquotes@gmail.com');

      // Invoice details
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Invoice #: ${invoice.invoiceNumber}');
      sheet.cell(CellIndex.indexByString('E2')).value = TextCellValue('Date: ${_formatDate(invoice.createdAt)}');
      sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue('Due Date: ${_formatDate(invoice.dueDate)}');
      sheet.cell(CellIndex.indexByString('E4')).value = TextCellValue('Status: ${invoice.status.toString().split('.').last.toUpperCase()}');

      // Client info
      sheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('Bill To:');
      sheet.cell(CellIndex.indexByString('A6')).cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByString('A7')).value = TextCellValue(invoice.clientInfo['company'] ?? '');
      sheet.cell(CellIndex.indexByString('A8')).value = TextCellValue(invoice.clientInfo['contactName'] ?? '');
      sheet.cell(CellIndex.indexByString('A9')).value = TextCellValue(invoice.clientInfo['email'] ?? '');
      sheet.cell(CellIndex.indexByString('A10')).value = TextCellValue(invoice.clientInfo['phone'] ?? '');
      sheet.cell(CellIndex.indexByString('A11')).value = TextCellValue(invoice.clientInfo['address'] ?? '');

      // Items header
      int currentRow = 13;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('SKU');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue('Description');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = TextCellValue('Qty');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue('Unit Price');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = TextCellValue('Total');

      // Style header row
      for (int col = 0; col < 5; col++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow)).cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.gray25,
        );
      }

      // Items
      currentRow++;
      for (final item in invoice.items) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue(item.sku);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = TextCellValue(item.description);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = IntCellValue(item.quantity);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = DoubleCellValue(item.unitPrice);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = DoubleCellValue(item.lineTotal);
        currentRow++;
      }

      // Totals
      currentRow += 2;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue('Subtotal:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = DoubleCellValue(invoice.subtotal);

      currentRow++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue('Tax (${(invoice.taxRate * 100).toStringAsFixed(1)}%):');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = DoubleCellValue(invoice.taxAmount);

      currentRow++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = TextCellValue('TOTAL:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = DoubleCellValue(invoice.totalAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).cellStyle = CellStyle(bold: true);

      // Notes
      if (invoice.notes != null && invoice.notes!.isNotEmpty) {
        currentRow += 3;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Notes:');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = CellStyle(bold: true);
        currentRow++;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue(invoice.notes!);
      }

      // Payment terms
      currentRow += 2;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = TextCellValue('Payment Terms: ${_getPaymentTermsDescription(invoice.paymentTerms)}');

      return excel.encode()!;

    } catch (e) {
      AppLogger.error('Error generating invoice Excel', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Send invoice via email
  Future<bool> sendInvoiceEmail({
    required String invoiceId,
    required String recipientEmail,
    String? subject,
    String? body,
    bool includePDF = true,
    bool includeExcel = false,
  }) async {
    try {
      AppLogger.info('Sending invoice email: $invoiceId to $recipientEmail', category: LogCategory.business);

      // Get invoice data
      final snapshot = await _db.ref('invoices/$userId/$invoiceId').get();
      if (!snapshot.exists) {
        throw Exception('Invoice not found');
      }

      final invoice = Invoice.fromMap(Map<String, dynamic>.from(snapshot.value as Map));

      // Generate attachments
      Uint8List? pdfBytes;
      Uint8List? excelBytes;

      if (includePDF) {
        pdfBytes = await generateInvoicePDF(invoiceId);
      }

      if (includeExcel) {
        excelBytes = await generateInvoiceExcel(invoiceId);
      }

      // Prepare email
      final emailSubject = subject ?? 'Invoice ${invoice.invoiceNumber} from Turbo Air Mexico';
      final emailBody = body ?? _generateEmailBody(invoice);

      // Send email
      final emailResult = await _emailService.sendInvoiceEmail(
        recipientEmail: recipientEmail,
        subject: emailSubject,
        body: emailBody,
        invoiceNumber: invoice.invoiceNumber,
        pdfBytes: pdfBytes,
        excelBytes: excelBytes,
      );

      if (emailResult.success) {
        // Update invoice status and sent date
        await updateInvoiceStatus(invoiceId, InvoiceStatus.sent);

        AppLogger.info('Invoice email sent successfully: ${invoice.invoiceNumber}', category: LogCategory.business);
        return true;
      } else {
        AppLogger.error('Failed to send invoice email: ${emailResult.error}', category: LogCategory.business);
        return false;
      }

    } catch (e) {
      AppLogger.error('Error sending invoice email', error: e, category: LogCategory.business);
      return false;
    }
  }

  /// Update invoice status
  Future<void> updateInvoiceStatus(String invoiceId, InvoiceStatus status) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updates = <String, dynamic>{
        'status': status.toString().split('.').last,
      };

      // Set timestamp based on status
      switch (status) {
        case InvoiceStatus.sent:
          updates['sentAt'] = DateTime.now().millisecondsSinceEpoch;
          updates['sentAtIso'] = DateTime.now().toIso8601String();
          break;
        case InvoiceStatus.paid:
          updates['paidAt'] = DateTime.now().millisecondsSinceEpoch;
          updates['paidAtIso'] = DateTime.now().toIso8601String();
          break;
        default:
          break;
      }

      await _db.ref('invoices/$userId/$invoiceId').update(updates);

      AppLogger.info('Invoice status updated: $invoiceId -> ${status.toString().split('.').last}', category: LogCategory.business);

    } catch (e) {
      AppLogger.error('Error updating invoice status', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Get invoices for current user
  Stream<List<Invoice>> getInvoices({
    InvoiceStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (userId == null) return Stream.value([]);

    Query query = _db.ref('invoices/$userId');
    query = query.orderByChild('createdAt');

    return query.onValue.map((event) {
      final List<Invoice> invoices = [];

      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final invoice = Invoice.fromMap(Map<String, dynamic>.from(entry.value));

            // Apply filters
            if (status != null && invoice.status != status) continue;
            if (startDate != null && invoice.createdAt.isBefore(startDate)) continue;
            if (endDate != null && invoice.createdAt.isAfter(endDate)) continue;

            invoices.add(invoice);
          } catch (e) {
            AppLogger.error('Error parsing invoice', error: e, category: LogCategory.business);
          }
        }
      }

      // Sort by creation date (newest first)
      invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return invoices;
    });
  }

  /// Get single invoice
  Future<Invoice?> getInvoice(String invoiceId) async {
    if (userId == null) return null;

    try {
      final snapshot = await _db.ref('invoices/$userId/$invoiceId').get();
      if (snapshot.exists && snapshot.value != null) {
        return Invoice.fromMap(Map<String, dynamic>.from(snapshot.value as Map));
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting invoice', error: e, category: LogCategory.business);
      return null;
    }
  }

  /// Delete invoice
  Future<void> deleteInvoice(String invoiceId) async {
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _db.ref('invoices/$userId/$invoiceId').remove();
      AppLogger.info('Invoice deleted: $invoiceId', category: LogCategory.business);
    } catch (e) {
      AppLogger.error('Error deleting invoice', error: e, category: LogCategory.business);
      rethrow;
    }
  }

  /// Helper methods
  Future<String> _generateInvoiceNumber() async {
    final now = DateTime.now();
    final prefix = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}';

    // Get existing invoices for this month to determine next number
    final snapshot = await _db.ref('invoices/$userId')
        .orderByChild('invoiceNumber')
        .startAt('$prefix-')
        .endAt('$prefix-Z')
        .get();

    int maxNumber = 0;
    if (snapshot.exists && snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in data.values) {
        final invoiceNumber = (entry as Map)['invoiceNumber'] as String? ?? '';
        final numberPart = invoiceNumber.split('-').last;
        final number = int.tryParse(numberPart) ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    return '$prefix-${(maxNumber + 1).toString().padLeft(4, '0')}';
  }

  DateTime _calculateDueDate(PaymentTerms terms) {
    final now = DateTime.now();
    switch (terms) {
      case PaymentTerms.net15:
        return now.add(const Duration(days: 15));
      case PaymentTerms.net30:
        return now.add(const Duration(days: 30));
      case PaymentTerms.net45:
        return now.add(const Duration(days: 45));
      case PaymentTerms.net60:
        return now.add(const Duration(days: 60));
      case PaymentTerms.cash_on_delivery:
      case PaymentTerms.advance_payment:
        return now;
    }
  }

  String _getPaymentTermsDescription(PaymentTerms terms) {
    switch (terms) {
      case PaymentTerms.net15:
        return 'Net 15 days';
      case PaymentTerms.net30:
        return 'Net 30 days';
      case PaymentTerms.net45:
        return 'Net 45 days';
      case PaymentTerms.net60:
        return 'Net 60 days';
      case PaymentTerms.cash_on_delivery:
        return 'Cash on Delivery';
      case PaymentTerms.advance_payment:
        return 'Advance Payment';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _generateEmailBody(Invoice invoice) {
    return '''
Dear ${invoice.clientInfo['contactName'] ?? 'Valued Customer'},

Please find attached Invoice ${invoice.invoiceNumber} for your recent order.

Invoice Details:
- Invoice Number: ${invoice.invoiceNumber}
- Invoice Date: ${_formatDate(invoice.createdAt)}
- Due Date: ${_formatDate(invoice.dueDate)}
- Total Amount: \$${invoice.totalAmount.toStringAsFixed(2)}
- Payment Terms: ${_getPaymentTermsDescription(invoice.paymentTerms)}

${invoice.notes != null && invoice.notes!.isNotEmpty ? '\nNotes:\n${invoice.notes}\n' : ''}

If you have any questions about this invoice, please don't hesitate to contact us.

Thank you for your business!

Best regards,
Turbo Air Mexico
Email: turboairquotes@gmail.com
''';
  }

  /// PDF building methods
  pw.Widget _buildPDFHeader(Invoice invoice) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Turbo Air Mexico'),
            pw.Text('turboairquotes@gmail.com'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Invoice #: ${invoice.invoiceNumber}'),
            pw.Text('Date: ${_formatDate(invoice.createdAt)}'),
            pw.Text('Due Date: ${_formatDate(invoice.dueDate)}'),
            pw.Text('Status: ${invoice.status.toString().split('.').last.toUpperCase()}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFClientInfo(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text(invoice.clientInfo['company'] ?? ''),
        pw.Text(invoice.clientInfo['contactName'] ?? ''),
        pw.Text(invoice.clientInfo['email'] ?? ''),
        pw.Text(invoice.clientInfo['phone'] ?? ''),
        pw.Text(invoice.clientInfo['address'] ?? ''),
      ],
    );
  }

  pw.Widget _buildPDFItemsTable(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('SKU', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        // Items
        ...invoice.items.map((item) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(item.sku),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(item.description),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(item.quantity.toString()),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('\$${item.unitPrice.toStringAsFixed(2)}'),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('\$${item.lineTotal.toStringAsFixed(2)}'),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildPDFTotals(Invoice invoice) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal:'),
                pw.Text('\$${invoice.subtotal.toStringAsFixed(2)}'),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Tax (${(invoice.taxRate * 100).toStringAsFixed(1)}%):'),
                pw.Text('\$${invoice.taxAmount.toStringAsFixed(2)}'),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('\$${invoice.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPDFNotes(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text(invoice.notes ?? ''),
      ],
    );
  }

  pw.Widget _buildPDFFooter(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Payment Terms: ${_getPaymentTermsDescription(invoice.paymentTerms)}'),
        pw.SizedBox(height: 10),
        pw.Text('Thank you for your business!'),
      ],
    );
  }
}