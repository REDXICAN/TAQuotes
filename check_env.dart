// Simple .env file checker
import 'dart:io';

void main() {
  print('Checking .env file configuration...\n');
  
  final file = File('.env');
  
  if (!file.existsSync()) {
    print('❌ .env file not found!');
    print('Please create a .env file in the project root');
    return;
  }
  
  print('✅ .env file exists\n');
  
  final lines = file.readAsLinesSync();
  final config = <String, String>{};
  
  for (final line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      config[key] = value;
    }
  }
  
  print('📧 Email Configuration Status:');
  print('--------------------------------');
  
  // Check email address
  final emailAddress = config['EMAIL_SENDER_ADDRESS'];
  if (emailAddress != null && emailAddress.isNotEmpty) {
    print('✅ EMAIL_SENDER_ADDRESS: $emailAddress');
    if (emailAddress != 'turboairquotes@gmail.com') {
      print('   ⚠️ Expected: turboairquotes@gmail.com');
    }
  } else {
    print('❌ EMAIL_SENDER_ADDRESS is missing');
    print('   Add to .env: EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com');
  }
  
  // Check app password
  final appPassword = config['EMAIL_APP_PASSWORD'];
  if (appPassword != null && appPassword.isNotEmpty) {
    final passwordLength = appPassword.replaceAll(' ', '').length;
    print('✅ EMAIL_APP_PASSWORD: Set ($passwordLength characters)');
    
    // Google App passwords are 16 characters
    if (passwordLength != 16) {
      print('   ⚠️ App password should be 16 characters (got $passwordLength)');
      print('   Expected format: mvev oryh bkkk lufm (or without spaces)');
    }
  } else {
    print('❌ EMAIL_APP_PASSWORD is missing');
    print('   Add to .env: EMAIL_APP_PASSWORD=mvev oryh bkkk lufm');
    print('   (Get app password from: https://myaccount.google.com/apppasswords)');
  }
  
  print('\n🔧 Instructions to fix:');
  print('1. Open the .env file in your project root');
  print('2. Add or update these lines:');
  print('   EMAIL_SENDER_ADDRESS=turboairquotes@gmail.com');
  print('   EMAIL_APP_PASSWORD=mvev oryh bkkk lufm');
  print('3. Save the file and restart the app');
  
  print('\n📝 Note: The app password should be the 16-character code');
  print('   from Google\'s App Passwords page, with or without spaces.');
}