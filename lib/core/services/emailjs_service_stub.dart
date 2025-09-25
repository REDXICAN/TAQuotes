// Stub implementation for non-web platforms
// This uses the regular EmailService with SMTP for mobile/desktop platforms
import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'email_service.dart';
import 'app_logger.dart';

class EmailJSService {
  static const String _serviceId = 'service_taquotes';
  static const String _templateId = 'template_quote';
  static const String _publicKey = 'YOUR_PUBLIC_KEY';

  // EmailService instance for mobile/desktop platforms
  static final EmailService _emailService = EmailService();

  static bool get isConfigured => true; // SMTP is configured for mobile

  static Future<bool> sendQuoteEmail({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required double totalAmount,
    Uint8List? pdfBytes,
    Uint8List? excelBytes,
    bool attachPdf = true,
    bool attachExcel = false,
    List<Map<String, dynamic>>? products,
  }) async {
    try {
      AppLogger.info('Sending email via SMTP (non-web platform)', category: LogCategory.email);

      // Create attachments list
      final attachments = <Attachment>[];

      // Add PDF attachment if requested and available
      if (attachPdf && pdfBytes != null) {
        attachments.add(
          Attachment(
            Stream.value(pdfBytes),
            'application/pdf',
            fileName: 'Quote_$quoteNumber.pdf',
          ),
        );
      }

      // Add Excel attachment if requested and available
      if (attachExcel && excelBytes != null) {
        attachments.add(
          Attachment(
            Stream.value(excelBytes),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            fileName: 'Quote_$quoteNumber.xlsx',
          ),
        );
      }

      // Generate HTML content with products table
      final htmlContent = _generateHtmlContent(
        recipientName: recipientName,
        quoteNumber: quoteNumber,
        totalAmount: totalAmount,
        products: products,
      );

      // Send email using EmailService (SMTP)
      return await _emailService.sendQuoteEmail(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        quoteNumber: quoteNumber,
        htmlContent: htmlContent,
        userInfo: {
          'name': 'TurboAir Sales Team',
          'email': 'turboairquotes@gmail.com',
          'role': 'Sales Representative',
        },
        attachments: attachments,
      );
    } catch (e) {
      AppLogger.error('Failed to send email on non-web platform',
          error: e, category: LogCategory.email);
      return false;
    }
  }

  static String _generateHtmlContent({
    required String recipientName,
    required String quoteNumber,
    required double totalAmount,
    List<Map<String, dynamic>>? products,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
    .content { padding: 20px; background-color: #f5f5f5; }
    .details { background: white; padding: 15px; margin: 15px 0; border-radius: 5px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 8px; text-align: left; border: 1px solid #ddd; }
    th { background-color: #f0f0f0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>TurboAir Quote</h1>
    </div>
    <div class="content">
      <h2>Dear $recipientName,</h2>
      <p>Thank you for your interest in TurboAir products. Please find your quote details below:</p>

      <div class="details">
        <h3>Quote Details</h3>
        <p><strong>Quote Number:</strong> $quoteNumber</p>
        <p><strong>Total Amount:</strong> \$${totalAmount.toStringAsFixed(2)}</p>
        <p><strong>Date:</strong> ${DateTime.now().toIso8601String().split('T')[0]}</p>
      </div>
    ''');

    // Add products table if available
    if (products != null && products.isNotEmpty) {
      buffer.writeln('''
      <div class="details">
        <h3>Products</h3>
        <table>
          <thead>
            <tr>
              <th>SKU</th>
              <th>Product</th>
              <th>Qty</th>
              <th>Unit Price</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
      ''');

      for (final product in products) {
        final sku = product['sku'] ?? 'N/A';
        final name = product['name'] ?? 'Unknown';
        final quantity = product['quantity'] ?? 1;
        final unitPrice = product['unitPrice'] ?? 0.0;
        final total = (quantity as num) * (unitPrice as num);

        buffer.writeln('''
            <tr>
              <td>$sku</td>
              <td>$name</td>
              <td>$quantity</td>
              <td>\$${(unitPrice as num).toStringAsFixed(2)}</td>
              <td>\$${total.toStringAsFixed(2)}</td>
            </tr>
        ''');
      }

      buffer.writeln('''
          </tbody>
        </table>
      </div>
      ''');
    }

    buffer.writeln('''
      <p>Please review the attached documents for complete details.</p>
      <p>If you have any questions, please don't hesitate to contact us.</p>

      <p>Best regards,<br>
      TurboAir Sales Team</p>
    </div>
  </div>
</body>
</html>
    ''');

    return buffer.toString();
  }
}