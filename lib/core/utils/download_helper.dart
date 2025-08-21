// lib/core/utils/download_helper.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports for web
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

class DownloadHelper {
  static Future<void> downloadFile({
    required Uint8List bytes,
    required String filename,
    String? mimeType,
  }) async {
    if (kIsWeb) {
      downloadFileWeb(bytes, filename, mimeType);
    } else {
      // For desktop/mobile, use a different approach
      downloadFileNative(bytes, filename);
    }
  }
  
  // Legacy method for backward compatibility
  static void downloadFileLegacy(Uint8List bytes, String fileName) {
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName, null);
    } else {
      downloadFileNative(bytes, fileName);
    }
  }
  
  static void downloadFileNative(Uint8List bytes, String fileName) {
    // This will be implemented differently for each platform
    // For now, just save to downloads folder or show save dialog
    // You can use file_picker's FilePicker.platform.saveFile
  }
}