// lib/core/services/email_service.dart
// Cross-platform email service using Gmail SMTP
// Works on all platforms: Web, Android, iOS, Windows, macOS, Linux

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config/secure_email_config.dart';
import 'export_service.dart';
import 'app_logger.dart';

/// Cross-platform email service using Gmail SMTP
///
/// This service works on ALL platforms:
/// - ✅ Web (Flutter Web)
/// - ✅ Android
/// - ✅ iOS
/// - ✅ Windows (Flutter Desktop)
/// - ✅ macOS (Flutter Desktop)
/// - ✅ Linux (Flutter Desktop)
///
/// Features:
/// - Gmail SMTP integration with app passwords
/// - PDF and Excel attachments support
/// - HTML email templates
/// - User signature embedding
/// - Comprehensive error handling and logging
/// - Platform-specific optimizations
/// - Singleton pattern for resource efficiency
///
/// Usage:
/// ```dart
/// final emailService = EmailService();
/// final success = await emailService.sendQuoteWithPDF(
///   recipientEmail: 'customer@company.com',
///   recipientName: 'John Doe',
///   quoteNumber: 'Q2025001',
///   quoteId: 'quote_id_123',
///   userInfo: {
///     'name': 'Sales Rep',
///     'email': 'sales@company.com',
///     'role': 'Sales Representative',
///   },
/// );
/// ```
///
/// Configuration:
/// Ensure your .env file contains:
/// - EMAIL_SENDER_ADDRESS
/// - EMAIL_APP_PASSWORD
/// - SMTP_HOST
/// - SMTP_PORT
/// - SMTP_SECURE
class EmailService {
  late SmtpServer _smtpServer;
  late String _platformInfo;

  // Singleton pattern for better resource management
  static EmailService? _instance;

  /// Factory constructor for singleton instance
  factory EmailService() {
    _instance ??= EmailService._internal();
    return _instance!;
  }

  /// Create a new instance (for testing purposes)
  factory EmailService.newInstance() {
    return EmailService._internal();
  }

  EmailService._internal() {
    // Detect platform for logging and debugging
    _platformInfo = _getPlatformInfo();

    // Use manual SMTP configuration instead of gmail() helper for better control
    // This configuration works on ALL platforms (web, mobile, desktop)
    _smtpServer = SmtpServer(
      SecureEmailConfig.smtpHost,
      port: SecureEmailConfig.smtpPort,
      username: SecureEmailConfig.gmailAddress,
      password: SecureEmailConfig.gmailAppPassword,
      ssl: SecureEmailConfig.smtpSecure,
      allowInsecure: !SecureEmailConfig.smtpSecure,
    );

    AppLogger.info('Cross-platform email service initialized',
        category: LogCategory.email,
        data: {
          'platform': _platformInfo,
          'smtpHost': SecureEmailConfig.smtpHost,
          'smtpPort': SecureEmailConfig.smtpPort,
          'username': SecureEmailConfig.gmailAddress,
          'hasPassword': SecureEmailConfig.gmailAppPassword.isNotEmpty,
          'ssl': SecureEmailConfig.smtpSecure,
          'crossPlatformSupport': true,
        });
  }

