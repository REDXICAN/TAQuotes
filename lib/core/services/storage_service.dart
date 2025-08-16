// lib/core/services/storage_service.dart
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_logger.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Upload profile picture for client
  static Future<String?> uploadClientProfilePicture({
    required String clientId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Create a reference to the location where we'll store the image
      // Structure: client_profiles/{userId}/{clientId}/{fileName}
      final storageRef = _storage.ref()
          .child('client_profiles')
          .child(user.uid)
          .child(clientId)
          .child(fileName);
      
      // Upload the file
      final uploadTask = await storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/${fileName.split('.').last}',
        ),
      );
      
      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      AppLogger.info(
        'Client profile picture uploaded successfully',
        category: LogCategory.database,
      );
      
      return downloadUrl;
    } catch (e) {
      AppLogger.error(
        'Error uploading client profile picture',
        error: e,
        category: LogCategory.database,
      );
      return null;
    }
  }
  
  // Upload profile picture for user
  static Future<String?> uploadUserProfilePicture({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Create a reference to the location where we'll store the image
      // Structure: user_profiles/{userId}/{fileName}
      final storageRef = _storage.ref()
          .child('user_profiles')
          .child(user.uid)
          .child(fileName);
      
      // Upload the file
      final uploadTask = await storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/${fileName.split('.').last}',
        ),
      );
      
      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      AppLogger.info(
        'User profile picture uploaded successfully',
        category: LogCategory.database,
      );
      
      return downloadUrl;
    } catch (e) {
      AppLogger.error(
        'Error uploading user profile picture',
        error: e,
        category: LogCategory.database,
      );
      return null;
    }
  }
  
  // Delete profile picture
  static Future<bool> deleteProfilePicture(String imageUrl) async {
    try {
      // Get reference from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      
      AppLogger.info(
        'Profile picture deleted successfully',
        category: LogCategory.database,
      );
      
      return true;
    } catch (e) {
      AppLogger.error(
        'Error deleting profile picture',
        error: e,
        category: LogCategory.database,
      );
      return false;
    }
  }
}