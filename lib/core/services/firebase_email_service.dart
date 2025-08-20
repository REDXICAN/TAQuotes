// lib/core/services/firebase_email_service.dart
// Email service that uses Firebase Functions to send emails
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_logger.dart';

class FirebaseEmailService {
  static final FirebaseEmailService _instance = FirebaseEmailService._internal();
  factory FirebaseEmailService() => _instance;
  FirebaseEmailService._internal();

  // Firebase Functions endpoints
  static const String _baseUrl = 'https://us-central1-taquotes.cloudfunctions.net';
  
  /// Send quote email with optional attachments via Firebase Function
  Future<bool> sendQuoteEmail({
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
      AppLogger.info('Sending email via Firebase Function', 
        category: LogCategory.business,
        data: {
          'recipient': recipientEmail,
          'quoteNumber': quoteNumber,
          'attachments': {
            'pdf': attachPdf && pdfBytes != null,
            'excel': attachExcel && excelBytes != null,
          }
        });

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'quoteNumber': quoteNumber,
        'totalAmount': totalAmount,
        'attachPdf': attachPdf,
        'attachExcel': attachExcel,
      };
      
      // Add products if provided
      if (products != null && products.isNotEmpty) {
        requestBody['products'] = products;
        AppLogger.info('Adding ${products.length} products to email', category: LogCategory.business);
      }

      // Convert attachments to base64 if provided
      if (attachPdf && pdfBytes != null && pdfBytes.isNotEmpty) {
        requestBody['pdfBase64'] = base64Encode(pdfBytes);
        AppLogger.info('PDF attachment prepared: ${pdfBytes.length} bytes',
          category: LogCategory.business);
      }

      if (attachExcel && excelBytes != null && excelBytes.isNotEmpty) {
        requestBody['excelBase64'] = base64Encode(excelBytes);
        AppLogger.info('Excel attachment prepared: ${excelBytes.length} bytes',
          category: LogCategory.business);
      }

      // Make HTTP request to Firebase Function
      final url = '$_baseUrl/sendQuoteEmail';
      AppLogger.info('Sending email request to: $url', category: LogCategory.business);
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          AppLogger.error('Email request timed out', category: LogCategory.business);
          throw Exception('Email request timed out after 30 seconds');
        },
      );
      
      AppLogger.info('Email response received: ${response.statusCode}', category: LogCategory.business);

      // Parse response
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        AppLogger.info('Email sent successfully via Firebase Function', 
          category: LogCategory.business,
          data: {
            'messageId': responseData['messageId'],
            'message': responseData['message'],
          });
        return true;
      } else {
        try {
          final errorData = jsonDecode(response.body);
          AppLogger.error('Firebase Function returned error', 
            category: LogCategory.business,
            data: {
              'statusCode': response.statusCode,
              'error': errorData['error'] ?? 'Unknown error',
              'details': errorData['details'] ?? response.body,
            });
        } catch (_) {
          AppLogger.error('Firebase Function returned error', 
            category: LogCategory.business,
            data: {
              'statusCode': response.statusCode,
              'body': response.body,
            });
        }
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send email via Firebase Function', 
        error: e,
        category: LogCategory.business,
        data: {
          'recipient': recipientEmail,
          'quoteNumber': quoteNumber,
          'error_type': e.runtimeType.toString(),
          'error_message': e.toString(),
        });
      
      // Return false on error, don't throw
      return false;
    }
  }

  /// Send test email to verify configuration
  Future<bool> sendTestEmail(String recipientEmail) async {
    try {
      AppLogger.info('Sending test email via Firebase Function', 
        category: LogCategory.business,
        data: {'recipient': recipientEmail});

      final response = await http.post(
        Uri.parse('$_baseUrl/testEmail'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipientEmail': recipientEmail,
        }),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Test email request timed out');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        AppLogger.info('Test email sent successfully', 
          category: LogCategory.business,
          data: responseData);
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        AppLogger.error('Test email failed', 
          category: LogCategory.business,
          data: errorData);
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send test email', 
        error: e,
        category: LogCategory.business);
      return false;
    }
  }
}