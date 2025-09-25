// lib/core/services/storage_service.dart
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_logger.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Constants for image optimization
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _maxImageWidth = 1024;
  static const int _maxImageHeight = 1024;
  static const int _compressionQuality = 85; // 85% quality
  
  // Compress and resize image before upload
  static Future<Uint8List?> _optimizeImage(Uint8List imageBytes) async {
    try {
      // Check file size first
      if (imageBytes.length > _maxFileSizeBytes) {
        AppLogger.info(
          'Image size ${imageBytes.length} bytes exceeds limit $_maxFileSizeBytes bytes',
          category: LogCategory.general,
        );
      }

      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Calculate new dimensions maintaining aspect ratio
      double width = image.width.toDouble();
      double height = image.height.toDouble();
      
      if (width > _maxImageWidth || height > _maxImageHeight) {
        final double aspectRatio = width / height;
        
        if (width > height) {
          width = _maxImageWidth.toDouble();
          height = width / aspectRatio;
        } else {
          height = _maxImageHeight.toDouble();
          width = height * aspectRatio;
        }
      }

      // Resize image if necessary
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, width, height),
        ui.Paint(),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(width.toInt(), height.toInt());
      
      // Convert back to bytes with compression
      final ByteData? byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final Uint8List compressedBytes = byteData.buffer.asUint8List();
        
        AppLogger.info(
          'Image optimized: ${imageBytes.length} -> ${compressedBytes.length} bytes',
          category: LogCategory.general,
          data: {
            'originalSize': imageBytes.length,
            'optimizedSize': compressedBytes.length,
            'compressionRatio': '${((1 - (compressedBytes.length / imageBytes.length)) * 100).toStringAsFixed(1)}%',
          }
        );
        
        return compressedBytes;
      }

      return imageBytes; // Return original if compression fails
    } catch (e) {
      AppLogger.error(
        'Error optimizing image, using original',
        error: e,
        category: LogCategory.general,
      );
      return imageBytes; // Return original if optimization fails
    }
  }
  
  
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
      
      // Optimize image before upload
      final optimizedBytes = await _optimizeImage(imageBytes);
      if (optimizedBytes == null) {
        throw Exception('Failed to optimize image');
      }
      
      // Create a reference to the location where we'll store the image
      // Structure: client_profiles/{userId}/{clientId}/{fileName}
      final storageRef = _storage.ref()
          .child('client_profiles')
          .child(user.uid)
          .child(clientId)
          .child(fileName);
      
      // Upload the optimized file with metadata
      final uploadTask = await storageRef.putData(
        optimizedBytes,
        SettableMetadata(
          contentType: 'image/${fileName.split('.').last}',
          customMetadata: {
            'uploadedBy': user.uid,
            'optimized': 'true',
            'originalSize': imageBytes.length.toString(),
            'optimizedSize': optimizedBytes.length.toString(),
          }
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
      
      // Optimize image before upload
      final optimizedBytes = await _optimizeImage(imageBytes);
      if (optimizedBytes == null) {
        throw Exception('Failed to optimize image');
      }
      
      // Create a reference to the location where we'll store the image
      // Structure: user_profiles/{userId}/{fileName}
      final storageRef = _storage.ref()
          .child('user_profiles')
          .child(user.uid)
          .child(fileName);
      
      // Upload the optimized file with metadata
      final uploadTask = await storageRef.putData(
        optimizedBytes,
        SettableMetadata(
          contentType: 'image/${fileName.split('.').last}',
          customMetadata: {
            'uploadedBy': user.uid,
            'optimized': 'true',
            'originalSize': imageBytes.length.toString(),
            'optimizedSize': optimizedBytes.length.toString(),
          }
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