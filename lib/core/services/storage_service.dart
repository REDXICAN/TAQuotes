// lib/core/services/storage_service.dart
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
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

  // Upload PDF to Firebase Storage
  static Future<String?> uploadPDF({
    required Uint8List pdfBytes,
    required String fileName,
    String? folderPath,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to upload PDF');
      }

      AppLogger.info(
        'Starting PDF upload',
        category: LogCategory.database,
        data: {
          'fileName': fileName,
          'fileSize': pdfBytes.length,
          'folderPath': folderPath,
        },
      );

      // Validate file size (max 10MB for PDFs)
      if (pdfBytes.length > 10 * 1024 * 1024) {
        throw Exception('PDF file size exceeds 10MB limit');
      }

      // Ensure file has .pdf extension
      final pdfFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';

      // Create storage reference
      // Structure: pdfs/{folderPath}/{userId}/{fileName} or pdfs/{userId}/{fileName}
      Reference storageRef;
      if (folderPath != null && folderPath.isNotEmpty) {
        storageRef = _storage.ref()
            .child('pdfs')
            .child(folderPath)
            .child(user.uid)
            .child(pdfFileName);
      } else {
        storageRef = _storage.ref()
            .child('pdfs')
            .child(user.uid)
            .child(pdfFileName);
      }

      // Upload PDF with metadata
      final uploadTask = await storageRef.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalFileName': fileName,
          },
        ),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      AppLogger.info(
        'PDF uploaded successfully',
        category: LogCategory.database,
        data: {
          'downloadUrl': downloadUrl,
          'fileName': pdfFileName,
          'size': pdfBytes.length,
        },
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to upload PDF',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.database,
      );
      return null;
    }
  }

  // Upload quote PDF to Firebase Storage
  static Future<String?> uploadQuotePDF({
    required Uint8List pdfBytes,
    required String quoteNumber,
    String? clientId,
  }) async {
    try {
      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'quote_${quoteNumber}_$timestamp.pdf';

      // Upload to quotes folder
      return await uploadPDF(
        pdfBytes: pdfBytes,
        fileName: fileName,
        folderPath: 'quotes',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to upload quote PDF',
        error: e,
        category: LogCategory.database,
      );
      return null;
    }
  }

  // Upload Excel file to Firebase Storage
  static Future<String?> uploadExcel({
    required Uint8List excelBytes,
    required String fileName,
    String? folderPath,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to upload Excel');
      }

      AppLogger.info(
        'Starting Excel upload',
        category: LogCategory.database,
        data: {
          'fileName': fileName,
          'fileSize': excelBytes.length,
          'folderPath': folderPath,
        },
      );

      // Validate file size (max 25MB for Excel)
      if (excelBytes.length > 25 * 1024 * 1024) {
        throw Exception('Excel file size exceeds 25MB limit');
      }

      // Ensure file has .xlsx extension
      final excelFileName = fileName.endsWith('.xlsx') ? fileName : '$fileName.xlsx';

      // Create storage reference
      Reference storageRef;
      if (folderPath != null && folderPath.isNotEmpty) {
        storageRef = _storage.ref()
            .child('excel')
            .child(folderPath)
            .child(user.uid)
            .child(excelFileName);
      } else {
        storageRef = _storage.ref()
            .child('excel')
            .child(user.uid)
            .child(excelFileName);
      }

      // Upload Excel with metadata
      final uploadTask = await storageRef.putData(
        excelBytes,
        SettableMetadata(
          contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalFileName': fileName,
          },
        ),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      AppLogger.info(
        'Excel uploaded successfully',
        category: LogCategory.database,
        data: {
          'downloadUrl': downloadUrl,
          'fileName': excelFileName,
          'size': excelBytes.length,
        },
      );

      return downloadUrl;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to upload Excel',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.database,
      );
      return null;
    }
  }

  // Delete file from Firebase Storage
  static Future<bool> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();

      AppLogger.info(
        'File deleted successfully',
        category: LogCategory.database,
        data: {'fileUrl': fileUrl},
      );

      return true;
    } catch (e) {
      AppLogger.error(
        'Failed to delete file',
        error: e,
        category: LogCategory.database,
      );
      return false;
    }
  }

  // Get list of user's PDFs
  static Future<List<Map<String, dynamic>>> getUserPDFs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return [];
      }

      final listResult = await _storage.ref()
          .child('pdfs')
          .child(user.uid)
          .listAll();

      final pdfs = <Map<String, dynamic>>[];

      for (var item in listResult.items) {
        final metadata = await item.getMetadata();
        final url = await item.getDownloadURL();

        pdfs.add({
          'name': item.name,
          'url': url,
          'size': metadata.size,
          'created': metadata.timeCreated,
          'contentType': metadata.contentType,
          'customMetadata': metadata.customMetadata,
        });
      }

      return pdfs;
    } catch (e) {
      AppLogger.error(
        'Failed to get user PDFs',
        error: e,
        category: LogCategory.database,
      );
      return [];
    }
  }
}