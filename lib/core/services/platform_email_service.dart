// Platform-specific email service that handles web and mobile
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'email_service.dart';
import 'app_logger.dart';
import '../config/secure_email_config.dart';

class PlatformEmailService {
  final EmailService _mobileEmailService = EmailService();

  /// Send quote email with platform-specific handling
  Future<bool> sendQuoteEmail({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required String htmlContent,
    required Map<String, dynamic> userInfo,
    List<Attachment>? attachments,
    Uint8List? pdfBytes,
    Uint8List? excelBytes,
  }) async {
    try {
      if (kIsWeb) {
        // Web platform - use Firebase Functions
        return await _sendViaFirebaseFunctions(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          quoteNumber: quoteNumber,
          htmlContent: htmlContent,
          pdfBytes: pdfBytes,
          excelBytes: excelBytes,
          userInfo: userInfo,
        );
      } else {
        // Mobile platforms - use SMTP
        return await _mobileEmailService.sendQuoteEmail(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          quoteNumber: quoteNumber,
          htmlContent: htmlContent,
          userInfo: userInfo,
          attachments: attachments,
        );
      }
    } catch (e) {
      AppLogger.error('Platform email service error', error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Send email with PDF bytes
  Future<bool> sendQuoteWithPDFBytes({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required double totalAmount,
    required Uint8List pdfBytes,
    String? htmlContent,
    Map<String, dynamic>? userInfo,
    List<Map<String, dynamic>>? products,
  }) async {
    try {
      if (kIsWeb) {
        // Web platform - use Firebase Functions
        return await _sendViaFirebaseFunctions(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          quoteNumber: quoteNumber,
          htmlContent: htmlContent ?? _generateDefaultHtmlContent(quoteNumber, totalAmount),
          pdfBytes: pdfBytes,
          totalAmount: totalAmount,
          products: products,
          userInfo: userInfo,
        );
      } else {
        // Mobile platforms - use SMTP
        return await _mobileEmailService.sendQuoteWithPDFBytes(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          quoteNumber: quoteNumber,
          pdfBytes: pdfBytes,
          userInfo: userInfo ?? {},
        );
      }
    } catch (e) {
      AppLogger.error('Platform email service error', error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Send email via Firebase Functions for web platform
  Future<bool> _sendViaFirebaseFunctions({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required String htmlContent,
    Uint8List? pdfBytes,
    Uint8List? excelBytes,
    double? totalAmount,
    List<Map<String, dynamic>>? products,
    Map<String, dynamic>? userInfo,
  }) async {
    try {
      AppLogger.info('Sending email via Firebase Functions', category: LogCategory.email);

      // Firebase Functions endpoint
      const String functionsUrl = 'https://us-central1-taquotes.cloudfunctions.net/sendQuoteEmail';

      // Build request body
      final requestBody = {
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'quoteNumber': quoteNumber,
        'totalAmount': totalAmount ?? 0,
        'attachPdf': pdfBytes != null,
        'attachExcel': excelBytes != null,
      };

      // Add products if provided
      if (products != null && products.isNotEmpty) {
        requestBody['products'] = products;
      }

      // Add attachments as base64 strings
      if (pdfBytes != null) {
        requestBody['pdfBase64'] = base64Encode(pdfBytes);
      }

      if (excelBytes != null) {
        requestBody['excelBase64'] = base64Encode(excelBytes);
      }

      // Send request
      final response = await http.post(
        Uri.parse(functionsUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Email sent successfully via Firebase Functions',
            category: LogCategory.email);
        return true;
      } else {
        AppLogger.error('Firebase Functions error: ${response.body}',
            category: LogCategory.email);

        // Try fallback methods
        return await _fallbackEmailMethods(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          quoteNumber: quoteNumber,
          htmlContent: htmlContent,
          pdfBytes: pdfBytes,
          excelBytes: excelBytes,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to send email via Firebase Functions',
          error: e, category: LogCategory.email);

      // Try fallback methods
      return await _fallbackEmailMethods(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        quoteNumber: quoteNumber,
        htmlContent: htmlContent,
        pdfBytes: pdfBytes,
        excelBytes: excelBytes,
      );
    }
  }

  /// Fallback email methods for web
  Future<bool> _fallbackEmailMethods({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required String htmlContent,
    Uint8List? pdfBytes,
    Uint8List? excelBytes,
  }) async {
    AppLogger.warning('Using fallback email methods', category: LogCategory.email);

    // Try SendGrid first (if configured)
    final sendGridKey = const String.fromEnvironment('SENDGRID_API_KEY');
    if (sendGridKey.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('https://api.sendgrid.com/v3/mail/send'),
          headers: {
            'Authorization': 'Bearer $sendGridKey',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'personalizations': [
              {
                'to': [{'email': recipientEmail, 'name': recipientName}],
                'subject': 'Quote #$quoteNumber',
              }
            ],
            'from': {
              'email': SecureEmailConfig.gmailAddress,
              'name': SecureEmailConfig.senderName,
            },
            'content': [
              {'type': 'text/html', 'value': htmlContent}
            ],
            if (pdfBytes != null || excelBytes != null) 'attachments': [
              if (pdfBytes != null) {
                'content': base64Encode(pdfBytes),
                'filename': 'Quote_$quoteNumber.pdf',
                'type': 'application/pdf',
              },
              if (excelBytes != null) {
                'content': base64Encode(excelBytes),
                'filename': 'Quote_$quoteNumber.xlsx',
                'type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              },
            ],
          }),
        );

        if (response.statusCode == 202) {
          AppLogger.info('Email sent via SendGrid fallback', category: LogCategory.email);
          return true;
        }
      } catch (e) {
        AppLogger.error('SendGrid fallback failed', error: e, category: LogCategory.email);
      }
    }

    // Final fallback - show download prompt
    AppLogger.warning('All email methods failed. User must download attachments manually.',
        category: LogCategory.email);
    return false;
  }

  /// Generate default HTML content for email
  String _generateDefaultHtmlContent(String quoteNumber, double totalAmount) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>TurboAir Quote</h1>
        </div>
        <div class="content">
          <h2>Quote #$quoteNumber</h2>
          <p>Total Amount: \$${totalAmount.toStringAsFixed(2)}</p>
          <p>Please find your quote details in the attached PDF.</p>
          <p>Thank you for your business!</p>
        </div>
      </div>
    </body>
    </html>
    ''';
  }
}