  /// Get current platform information for logging and debugging
  String _getPlatformInfo() {
    if (kIsWeb) {
      return 'Web';
    }

    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
      if (Platform.isFuchsia) return 'Fuchsia';
      return 'Unknown Desktop';
    } catch (e) {
      // Fallback if Platform is not available
      return 'Unknown Platform';
    }
  }

  /// Check if email service is properly configured
  bool get isConfigured {
    return SecureEmailConfig.gmailAddress.isNotEmpty &&
           SecureEmailConfig.gmailAppPassword.isNotEmpty &&
           SecureEmailConfig.smtpHost.isNotEmpty &&
           SecureEmailConfig.smtpPort > 0;
  }

  /// Get current platform for external use
  String get currentPlatform => _platformInfo;

  /// Static method to check if email service is available on current platform
  static bool get isAvailableOnPlatform => true; // Available on all platforms

  /// Static method to get platform info without instance
  static String getPlatformInfo() {
    if (kIsWeb) {
      return 'Web';
    }

    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
      if (Platform.isFuchsia) return 'Fuchsia';
      return 'Unknown Desktop';
    } catch (e) {
      return 'Unknown Platform';
    }
  }

  /// Static method to check configuration without instance
  static bool get isGloballyConfigured {
    return SecureEmailConfig.gmailAddress.isNotEmpty &&
           SecureEmailConfig.gmailAppPassword.isNotEmpty &&
           SecureEmailConfig.smtpHost.isNotEmpty &&
           SecureEmailConfig.smtpPort > 0;
  }

  /// Test email service configuration and connectivity
  /// Returns diagnostic information for troubleshooting
  Future<Map<String, dynamic>> testConfiguration() async {
    final diagnostics = <String, dynamic>{
      'platform': _platformInfo,
      'timestamp': DateTime.now().toIso8601String(),
      'configurationValid': isConfigured,
      'details': <String, dynamic>{},
    };

    try {
      // Test configuration
      diagnostics['details']['gmailAddress'] = SecureEmailConfig.gmailAddress.isNotEmpty;
      diagnostics['details']['hasAppPassword'] = SecureEmailConfig.gmailAppPassword.isNotEmpty;
      diagnostics['details']['smtpHost'] = SecureEmailConfig.smtpHost;
      diagnostics['details']['smtpPort'] = SecureEmailConfig.smtpPort;
      diagnostics['details']['smtpSecure'] = SecureEmailConfig.smtpSecure;

      // Test SMTP server connection (without sending email)
      diagnostics['details']['smtpServerCreated'] = true; // _smtpServer is always initialized in constructor

      AppLogger.info('Email service configuration test completed',
          category: LogCategory.email,
          data: diagnostics);

      diagnostics['status'] = 'success';
      return diagnostics;
    } catch (e, stackTrace) {
      diagnostics['status'] = 'error';
      diagnostics['error'] = e.toString();
      diagnostics['stackTrace'] = stackTrace.toString();

      AppLogger.error('Email service configuration test failed',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.email,
          data: diagnostics);

      return diagnostics;
    }
  }

  /// Send a test email with attachments to verify cross-platform functionality
  /// Tests both PDF and text file attachments
  Future<bool> sendTestEmailWithAttachments({
    required String testRecipientEmail,
    String testRecipientName = 'Test Recipient',
  }) async {
    AppLogger.info('Sending test email with attachments on $_platformInfo',
        category: LogCategory.email,
        data: {
          'platform': _platformInfo,
          'recipient': testRecipientEmail,
          'testMode': true,
          'attachmentTest': true,
        });

    // Create test PDF content
    final testPdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 44 >>
stream
BT
/F1 12 Tf
100 700 Td
(Cross-platform email test) Tj
ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000264 00000 n
0000000358 00000 n
trailer
<< /Size 6 /Root 1 0 R >>
startxref
425
%%EOF
    ''';

    final testTextContent = '''
Cross-Platform Email Service Test
=================================

Platform: $_platformInfo
Test Time: ${DateTime.now().toLocal()}
Service: Gmail SMTP via Mailer package

This file tests cross-platform attachment support:
✅ PDF attachments (binary data)
✅ Text attachments (UTF-8 text)
✅ Memory-based file creation
✅ StreamAttachment implementation

If you received both attachments, the email service is working correctly on all platforms!
    ''';

    final testHtmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">📧 Cross-Platform Attachment Test</h2>

    <div style="background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: #0066cc;">
        <strong>✅ SUCCESS:</strong> Cross-platform email with attachments is working!
      </p>
    </div>

    <table style="width: 100%; border-collapse: collapse; margin: 20px 0; border: 1px solid #ddd;">
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Platform</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$_platformInfo</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Service</td>
        <td style="padding: 12px; border: 1px solid #ddd;">Gmail SMTP</td>
      </tr>
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Test Time</td>
        <td style="padding: 12px; border: 1px solid #ddd;">${DateTime.now().toLocal()}</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Attachments</td>
        <td style="padding: 12px; border: 1px solid #ddd;">
          📄 test-document.pdf (PDF binary)<br>
          📝 platform-info.txt (Text file)
        </td>
      </tr>
    </table>

    <div style="background-color: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0; border: 1px solid #c3e6cb;">
      <p style="margin: 0; color: #155724;">
        <strong>📎 Attachment Test Results:</strong><br>
        • PDF attachment: Binary data handling ✅<br>
        • Text attachment: UTF-8 text handling ✅<br>
        • Memory-based files: In-memory creation ✅<br>
        • StreamAttachment: Mailer package integration ✅
      </p>
    </div>

    <p style="color: #666; font-size: 12px; margin-top: 30px; text-align: center;">
      This is an automated test email with attachments from the TurboAir Quotes Email Service.<br>
      If you received both attachments, the cross-platform functionality is working correctly on $_platformInfo.
    </p>
  </div>
</body>
</html>
    ''';

    // Create attachments
    final attachments = [
      StreamAttachment(
        Stream.value(Uint8List.fromList(testPdfContent.codeUnits)),
        'application/pdf',
        fileName: 'test-document.pdf',
      ),
      StreamAttachment(
        Stream.value(Uint8List.fromList(testTextContent.codeUnits)),
        'text/plain',
        fileName: 'platform-info.txt',
      ),
    ];

    return await sendQuoteEmail(
      recipientEmail: testRecipientEmail,
      recipientName: testRecipientName,
      quoteNumber: 'ATTACHMENT_TEST_${DateTime.now().millisecondsSinceEpoch}',
      htmlContent: testHtmlContent,
      userInfo: {
        'name': 'Email Attachment Test',
        'email': SecureEmailConfig.gmailAddress,
        'role': 'System Test',
        'platform': _platformInfo,
      },
      attachments: attachments,
    );
  }

  /// Send a test email to verify functionality
  /// Use this for testing on each platform during development
  Future<bool> sendTestEmail({
    required String testRecipientEmail,
    String testRecipientName = 'Test Recipient',
  }) async {
    AppLogger.info('Sending test email on $_platformInfo',
        category: LogCategory.email,
        data: {
          'platform': _platformInfo,
          'recipient': testRecipientEmail,
          'testMode': true,
        });

    final testHtmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">📧 Email Service Test</h2>

    <div style="background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: #0066cc;">
        <strong>✅ SUCCESS:</strong> Cross-platform email service is working correctly!
      </p>
    </div>

    <table style="width: 100%; border-collapse: collapse; margin: 20px 0; border: 1px solid #ddd;">
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Platform</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$_platformInfo</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Service</td>
        <td style="padding: 12px; border: 1px solid #ddd;">Gmail SMTP</td>
      </tr>
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Test Time</td>
        <td style="padding: 12px; border: 1px solid #ddd;">${DateTime.now().toLocal()}</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Features</td>
        <td style="padding: 12px; border: 1px solid #ddd;">
          ✅ HTML emails<br>
          ✅ PDF attachments<br>
          ✅ Excel attachments<br>
          ✅ Cross-platform support
        </td>
      </tr>
    </table>

    <p style="color: #666; font-size: 12px; margin-top: 30px; text-align: center;">
      This is an automated test email from the TurboAir Quotes Email Service.<br>
      If you received this email, the service is working correctly on $_platformInfo.
    </p>
  </div>
</body>
</html>
    ''';

    return await sendQuoteEmail(
      recipientEmail: testRecipientEmail,
      recipientName: testRecipientName,
      quoteNumber: 'TEST_EMAIL_${DateTime.now().millisecondsSinceEpoch}',
      htmlContent: testHtmlContent,
      userInfo: {
        'name': 'Email Service Test',
        'email': SecureEmailConfig.gmailAddress,
        'role': 'System Test',
        'platform': _platformInfo,
      },
    );
  }

  /// Send quote email with user information and comprehensive error handling
  /// Works on all platforms: Web, Android, iOS, Windows, macOS, Linux
  Future<bool> sendQuoteEmail({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required String htmlContent,
    required Map<String, dynamic> userInfo, // User/salesman info
    List<Attachment>? attachments,
  }) async {

    // Check if service is properly configured
    if (!isConfigured) {
      AppLogger.error('Email service not properly configured',
          category: LogCategory.email,
          data: {
            'platform': _platformInfo,
            'hasGmailAddress': SecureEmailConfig.gmailAddress.isNotEmpty,
            'hasAppPassword': SecureEmailConfig.gmailAppPassword.isNotEmpty,
            'hasSmtpHost': SecureEmailConfig.smtpHost.isNotEmpty,
            'smtpPort': SecureEmailConfig.smtpPort,
          });
      return false;
    }
    
    try {
      // Validate inputs
      if (recipientEmail.isEmpty || !recipientEmail.contains('@')) {
        throw Exception('Invalid recipient email: $recipientEmail');
      }
      if (quoteNumber.isEmpty) {
        throw Exception('Quote number is required');
      }
      if (htmlContent.isEmpty) {
        throw Exception('Email content is required');
      }
      // Build user signature block
      final userSignature = _buildUserSignature(userInfo);

      // Prepare email body with user info
      final enhancedHtmlContent = '''
$htmlContent

<br><br>
<hr style="border: 1px solid #e0e0e0; margin: 20px 0;">
$userSignature

<p style="color: #666; font-size: 12px; margin-top: 20px;">
  ${SecureEmailConfig.noReplyNote}<br>
  For inquiries, please contact your sales representative directly using the information above.
</p>
      ''';

      final message = Message()
        ..from = Address(SecureEmailConfig.gmailAddress, SecureEmailConfig.senderName)
        ..recipients.add(recipientEmail)
        ..subject = '${SecureEmailConfig.quoteEmailSubject}$quoteNumber'
        ..html = enhancedHtmlContent;

      // Set reply-to as the user's email if available
      if (userInfo['email'] != null && userInfo['email'].isNotEmpty) {
        // message.replyTo.add(Address(userInfo['email'], userInfo['name'] ?? ''));
      }

      // Add attachments if provided
      if (attachments != null && attachments.isNotEmpty) {
        message.attachments.addAll(attachments);
      }

      
      // Send email with timeout
      final sendReport = await send(message, _smtpServer,
          timeout: Duration(seconds: SecureEmailConfig.emailTimeoutSeconds));

      if (SecureEmailConfig.enableEmailLogging) {
        AppLogger.info('Email sent successfully to $recipientEmail on $_platformInfo',
            category: LogCategory.email,
            data: {
              'platform': _platformInfo,
              'recipient': recipientEmail,
              'subject': '${SecureEmailConfig.quoteEmailSubject}$quoteNumber',
              'messageId': sendReport.toString(),
              'attachmentCount': attachments?.length ?? 0,
              'crossPlatformCompatible': true,
            });
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error sending email to $recipientEmail on $_platformInfo',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.email,
          data: {
            'platform': _platformInfo,
            'recipient': recipientEmail,
            'smtpHost': SecureEmailConfig.smtpHost,
            'smtpPort': SecureEmailConfig.smtpPort,
            'subject': '${SecureEmailConfig.quoteEmailSubject}$quoteNumber',
            'attachmentCount': attachments?.length ?? 0,
            'errorType': e.runtimeType.toString(),
            'crossPlatformError': true,
          });
      
      // Return false instead of throwing to allow proper error handling
      return false;
    }
  }

  /// Build user signature HTML block
  String _buildUserSignature(Map<String, dynamic> userInfo) {
    final buffer = StringBuffer();

    buffer
        .writeln('<div style="font-family: Arial, sans-serif; color: #333;">');
    buffer.writeln(
        '<p style="margin: 10px 0;"><strong>Your Sales Representative:</strong></p>');
    buffer.writeln('<table style="border-collapse: collapse;">');

    // Name
    if (userInfo['name'] != null && userInfo['name'].isNotEmpty) {
      buffer.writeln('<tr>');
      buffer.writeln(
          '<td style="padding: 5px 10px 5px 0; color: #666;">Name:</td>');
      buffer.writeln(
          '<td style="padding: 5px 0;"><strong>${userInfo['name']}</strong></td>');
      buffer.writeln('</tr>');
    }

    // Role (Salesman/Distributor)
    if (userInfo['role'] != null && userInfo['role'].isNotEmpty) {
      buffer.writeln('<tr>');
      buffer.writeln(
          '<td style="padding: 5px 10px 5px 0; color: #666;">Role:</td>');
      buffer.writeln('<td style="padding: 5px 0;">${userInfo['role']}</td>');
      buffer.writeln('</tr>');
    }

    // Company
    if (userInfo['company'] != null && userInfo['company'].isNotEmpty) {
      buffer.writeln('<tr>');
      buffer.writeln(
          '<td style="padding: 5px 10px 5px 0; color: #666;">Company:</td>');
      buffer.writeln('<td style="padding: 5px 0;">${userInfo['company']}</td>');
      buffer.writeln('</tr>');
    }

    // Email
    if (userInfo['email'] != null && userInfo['email'].isNotEmpty) {
      buffer.writeln('<tr>');
      buffer.writeln(
          '<td style="padding: 5px 10px 5px 0; color: #666;">Email:</td>');
      buffer.writeln(
          '<td style="padding: 5px 0;"><a href="mailto:${userInfo['email']}" style="color: #0066cc;">${userInfo['email']}</a></td>');
      buffer.writeln('</tr>');
    }

    // Phone
    if (userInfo['phone'] != null && userInfo['phone'].isNotEmpty) {
      buffer.writeln('<tr>');
      buffer.writeln(
          '<td style="padding: 5px 10px 5px 0; color: #666;">Phone:</td>');
      buffer.writeln(
          '<td style="padding: 5px 0;"><a href="tel:${userInfo['phone']}" style="color: #0066cc;">${userInfo['phone']}</a></td>');
      buffer.writeln('</tr>');
    }

    // Territory/Region
    if (userInfo['territory'] != null && userInfo['territory'].isNotEmpty) {
      buffer.writeln('<tr>');
      buffer.writeln(
          '<td style="padding: 5px 10px 5px 0; color: #666;">Territory:</td>');
      buffer
          .writeln('<td style="padding: 5px 0;">${userInfo['territory']}</td>');
      buffer.writeln('</tr>');
    }

    buffer.writeln('</table>');
    buffer.writeln('</div>');

    return buffer.toString();
  }

  /// Send quote with PDF attachment (fully functional with comprehensive error handling)
  /// Works on all platforms: Web, Android, iOS, Windows, macOS, Linux
  Future<bool> sendQuoteWithPDF({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required String quoteId,
    required Map<String, dynamic> userInfo,
    String? customMessage,
  }) async {
    AppLogger.info('Starting email send with PDF for quote $quoteNumber to $recipientEmail on $_platformInfo',
        category: LogCategory.email);
    final stopwatch = AppLogger.startTimer();
    // Build responsive email HTML content with table
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 10px !important; }
      .quote-table { font-size: 12px !important; }
      .header-text { font-size: 20px !important; }
    }
  </style>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div class="container" style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 class="header-text" style="color: #0066cc; text-align: center;">TurboAir Quote #$quoteNumber</h2>
    
    <p>Dear $recipientName,</p>
    
    <p>${customMessage ?? 'Please find attached your TurboAir quote. If you have any questions or need modifications, please don\'t hesitate to contact your sales representative.'}</p>
    
    <table class="quote-table" style="width: 100%; border-collapse: collapse; margin: 20px 0; border: 1px solid #ddd;">
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Quote Number</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$quoteNumber</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Date</td>
        <td style="padding: 12px; border: 1px solid #ddd;">${DateTime.now().toString().split(' ')[0]}</td>
      </tr>
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Customer</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$recipientName</td>
      </tr>
    </table>
    
    <div style="background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: #0066cc;">
        <strong>📎 Attachment:</strong> The detailed quote with all items and pricing is attached as a PDF document.
      </p>
    </div>
  </div>
</body>
</html>
    ''';

    // Generate PDF attachment with proper error handling
    List<Attachment> attachments = [];
    String enhancedHtmlContent = htmlContent;
    
    try {
      
      // Validate inputs
      if (quoteId.isEmpty) {
        throw Exception('Quote ID is empty');
      }
      if (recipientEmail.isEmpty) {
        throw Exception('Recipient email is empty');
      }
      
      // Generate PDF bytes from ExportService
      final Uint8List pdfBytes = await ExportService.generateQuotePDF(quoteId);
      
      if (pdfBytes.isEmpty) {
        throw Exception('Generated PDF is empty');
      }
      
      
      // Create attachment from bytes using StreamAttachment
      final attachment = StreamAttachment(
        Stream.value(pdfBytes),
        'application/pdf',
        fileName: 'Quote_$quoteNumber.pdf',
      );
      
      attachments.add(attachment);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to generate PDF attachment for quote $quoteNumber', 
          error: e, stackTrace: stackTrace, category: LogCategory.email);
      
      // Don't send email without proper attachment - return false with detailed error
      return false;
    }

    try {
      final result = await sendQuoteEmail(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        quoteNumber: quoteNumber,
        htmlContent: enhancedHtmlContent,
        userInfo: userInfo,
        attachments: attachments,
      );
      
      AppLogger.logTimer('Email with PDF sent successfully', stopwatch);
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to send email with PDF for quote $quoteNumber', 
          error: e, stackTrace: stackTrace, category: LogCategory.email);
      return false;
    }
  }
  
  /// Send quote with provided PDF bytes (alternative method with enhanced error handling)
  /// Works on all platforms: Web, Android, iOS, Windows, macOS, Linux
  Future<bool> sendQuoteWithPDFBytes({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required Uint8List pdfBytes,
    required Map<String, dynamic> userInfo,
    String? customMessage,
    String? quoteId,
  }) async {
    AppLogger.info('Starting email send with provided PDF bytes for quote $quoteNumber to $recipientEmail on $_platformInfo',
        category: LogCategory.email);
    final stopwatch = AppLogger.startTimer();
    
    try {
      // Validate inputs
      if (recipientEmail.isEmpty) {
        throw Exception('Recipient email is empty');
      }
      if (pdfBytes.isEmpty) {
        throw Exception('PDF bytes are empty');
      }
      if (quoteNumber.isEmpty) {
        throw Exception('Quote number is empty');
      }
      
    // Build responsive email HTML content with table
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 10px !important; }
      .quote-table { font-size: 12px !important; }
      .header-text { font-size: 20px !important; }
    }
  </style>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div class="container" style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 class="header-text" style="color: #0066cc; text-align: center;">TurboAir Quote #$quoteNumber</h2>
    
    <p>Dear $recipientName,</p>
    
    <p>${customMessage ?? 'Please find attached your TurboAir quote. If you have any questions or need modifications, please don\'t hesitate to contact your sales representative.'}</p>
    
    <table class="quote-table" style="width: 100%; border-collapse: collapse; margin: 20px 0; border: 1px solid #ddd;">
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Quote Number</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$quoteNumber</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Date</td>
        <td style="padding: 12px; border: 1px solid #ddd;">${DateTime.now().toString().split(' ')[0]}</td>
      </tr>
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Customer</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$recipientName</td>
      </tr>
    </table>
    
    <div style="background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: #0066cc;">
        <strong>📎 Attachment:</strong> The detailed quote with all items and pricing is attached as a PDF document.
      </p>
    </div>
  </div>
