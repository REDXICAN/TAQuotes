// lib/core/services/emailjs_service.dart
// EmailJS service for sending emails from web browser
// Sign up at https://www.emailjs.com/ to get your credentials

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_logger.dart';

class EmailJSService {
  // EmailJS credentials - Get these from https://www.emailjs.com/
  // 1. Sign up for free account
  // 2. Add Gmail service
  // 3. Create email template
  // 4. Get these IDs from dashboard
  static const String _serviceId = 'service_taquotes'; // Replace with your service ID
  static const String _templateId = 'template_quote'; // Replace with your template ID
  static const String _publicKey = 'YOUR_PUBLIC_KEY'; // Replace with your public key
  
  /// Send email using EmailJS (web only)
  static Future<bool> sendEmail({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required double totalAmount,
    String? pdfUrl,
    String? excelUrl,
  }) async {
    if (!kIsWeb) {
      AppLogger.error('EmailJS only works on web platform', category: LogCategory.business);
      return false;
    }
    
    try {
      // Create template parameters
      final templateParams = {
        'to_email': recipientEmail,
        'to_name': recipientName,
        'quote_number': quoteNumber,
        'total_amount': totalAmount.toStringAsFixed(2),
        'pdf_link': pdfUrl ?? '',
        'excel_link': excelUrl ?? '',
        'reply_to': 'turboairquotes@gmail.com',
      };
      
      // Call EmailJS API
      final response = await html.HttpRequest.request(
        'https://api.emailjs.com/api/v1.0/email/send',
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
        },
        sendData: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': templateParams,
        }),
      );
      
      if (response.status == 200) {
        AppLogger.info('Email sent successfully via EmailJS', category: LogCategory.business);
        return true;
      } else {
        AppLogger.error('EmailJS failed with status: ${response.status}', category: LogCategory.business);
        return false;
      }
    } catch (e) {
      AppLogger.error('EmailJS error', error: e, category: LogCategory.business);
      return false;
    }
  }
  
  /// Upload file to temporary storage and get URL
  static Future<String?> uploadToTemporaryStorage(Uint8List bytes, String filename) async {
    try {
      // Create a blob URL for the file
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Note: This URL is temporary and only valid for the current session
      // For permanent storage, use Firebase Storage or similar
      return url;
    } catch (e) {
      AppLogger.error('Failed to create blob URL', error: e, category: LogCategory.business);
      return null;
    }
  }
}