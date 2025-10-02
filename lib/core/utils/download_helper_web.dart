// lib/core/utils/download_helper_web.dart
// ignore: avoid_web_libraries_in_flutter
// ignore_for_file: deprecated_member_use

import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadFileWeb(Uint8List bytes, String fileName, [String? mimeType]) {
  // Determine MIME type from file extension if not provided
  if (mimeType == null || mimeType.isEmpty) {
    if (fileName.toLowerCase().endsWith('.xlsx')) {
      mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (fileName.toLowerCase().endsWith('.pdf')) {
      mimeType = 'application/pdf';
    } else if (fileName.toLowerCase().endsWith('.csv')) {
      mimeType = 'text/csv';
    } else {
      mimeType = 'application/octet-stream';
    }
  }
  
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}