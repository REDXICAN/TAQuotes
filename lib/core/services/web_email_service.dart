// lib/core/services/web_email_service.dart
// Web-compatible email service using HTTP APIs

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_logger.dart';
import '../config/email_config.dart';

class WebEmailService {
  
  /// Send email using Formspree (https://formspree.io/)
  /// Sign up for free and get your form ID
  static Future<bool> sendViaFormspree({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required double totalAmount,
  }) async {
    const String formspreeEndpoint = 'https://formspree.io/f/YOUR_FORM_ID'; // Replace with your Formspree form ID
    
    try {
      final response = await http.post(
        Uri.parse(formspreeEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': recipientEmail,
          'name': recipientName,
          'message': '''
            Quote #$quoteNumber
            Customer: $recipientName
            Total Amount: \$${totalAmount.toStringAsFixed(2)}
            
            Please download the quote from your account.
          ''',
          '_replyto': recipientEmail,
          '_subject': 'Quote #$quoteNumber from TurboAir',
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.info('Email sent via Formspree', category: LogCategory.business);
        return true;
      } else {
        AppLogger.error('Formspree failed: ${response.statusCode}', category: LogCategory.business);
        return false;
      }
    } catch (e) {
      AppLogger.error('Formspree error', error: e, category: LogCategory.business);
      return false;
    }
  }
  
  /// Alternative: Use Web3Forms (https://web3forms.com/)
  /// No signup required, just use your email
  static Future<bool> sendViaWeb3Forms({
    required String recipientEmail,
    required String recipientName,
    required String quoteNumber,
    required double totalAmount,
  }) async {
    const String apiKey = 'YOUR_ACCESS_KEY'; // Get from https://web3forms.com/
    
    try {
      final response = await http.post(
        Uri.parse('https://api.web3forms.com/submit'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'access_key': apiKey,
          'email': recipientEmail,
          'name': recipientName,
          'subject': 'Quote #$quoteNumber from TurboAir',
          'message': '''
            Quote Details:
            - Quote Number: $quoteNumber
            - Customer: $recipientName
            - Total Amount: \$${totalAmount.toStringAsFixed(2)}
            
            Thank you for your business!
          ''',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          AppLogger.info('Email sent via Web3Forms', category: LogCategory.business);
          return true;
        }
      }
      
      AppLogger.error('Web3Forms failed', category: LogCategory.business);
      return false;
    } catch (e) {
      AppLogger.error('Web3Forms error', error: e, category: LogCategory.business);
      return false;
    }
  }
}