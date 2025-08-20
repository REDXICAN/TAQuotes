// lib/core/utils/download_helper.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports for web
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

class DownloadHelper {
  static void downloadFile(Uint8List bytes, String fileName) {
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName);
    } else {
      // For desktop/mobile, use a different approach
      downloadFileNative(bytes, fileName);
    }
  }
  
  static void downloadFileNative(Uint8List bytes, String fileName) {
    // This will be implemented differently for each platform
    // For now, just save to downloads folder or show save dialog
    // You can use file_picker's FilePicker.platform.saveFile
  }
}