import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/core/services/email_service_v2.dart';

void main() async {
  print('Loading environment variables...');
  await dotenv.load(fileName: '.env');
  
  print('Testing email configuration...');
  print('Sender: ${dotenv.env['EMAIL_SENDER_ADDRESS']}');
  print('App Password: ${dotenv.env['EMAIL_APP_PASSWORD']?.replaceRange(4, null, '****')}');
  
  final emailService = EmailServiceV2();
  
  print('\nSending test email to andres.xbgo@outlook.com...');
  final success = await emailService.sendTestEmail('andres.xbgo@outlook.com');
  
  if (success) {
    print('✅ Email sent successfully!');
    print('Please check your inbox at andres.xbgo@outlook.com');
  } else {
    print('❌ Failed to send email');
    print('Please check the configuration and try again');
  }
  
  print('\nTesting quote email with mock data...');
  final quoteSuccess = await emailService.sendQuoteEmail(
    recipientEmail: 'andres.xbgo@outlook.com',
    recipientName: 'Andres',
    quoteNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
    totalAmount: 1234.56,
    attachPdf: false,  // No attachment for test
  );
  
  if (quoteSuccess) {
    print('✅ Quote email sent successfully!');
  } else {
    print('❌ Failed to send quote email');
  }
}