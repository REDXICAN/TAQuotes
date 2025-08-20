// Web implementation of EmailJS service
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_logger.dart';

class EmailJSService {
  static const String _serviceId = 'service_taquotes';
  static const String _templateId = 'template_quote';
  static const String _publicKey = 'YOUR_PUBLIC_KEY';
  
  static bool get isConfigured {
    return _serviceId != 'YOUR_SERVICE_ID' && 
           _templateId != 'YOUR_TEMPLATE_ID' && 
           _publicKey != 'YOUR_PUBLIC_KEY';
  }
  
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
    if (!kIsWeb) {
      AppLogger.warning('EmailJS is only available on web platform', category: LogCategory.email);
      return false;
    }
    
    if (!isConfigured) {
      AppLogger.warning('EmailJS is not configured. Please set up credentials.', category: LogCategory.email);
      return false;
    }
    
    try {
      // Load EmailJS SDK if not already loaded
      await _loadEmailJS();
      
      // Prepare template parameters
      final templateParams = {
        'to_email': recipientEmail,
        'to_name': recipientName,
        'quote_number': quoteNumber,
        'total_amount': totalAmount.toStringAsFixed(2),
        'from_name': 'TurboAir Quotes',
        'reply_to': 'noreply@turboair.com',
      };
      
      // Add products table if provided
      if (products != null && products.isNotEmpty) {
        final productsHtml = _buildProductsTable(products);
        templateParams['products_table'] = productsHtml;
      }
      
      // Note: EmailJS doesn't support file attachments in free tier
      // For attachments, you need EmailJS Pro or use a different service
      
      // Send email via EmailJS
      final response = await html.window.fetch(
        'https://api.emailjs.com/api/v1.0/email/send',
        {
          'method': 'POST',
          'headers': {
            'Content-Type': 'application/json',
          },
          'body': json.encode({
            'service_id': _serviceId,
            'template_id': _templateId,
            'user_id': _publicKey,
            'template_params': templateParams,
          }),
        },
      );
      
      if (response.ok ?? false) {
        AppLogger.info('Email sent successfully via EmailJS', category: LogCategory.email);
        return true;
      } else {
        final errorText = await response.text();
        AppLogger.error('EmailJS error: $errorText', category: LogCategory.email);
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send email via EmailJS', error: e, category: LogCategory.email);
      return false;
    }
  }
  
  static Future<void> _loadEmailJS() async {
    // Check if EmailJS is already loaded
    if (html.document.querySelector('script[src*="emailjs.com"]') != null) {
      return;
    }
    
    // Load EmailJS SDK
    final script = html.ScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/@emailjs/browser@3/dist/email.min.js'
      ..async = true;
    
    html.document.head?.append(script);
    
    // Wait for script to load
    await script.onLoad.first;
  }
  
  static String _buildProductsTable(List<Map<String, dynamic>> products) {
    final buffer = StringBuffer();
    buffer.writeln('<table style="width: 100%; border-collapse: collapse;">');
    buffer.writeln('<thead>');
    buffer.writeln('<tr style="background-color: #f0f0f0;">');
    buffer.writeln('<th style="padding: 8px; border: 1px solid #ddd;">Product</th>');
    buffer.writeln('<th style="padding: 8px; border: 1px solid #ddd;">Quantity</th>');
    buffer.writeln('<th style="padding: 8px; border: 1px solid #ddd;">Price</th>');
    buffer.writeln('</tr>');
    buffer.writeln('</thead>');
    buffer.writeln('<tbody>');
    
    for (final product in products) {
      buffer.writeln('<tr>');
      buffer.writeln('<td style="padding: 8px; border: 1px solid #ddd;">${product['name'] ?? 'Unknown'}</td>');
      buffer.writeln('<td style="padding: 8px; border: 1px solid #ddd;">${product['quantity'] ?? 1}</td>');
      buffer.writeln('<td style="padding: 8px; border: 1px solid #ddd;">\$${product['unitPrice'] ?? 0}</td>');
      buffer.writeln('</tr>');
    }
    
    buffer.writeln('</tbody>');
    buffer.writeln('</table>');
    
    return buffer.toString();
  }
}