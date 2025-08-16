// Test email configuration
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  print('Testing Email Configuration...\n');
  
  // Load .env file
  try {
    await dotenv.load(fileName: '.env');
    print('✅ .env file loaded successfully');
  } catch (e) {
    print('❌ Failed to load .env file: $e');
    exit(1);
  }
  
  // Check email configuration
  final emailAddress = dotenv.env['EMAIL_SENDER_ADDRESS'];
  final emailPassword = dotenv.env['EMAIL_APP_PASSWORD'];
  
  print('\n📧 Email Configuration:');
  print('Email Address: ${emailAddress ?? "NOT SET"}');
  print('App Password: ${emailPassword != null ? "SET (${emailPassword.length} characters)" : "NOT SET"}');
  
  if (emailAddress == null || emailAddress.isEmpty) {
    print('\n❌ EMAIL_SENDER_ADDRESS is not set in .env file');
    print('Add this line to your .env file:');
    print('EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com');
  }
  
  if (emailPassword == null || emailPassword.isEmpty) {
    print('\n❌ EMAIL_APP_PASSWORD is not set in .env file');
    print('Add this line to your .env file:');
    print('EMAIL_APP_PASSWORD=mvev oryh bkkk lufm');
  }
  
  if (emailAddress != null && emailPassword != null) {
    print('\n✅ Email configuration appears to be set correctly!');
    print('\nExpected values:');
    print('Email: turboairquotes@gmail.com');
    print('Password format: 16 characters (4 groups of 4 letters)');
    
    // Validate format
    if (emailAddress == 'turboairquotes@gmail.com') {
      print('✅ Email address matches expected value');
    } else {
      print('⚠️ Email address does not match expected value');
    }
    
    // Check password format (should be 16 chars without spaces or 19 with spaces)
    final passwordNoSpaces = emailPassword.replaceAll(' ', '');
    if (passwordNoSpaces.length == 16) {
      print('✅ App password has correct length');
    } else {
      print('⚠️ App password length incorrect (expected 16 characters without spaces)');
    }
  }
}