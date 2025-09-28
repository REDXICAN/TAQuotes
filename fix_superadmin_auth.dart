// fix_superadmin_auth.dart
// Script to ensure superadmin account exists in Firebase Auth

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  print('Setting up superadmin authentication...');

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp();

  final auth = FirebaseAuth.instance;
  final database = FirebaseDatabase.instance;

  // Get credentials from .env
  final adminEmail = dotenv.env['ADMIN_EMAIL'] ?? '';
  final adminPassword = dotenv.env['ADMIN_PASSWORD'] ?? '';

  if (adminEmail.isEmpty || adminPassword.isEmpty) {
    print('Error: Admin credentials not found in .env file');
    return;
  }

  print('Admin email: $adminEmail');

  try {
    // Try to sign in first
    await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    print('✅ Superadmin account exists and credentials are correct');

    // Ensure user profile exists with correct status
    final user = auth.currentUser;
    if (user != null) {
      await database.ref('user_profiles/${user.uid}').set({
        'email': adminEmail,
        'name': 'Super Admin',
        'role': 'superadmin',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      print('✅ User profile updated with active status');
    }

  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      print('User not found. Creating superadmin account...');

      try {
        // Create the account
        final credential = await auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );

        print('✅ Superadmin account created successfully');

        // Set up user profile
        if (credential.user != null) {
          await database.ref('user_profiles/${credential.user!.uid}').set({
            'email': adminEmail,
            'name': 'Super Admin',
            'role': 'superadmin',
            'status': 'active',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
          print('✅ User profile created with active status');
        }

      } catch (createError) {
        print('❌ Error creating account: $createError');
      }
    } else if (e.code == 'wrong-password') {
      print('❌ Wrong password! The account exists but password doesn\'t match.');
      print('   Update the password in Firebase Console or use password reset.');
    } else {
      print('❌ Error: ${e.message}');
    }
  }

  await auth.signOut();
  print('\nDone! You can now login with the superadmin account.');
}