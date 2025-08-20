// Stub implementation for non-web platforms
import 'dart:typed_data';

class EmailJSService {
  static const String _serviceId = 'service_taquotes';
  static const String _templateId = 'template_quote';
  static const String _publicKey = 'YOUR_PUBLIC_KEY';
  
  static bool get isConfigured => false;
  
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
    // EmailJS is only available on web
    return false;
  }
}