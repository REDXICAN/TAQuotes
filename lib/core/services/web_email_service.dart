// Web-specific email service implementation using HTTP API
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_logger.dart';
import '../config/secure_email_config.dart';

class WebEmailService {
  // Using SendGrid API (free tier supports attachments)
  static const String _sendGridApiUrl = 'https://api.sendgrid.com/v3/mail/send';

  // Alternative: Using Brevo (formerly Sendinblue) API (free tier supports attachments)
  static const String _brevoApiUrl = 'https://api.brevo.com/v3/smtp/email';

  // Using a custom backend endpoint (recommended for production)
  static const String _customBackendUrl = 'https://your-backend.com/api/send-email';

  /// Send email with attachments using SendGrid API
  /// SendGrid offers 100 emails/day free with attachment support
  static Future<bool> sendEmailWithSendGrid({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlContent,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Uint8List? excelBytes,
    String? excelFileName,
    Map<String, dynamic>? userInfo,
  }) async {
    try {
      // Get SendGrid API key from environment
      final apiKey = const String.fromEnvironment('SENDGRID_API_KEY',
          defaultValue: '');

      if (apiKey.isEmpty) {
        AppLogger.warning('SendGrid API key not configured. Please set SENDGRID_API_KEY.',
            category: LogCategory.email);
        // Fallback to Brevo
        return await sendEmailWithBrevo(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          subject: subject,
          htmlContent: htmlContent,
          pdfBytes: pdfBytes,
          pdfFileName: pdfFileName,
          excelBytes: excelBytes,
          excelFileName: excelFileName,
          userInfo: userInfo,
        );
      }

      // Build request body
      final requestBody = {
        'personalizations': [
          {
            'to': [
              {
                'email': recipientEmail,
                'name': recipientName,
              }
            ],
            'subject': subject,
          }
        ],
        'from': {
          'email': SecureEmailConfig.gmailAddress,
          'name': SecureEmailConfig.senderName,
        },
        'content': [
          {
            'type': 'text/html',
            'value': htmlContent,
          }
        ],
      };

      // Add attachments if provided
      final attachments = <Map<String, dynamic>>[];

      if (pdfBytes != null && pdfFileName != null) {
        attachments.add({
          'content': base64Encode(pdfBytes),
          'filename': pdfFileName,
          'type': 'application/pdf',
          'disposition': 'attachment',
        });
      }

      if (excelBytes != null && excelFileName != null) {
        attachments.add({
          'content': base64Encode(excelBytes),
          'filename': excelFileName,
          'type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'disposition': 'attachment',
        });
      }

      if (attachments.isNotEmpty) {
        requestBody['attachments'] = attachments;
      }

      // Send request
      final response = await http.post(
        Uri.parse(_sendGridApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 202) {
        AppLogger.info('Email sent successfully via SendGrid',
            category: LogCategory.email);
        return true;
      } else {
        AppLogger.error('SendGrid API error: ${response.body}',
            category: LogCategory.email);
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send email via SendGrid',
          error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Send email with attachments using Brevo (Sendinblue) API
  /// Brevo offers 300 emails/day free with attachment support
  static Future<bool> sendEmailWithBrevo({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlContent,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Uint8List? excelBytes,
    String? excelFileName,
    Map<String, dynamic>? userInfo,
  }) async {
    try {
      // Get Brevo API key from environment or use a test key
      final apiKey = const String.fromEnvironment('BREVO_API_KEY',
          defaultValue: '');

      if (apiKey.isEmpty) {
        AppLogger.warning('Brevo API key not configured. Please set BREVO_API_KEY.',
            category: LogCategory.email);
        // Fallback to custom backend
        return await sendEmailViaBackend(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          subject: subject,
          htmlContent: htmlContent,
          pdfBytes: pdfBytes,
          pdfFileName: pdfFileName,
          excelBytes: excelBytes,
          excelFileName: excelFileName,
          userInfo: userInfo,
        );
      }

      // Build request body
      final requestBody = {
        'sender': {
          'email': SecureEmailConfig.gmailAddress,
          'name': SecureEmailConfig.senderName,
        },
        'to': [
          {
            'email': recipientEmail,
            'name': recipientName,
          }
        ],
        'subject': subject,
        'htmlContent': htmlContent,
      };

      // Add attachments if provided
      final attachments = <Map<String, dynamic>>[];

      if (pdfBytes != null && pdfFileName != null) {
        attachments.add({
          'content': base64Encode(pdfBytes),
          'name': pdfFileName,
        });
      }

      if (excelBytes != null && excelFileName != null) {
        attachments.add({
          'content': base64Encode(excelBytes),
          'name': excelFileName,
        });
      }

      if (attachments.isNotEmpty) {
        requestBody['attachment'] = attachments;
      }

      // Send request
      final response = await http.post(
        Uri.parse(_brevoApiUrl),
        headers: {
          'api-key': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 201) {
        AppLogger.info('Email sent successfully via Brevo',
            category: LogCategory.email);
        return true;
      } else {
        AppLogger.error('Brevo API error: ${response.body}',
            category: LogCategory.email);
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send email via Brevo',
          error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Send email via custom backend (recommended for production)
  /// This requires setting up your own backend endpoint
  static Future<bool> sendEmailViaBackend({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlContent,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Uint8List? excelBytes,
    String? excelFileName,
    Map<String, dynamic>? userInfo,
  }) async {
    try {
      // Check if backend URL is configured
      if (_customBackendUrl == 'https://your-backend.com/api/send-email') {
        AppLogger.warning('Custom backend URL not configured. Using client-side fallback.',
            category: LogCategory.email);

        // Use Firebase Functions as a backend (if available)
        return await sendEmailViaFirebaseFunctions(
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          subject: subject,
          htmlContent: htmlContent,
          pdfBytes: pdfBytes,
          pdfFileName: pdfFileName,
          excelBytes: excelBytes,
          excelFileName: excelFileName,
          userInfo: userInfo,
        );
      }

      // Build multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_customBackendUrl));

      // Add form fields
      request.fields['to'] = recipientEmail;
      request.fields['toName'] = recipientName;
      request.fields['subject'] = subject;
      request.fields['html'] = htmlContent;
      request.fields['from'] = SecureEmailConfig.gmailAddress;
      request.fields['fromName'] = SecureEmailConfig.senderName;

      if (userInfo != null) {
        request.fields['userInfo'] = json.encode(userInfo);
      }

      // Add file attachments
      if (pdfBytes != null && pdfFileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'pdf',
          pdfBytes,
          filename: pdfFileName,
        ));
      }

      if (excelBytes != null && excelFileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'excel',
          excelBytes,
          filename: excelFileName,
        ));
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        AppLogger.info('Email sent successfully via backend',
            category: LogCategory.email);
        return true;
      } else {
        AppLogger.error('Backend API error: $responseBody',
            category: LogCategory.email);
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send email via backend',
          error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Send email via Firebase Functions (PRIMARY METHOD)
  /// This is the preferred method that works with your existing Firebase setup
  static Future<bool> sendEmailViaFirebaseFunctions({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlContent,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Uint8List? excelBytes,
    String? excelFileName,
    Map<String, dynamic>? userInfo,
  }) async {
    try {
      // Firebase Functions endpoint - using the existing sendQuoteEmail function
      const String functionsUrl = 'https://us-central1-taquotes.cloudfunctions.net/sendQuoteEmail';

      // Extract quote number from subject or generate one
      final quoteNumber = subject.contains('#')
          ? subject.split('#').last.split(' ').first
          : 'Q${DateTime.now().millisecondsSinceEpoch}';

      // Build request body matching the Firebase Function structure
      final requestBody = {
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'quoteNumber': quoteNumber,
        'totalAmount': 0, // Will be extracted from HTML content if needed
        'attachPdf': pdfBytes != null,
        'attachExcel': excelBytes != null,
        'products': [], // Can be extracted from HTML if needed
      };

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

        // Final fallback: Show download prompt for attachments
        return _fallbackToDownload(
          subject: subject,
          htmlContent: htmlContent,
          pdfBytes: pdfBytes,
          pdfFileName: pdfFileName,
          excelBytes: excelBytes,
          excelFileName: excelFileName,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to send email via Firebase Functions',
          error: e, category: LogCategory.email);
      return false;
    }
  }

  /// Fallback: Prompt user to download attachments and send manually
  static bool _fallbackToDownload({
    required String subject,
    required String htmlContent,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Uint8List? excelBytes,
    String? excelFileName,
  }) {
    try {
      // Use HTML5 download functionality
      // This will be implemented in the UI layer
      AppLogger.warning('Email service unavailable. Prompting user to download attachments.',
          category: LogCategory.email);

      // Return false to indicate email wasn't sent automatically
      // The UI should handle this and provide download links
      return false;
    } catch (e) {
      AppLogger.error('Failed to provide download fallback',
          error: e, category: LogCategory.email);
      return false;
    }
  }
}