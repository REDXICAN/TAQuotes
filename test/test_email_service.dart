import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/core/services/email_service_v2.dart';

void main() {
  test('Email service sends test email', () async {
    // Load environment variables
    await dotenv.load(fileName: '.env');
    
    // Create email service
    final emailService = EmailServiceV2();
    
    // Send test email using the correct method
    final result = await emailService.sendTestEmail('andres.xbgo@outlook.com');
    
    // Verify result
    expect(result, true, reason: 'Email should be sent successfully');
  });
  
  test('Email service sends quote email', () async {
    // Load environment variables if not already loaded
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env');
    }
    
    // Create email service
    final emailService = EmailServiceV2();
    
    // Send quote email
    final result = await emailService.sendQuoteEmail(
      recipientEmail: 'andres.xbgo@outlook.com',
      recipientName: 'Andres',
      quoteNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      totalAmount: 1234.56,
      attachPdf: false, // No PDF for this test
      attachExcel: false, // No Excel for this test
    );
    
    // Verify result
    expect(result, true, reason: 'Quote email should be sent successfully');
  });
}