import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  print('Testing Gmail SMTP with app password...');
  
  // Gmail credentials from .env
  final username = 'turboairquotes@gmail.com';
  final password = 'ioejhaylapwdxred';  // App password
  
  final smtpServer = gmail(username, password);
  
  final message = Message()
    ..from = Address(username, 'TurboAir Quote System')
    ..recipients.add('andres.xbgo@outlook.com')
    ..subject = 'Test Email - ${DateTime.now()}'
    ..text = 'This is a test email from TurboAir Quote System'
    ..html = '''
      <h2>Test Email</h2>
      <p>This is a test email from TurboAir Quote System.</p>
      <p>Timestamp: ${DateTime.now()}</p>
      <hr>
      <p><small>If you received this, the email configuration is working!</small></p>
    ''';

  try {
    print('Sending email to andres.xbgo@outlook.com...');
    final sendReport = await send(message, smtpServer);
    print('✅ Email sent successfully!');
    print('Message: ${sendReport.toString()}');
    exit(0);
  } on MailerException catch (e) {
    print('❌ Email failed!');
    print('Message: ${e.message}');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
    exit(1);
  } catch (e) {
    print('❌ Unexpected error: $e');
    exit(1);
  }
}