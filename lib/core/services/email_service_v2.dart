// lib/core/services/email_service_v2.dart
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'app_logger.dart';

class EmailServiceV2 {
  static final EmailServiceV2 _instance = EmailServiceV2._internal();
  factory EmailServiceV2() => _instance;
  EmailServiceV2._internal();

  // Gmail SMTP configuration with app password
  SmtpServer? _smtpServer;
  
  SmtpServer get smtpServer {
    if (_smtpServer == null) {
      final username = dotenv.env['EMAIL_SENDER_ADDRESS'] ?? '';
      final password = dotenv.env['EMAIL_APP_PASSWORD'] ?? '';
      
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Email configuration missing. Please set EMAIL_SENDER_ADDRESS and EMAIL_APP_PASSWORD in .env file');
      }
      
      _smtpServer = gmail(username, password);
      
      AppLogger.info('Email service initialized with Gmail SMTP', 
        category: LogCategory.business,
        data: {'sender': username});
    }
    return _smtpServer!;
  }

  /// Send a test email to verify configuration
  Future<bool> sendTestEmail(String recipientEmail) async {
    try {
      final message = Message()
        ..from = Address(
          dotenv.env['EMAIL_SENDER_ADDRESS'] ?? '',
          dotenv.env['EMAIL_SENDER_NAME'] ?? 'TurboAir Quote System'
        )
        ..recipients.add(recipientEmail)
        ..subject = 'Test Email from TurboAir Quote System'
        ..text = 'This is a test email to verify the email configuration.'
        ..html = '''
          <h2>Test Email</h2>
          <p>This is a test email from the TurboAir Quote System.</p>
          <p>If you receive this email, the configuration is working correctly.</p>
          <hr>
          <p><small>Sent from TurboAir Quote System</small></p>
        ''';

      final sendReport = await send(message, smtpServer);
      
      AppLogger.info('Test email sent successfully', 
        category: LogCategory.business,
        data: {
          'recipient': recipientEmail,
          'messageId': sendReport.toString(),
        });
      
      return true;
    } catch (e) {
      AppLogger.error('Failed to send test email', 
        error: e,
        category: LogCategory.business,
        data: {'recipient': recipientEmail});
      return false;
    }
  }

  /// Send quote email with optional PDF attachment
  Future<bool> sendQuoteEmail({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required double totalAmount,
    Uint8List? pdfBytes,
    bool attachPdf = true,
    bool attachExcel = false,
    Uint8List? excelBytes,
  }) async {
    try {
      final message = Message()
        ..from = Address(
          dotenv.env['EMAIL_SENDER_ADDRESS'] ?? '',
          dotenv.env['EMAIL_SENDER_NAME'] ?? 'TurboAir Quote System'
        )
        ..recipients.add(recipientEmail)
        ..subject = 'Quote #$quoteNumber from TurboAir'
        ..text = '''
Dear $recipientName,

Please find attached your quote #$quoteNumber.

Quote Details:
- Quote Number: $quoteNumber
- Total Amount: \$${totalAmount.toStringAsFixed(2)}
- Date: ${DateTime.now().toString().split(' ')[0]}

Thank you for your business!

Best regards,
TurboAir Quote System
        '''
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; }
    .content { padding: 20px; background-color: #f5f5f5; }
    .details { background: white; padding: 15px; margin: 15px 0; border-radius: 5px; }
    .footer { text-align: center; padding: 10px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>TurboAir Quote System</h1>
    </div>
    <div class="content">
      <h2>Dear $recipientName,</h2>
      <p>Thank you for your interest in TurboAir products. Please find your quote details below:</p>
      
      <div class="details">
        <h3>Quote Details</h3>
        <p><strong>Quote Number:</strong> $quoteNumber</p>
        <p><strong>Total Amount:</strong> \$${totalAmount.toStringAsFixed(2)}</p>
        <p><strong>Date:</strong> ${DateTime.now().toString().split(' ')[0]}</p>
      </div>
      
      ${(attachPdf && pdfBytes != null) || (attachExcel && excelBytes != null) ? '<p><strong>Attachments:</strong></p><ul>' : ''}
      ${(attachPdf && pdfBytes != null) ? '<li>Quote PDF Document</li>' : ''}
      ${(attachExcel && excelBytes != null) ? '<li>Quote Excel Spreadsheet</li>' : ''}
      ${(attachPdf && pdfBytes != null) || (attachExcel && excelBytes != null) ? '</ul>' : ''}
      
      <p>If you have any questions, please don't hesitate to contact us.</p>
      
      <p>Best regards,<br>
      TurboAir Quote System</p>
    </div>
    <div class="footer">
      <p>© ${DateTime.now().year} TurboAir. All rights reserved.</p>
      <p>This is an automated email. Please do not reply directly to this message.</p>
    </div>
  </div>
</body>
</html>
        ''';

      // Add PDF attachment if provided
      if (attachPdf && pdfBytes != null && pdfBytes.isNotEmpty) {
        AppLogger.info('Adding PDF attachment: ${pdfBytes.length} bytes',
          category: LogCategory.business);
        final attachment = StreamAttachment(
          Stream.value(pdfBytes),
          'application/pdf',
          fileName: 'Quote_$quoteNumber.pdf',
        );
        message.attachments.add(attachment);
      }

      // Add Excel attachment if provided
      if (attachExcel && excelBytes != null && excelBytes.isNotEmpty) {
        AppLogger.info('Adding Excel attachment: ${excelBytes.length} bytes',
          category: LogCategory.business);
        final attachment = StreamAttachment(
          Stream.value(excelBytes),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          fileName: 'Quote_$quoteNumber.xlsx',
        );
        message.attachments.add(attachment);
      }

      AppLogger.info('Sending email with ${message.attachments.length} attachments',
        category: LogCategory.business);
      
      final sendReport = await send(message, smtpServer);
      
      AppLogger.info('Quote email sent successfully', 
        category: LogCategory.business,
        data: {
          'recipient': recipientEmail,
          'quoteNumber': quoteNumber,
          'attachments': {
            'pdf': attachPdf && pdfBytes != null,
            'excel': attachExcel && excelBytes != null,
          },
          'messageId': sendReport.toString(),
        });
      
      return true;
    } catch (e) {
      AppLogger.error('Failed to send quote email', 
        error: e,
        category: LogCategory.business,
        data: {
          'recipient': recipientEmail,
          'quoteNumber': quoteNumber,
        });
      return false;
    }
  }

  /// Simple email without attachments
  Future<bool> sendSimpleEmail({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    try {
      final message = Message()
        ..from = Address(
          dotenv.env['EMAIL_SENDER_ADDRESS'] ?? '',
          dotenv.env['EMAIL_SENDER_NAME'] ?? 'TurboAir Quote System'
        )
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..text = body
        ..html = '''
<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto;">
    ${body.replaceAll('\n', '<br>')}
    <hr style="margin-top: 30px;">
    <p style="color: #666; font-size: 12px;">
      Sent from TurboAir Quote System<br>
      © ${DateTime.now().year} TurboAir. All rights reserved.
    </p>
  </div>
</body>
</html>
        ''';

      await send(message, smtpServer);
      return true;
    } catch (e) {
      AppLogger.error('Failed to send simple email', 
        error: e,
        category: LogCategory.business,
        data: {'recipient': recipientEmail, 'subject': subject});
      return false;
    }
  }
}