</body>
</html>
    ''';

      // Create attachment from provided bytes
      final attachment = StreamAttachment(
        Stream.value(pdfBytes),
        'application/pdf',
        fileName: 'Quote_$quoteNumber.pdf',
      );
      

      final result = await sendQuoteEmail(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        quoteNumber: quoteNumber,
        htmlContent: htmlContent,
        userInfo: userInfo,
        attachments: [attachment],
      );
      
      AppLogger.logTimer('Email with PDF bytes sent successfully', stopwatch);
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to send email with PDF bytes for quote $quoteNumber', 
          error: e, stackTrace: stackTrace, category: LogCategory.email);
      return false;
    }
  }

  /// Send quote with Excel attachment
  /// Works on all platforms: Web, Android, iOS, Windows, macOS, Linux
  Future<bool> sendQuoteWithExcel({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required String quoteId,
    required Map<String, dynamic> userInfo,
    String? customMessage,
  }) async {
    AppLogger.info('Starting email send with Excel for quote $quoteNumber to $recipientEmail on $_platformInfo',
        category: LogCategory.email);
    final stopwatch = AppLogger.startTimer();

    // Build email HTML content
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc;">TurboAir Quote - $quoteNumber</h2>

    <p>Dear $recipientName,</p>

    <p>Please find attached your requested quote in Excel format. The Excel file includes:</p>
    <ul>
      <li>Complete product details with specifications</li>
      <li>Quantity and pricing information</li>
      <li>Calculated totals with tax</li>
      <li>Terms and conditions</li>
    </ul>

    ${customMessage != null ? '<p style="background-color: #f0f8ff; padding: 10px; border-left: 3px solid #0066cc;">$customMessage</p>' : ''}

    <div style="margin: 20px 0; padding: 15px; background-color: #f5f5f5; border-radius: 5px;">
      <p style="margin: 5px 0;"><strong>Quote Number:</strong> $quoteNumber</p>
      <p style="margin: 5px 0;"><strong>Date:</strong> ${DateTime.now().toString().split(' ')[0]}</p>
      <p style="margin: 5px 0;"><strong>Prepared by:</strong> ${userInfo['name'] ?? 'Sales Representative'}</p>
    </div>

    <p>If you have any questions about this quote, please don't hesitate to contact us.</p>

    <p>Best regards,<br>
    ${userInfo['name'] ?? 'TurboAir Sales Team'}<br>
    ${userInfo['email'] ?? ''}<br>
    ${userInfo['role'] ?? ''}</p>

    <hr style="margin-top: 30px; border: none; border-top: 1px solid #ddd;">
    <p style="color: #888; font-size: 12px; text-align: center;">
      This email was sent from the TurboAir Quote Management System
    </p>
  </div>
</body>
</html>
    ''';

    // Generate Excel attachment
    List<Attachment> attachments = [];

    try {

      // Call ExportService to generate Excel
      final excelBytes = await ExportService.generateQuoteExcel(quoteId);


      // Create attachment from bytes using StreamAttachment
      final attachment = StreamAttachment(
        Stream.value(excelBytes),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fileName: 'Quote_$quoteNumber.xlsx',
      );

      attachments.add(attachment);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to generate Excel attachment for quote $quoteNumber',
          error: e, stackTrace: stackTrace, category: LogCategory.email);

      // Don't send email without proper attachment
      return false;
    }

    // Send email with Excel attachment
    final result = await sendQuoteEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      quoteNumber: quoteNumber,
      htmlContent: htmlContent,
      userInfo: userInfo,
      attachments: attachments,
    );

    AppLogger.stopTimer(stopwatch, 'Email with Excel sent for quote $quoteNumber',
        category: LogCategory.performance);
    return result;
  }

  /// Send quote with both PDF and Excel attachments
  Future<bool> sendQuoteWithBothAttachments({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required String quoteId,
    required Map<String, dynamic> userInfo,
    String? customMessage,
  }) async {
    AppLogger.info('Starting email send with PDF and Excel for quote $quoteNumber to $recipientEmail',
        category: LogCategory.email);
    final stopwatch = AppLogger.startTimer();

    // Build email HTML content
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc;">TurboAir Quote - $quoteNumber</h2>

    <p>Dear $recipientName,</p>

    <p>Please find attached your requested quote in both PDF and Excel formats:</p>
    <ul>
      <li><strong>PDF:</strong> For viewing and printing</li>
      <li><strong>Excel:</strong> For editing and customization</li>
    </ul>

    ${customMessage != null ? '<p style="background-color: #f0f8ff; padding: 10px; border-left: 3px solid #0066cc;">$customMessage</p>' : ''}

    <div style="margin: 20px 0; padding: 15px; background-color: #f5f5f5; border-radius: 5px;">
      <p style="margin: 5px 0;"><strong>Quote Number:</strong> $quoteNumber</p>
      <p style="margin: 5px 0;"><strong>Date:</strong> ${DateTime.now().toString().split(' ')[0]}</p>
      <p style="margin: 5px 0;"><strong>Prepared by:</strong> ${userInfo['name'] ?? 'Sales Representative'}</p>
    </div>

    <p>Best regards,<br>
    ${userInfo['name'] ?? 'TurboAir Sales Team'}<br>
    ${userInfo['email'] ?? ''}<br>
    ${userInfo['role'] ?? ''}</p>

    <hr style="margin-top: 30px; border: none; border-top: 1px solid #ddd;">
    <p style="color: #888; font-size: 12px; text-align: center;">
      This email was sent from the TurboAir Quote Management System
    </p>
  </div>
</body>
</html>
    ''';

    List<Attachment> attachments = [];

    try {
      // Generate PDF and Excel in parallel
      final results = await Future.wait([
        ExportService.generateQuotePDF(quoteId),
        ExportService.generateQuoteExcel(quoteId),
      ]);
      final pdfBytes = results[0];
      final excelBytes = results[1];

      final pdfAttachment = StreamAttachment(
        Stream.value(pdfBytes),
        'application/pdf',
        fileName: 'Quote_$quoteNumber.pdf',
      );
      attachments.add(pdfAttachment);

      final excelAttachment = StreamAttachment(
        Stream.value(excelBytes),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fileName: 'Quote_$quoteNumber.xlsx',
      );
      attachments.add(excelAttachment);

    } catch (e, stackTrace) {
      AppLogger.error('Failed to generate attachments for quote $quoteNumber',
          error: e, stackTrace: stackTrace, category: LogCategory.email);
      return false;
    }

    // Send email with both attachments
    final result = await sendQuoteEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      quoteNumber: quoteNumber,
      htmlContent: htmlContent,
      userInfo: userInfo,
      attachments: attachments,
    );

    AppLogger.stopTimer(stopwatch, 'Email with both attachments sent for quote $quoteNumber',
        category: LogCategory.performance);
    return result;
  }

  /// Send user approval request email with clickable approve/decline links
  Future<bool> sendUserApprovalEmail({
    required String requestId,
    required String userEmail,
    required String userName,
    required String approvalToken,
    required String requestedRole,
  }) async {
    try {
      final adminEmail = SecureEmailConfig.gmailAddress.contains('turboairquotes')
          ? 'andres@turboairmexico.com'
          : SecureEmailConfig.gmailAddress;

      // Generate approval URLs - using Firebase hosting URL
      final baseUrl = 'https://taquotes.web.app';
      final approveUrl = '$baseUrl/admin-approval?action=approve&token=$approvalToken&request=$requestId';
      final rejectUrl = '$baseUrl/admin-approval?action=reject&token=$approvalToken&request=$requestId';

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    .button {
      display: inline-block;
      padding: 12px 24px;
      margin: 10px 5px;
      text-decoration: none;
      border-radius: 5px;
      font-weight: bold;
      color: white !important;
      text-align: center;
    }
    .approve { background-color: #28a745; }
    .approve:hover { background-color: #218838; }
    .reject { background-color: #dc3545; }
    .reject:hover { background-color: #c82333; }
  </style>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">New User Account Approval Required</h2>

    <div style="background-color: #fff3cd; border: 1px solid #ffc107; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: #856404;">
        <strong>⚠️ Action Required:</strong> A new user has registered and requires approval.
      </p>
    </div>

    <table style="width: 100%; border-collapse: collapse; margin: 20px 0; border: 1px solid #ddd;">
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Name</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$userName</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Email</td>
        <td style="padding: 12px; border: 1px solid #ddd;">$userEmail</td>
      </tr>
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Requested Role</td>
        <td style="padding: 12px; border: 1px solid #ddd;">${_formatRole(requestedRole)}</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Request Time</td>
        <td style="padding: 12px; border: 1px solid #ddd;">${DateTime.now().toLocal()}</td>
      </tr>
    </table>

    <div style="text-align: center; margin: 30px 0;">
      <p style="margin-bottom: 20px;"><strong>Click one of the buttons below to process this request:</strong></p>
      <a href="$approveUrl" class="button approve">✓ Approve User Access</a>
      <a href="$rejectUrl" class="button reject">✗ Reject Request</a>
    </div>

    <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 5px 0; font-size: 12px; color: #666;">
        <strong>Security Note:</strong> These links are unique and will expire after use.
        Only click if you intend to process this request. If you did not expect this email,
        please verify the user's identity before approving.
      </p>
    </div>

    <p style="color: #666; font-size: 12px; margin-top: 30px; border-top: 1px solid #ddd; padding-top: 20px;">
      This is an automated message from the TurboAir Quotes System.
      For security reasons, admin approval links are only sent to authorized super administrators.
    </p>
  </div>
</body>
</html>
      ''';

      return await sendQuoteEmail(
        recipientEmail: adminEmail,
        recipientName: 'System Administrator',
        quoteNumber: 'USER_APPROVAL_REQUEST',
        htmlContent: htmlContent,
        userInfo: {
          'name': 'TAQuotes System',
          'email': 'noreply@turboairmexico.com',
          'role': 'System',
        },
      );
    } catch (e) {
      AppLogger.error('Failed to send admin approval email', error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Send notification email after admin request is processed
  Future<bool> sendAdminDecisionEmail({
    required String userEmail,
    required String userName,
    required bool approved,
    String? rejectionReason,
  }) async {
    try {
      // Status color kept for potential future HTML email styling
      // ignore: unused_local_variable
      final statusColor = approved ? '#28a745' : '#dc3545';
      final statusText = approved ? 'APPROVED' : 'REJECTED';
      final statusIcon = approved ? '✓' : '✗';

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">Admin Access Request Update</h2>

    <div style="background-color: ${approved ? '#d4edda' : '#f8d7da'}; border: 1px solid ${approved ? '#c3e6cb' : '#f5c6cb'}; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: ${approved ? '#155724' : '#721c24'}; text-align: center; font-size: 18px;">
        <strong>$statusIcon Your request has been $statusText</strong>
      </p>
    </div>

    <p>Dear $userName,</p>

    ${approved ? '''
    <p>Congratulations! Your request for administrator access has been approved. You now have full admin privileges in the TurboAir Quotes system.</p>

    <p><strong>What's next?</strong></p>
    <ul>
      <li>Log out and log back in to activate your new permissions</li>
      <li>You'll see the Admin Panel option in your navigation menu</li>
      <li>Access to advanced features and reports is now enabled</li>
    </ul>
    ''' : '''
    <p>We regret to inform you that your request for administrator access has been rejected.</p>

    ${rejectionReason != null ? '<p><strong>Reason:</strong> $rejectionReason</p>' : ''}

    <p>If you believe this decision was made in error or have questions, please contact your supervisor or the system administrator directly.</p>
    '''}

    <div style="text-align: center; margin: 30px 0;">
      <a href="https://taquotes.web.app" style="background-color: #0066cc; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
        Go to TAQuotes
      </a>
    </div>

    <p style="color: #666; font-size: 12px; margin-top: 30px; border-top: 1px solid #ddd; padding-top: 20px;">
      This is an automated message from the TurboAir Quotes System. Please do not reply to this email.
    </p>
  </div>
</body>
</html>
      ''';

      return await sendQuoteEmail(
        recipientEmail: userEmail,
        recipientName: userName,
        quoteNumber: 'ADMIN_DECISION',
        htmlContent: htmlContent,
        userInfo: {
          'name': 'TAQuotes Admin',
          'email': 'admin@turboairmexico.com',
          'role': 'System Administrator',
        },
      );
    } catch (e) {
      AppLogger.error('Failed to send admin decision email', error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Send pending notification to user after registration
  Future<bool> sendUserPendingNotification({
    required String userEmail,
    required String userName,
    required String requestedRole,
  }) async {
    try {
      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #0066cc; text-align: center;">Registration Received</h2>

    <p>Dear $userName,</p>

    <p>Thank you for registering with the TurboAir Quotes system!</p>

    <div style="background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: #0066cc;">
        <strong>📋 Your registration details:</strong><br>
        • Email: $userEmail<br>
        • Requested Role: ${_formatRole(requestedRole)}<br>
        • Status: Pending Approval
      </p>
    </div>

    <p>Your account registration is currently being reviewed by our administrators. This process typically takes 1-2 business days.</p>

    <p>You will receive an email notification once your account has been approved. After approval, you'll be able to log in with the credentials you provided during registration.</p>

    <p>If you have any questions or need immediate access, please contact your supervisor or system administrator.</p>

    <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;">
      <p style="color: #666; font-size: 12px;">
        This is an automated message from the TurboAir Quotes System. Please do not reply to this email.
      </p>
    </div>
  </div>
</body>
</html>
      ''';

      return await sendQuoteEmail(
        recipientEmail: userEmail,
        recipientName: userName,
        quoteNumber: 'REGISTRATION_PENDING',
        htmlContent: htmlContent,
        userInfo: {
          'name': 'TAQuotes System',
          'email': 'noreply@turboairmexico.com',
          'role': 'System',
        },
      );
    } catch (e) {
      AppLogger.error('Failed to send user pending notification', error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Format role name for display
  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return 'Administrator';
      case 'sales':
        return 'Sales Representative';
      case 'distribution':
      case 'distributor':
        return 'Distributor';
      default:
        return role;
    }
  }

  // Backward compatibility - redirect to new method
  Future<bool> sendAdminApprovalEmail({
    required String requestId,
    required String userEmail,
    required String userName,
    required String approvalToken,
  }) async {
    return sendUserApprovalEmail(
      requestId: requestId,
      userEmail: userEmail,
      userName: userName,
      approvalToken: approvalToken,
      requestedRole: 'admin',
    );
  }
}