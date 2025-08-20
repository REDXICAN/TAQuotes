// lib/core/utils/download_helper_stub.dart

import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String fileName) {
  // Stub implementation for non-web platforms
  // This will never be called on non-web platforms
  throw UnsupportedError('downloadFileWeb is only supported on web platform');
}