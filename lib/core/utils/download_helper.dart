// lib/core/utils/download_helper.dart

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/app_logger.dart';

// Conditional imports for web
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

class DownloadHelper {
  /// Download a file from a URL
  static Future<void> downloadFromUrl({
    required String url,
    required String filename,
    String? mimeType,
  }) async {
    try {
      AppLogger.info('Downloading file from URL: $url', category: LogCategory.general);

      // Download the file
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: HTTP ${response.statusCode}');
      }

      // Convert response body to Uint8List
      final bytes = response.bodyBytes;

      // Use existing download method
      await downloadFile(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType ?? 'application/octet-stream',
      );

    } catch (e) {
      AppLogger.error('Error downloading from URL', error: e, category: LogCategory.general);
      rethrow;
    }
  }

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
  static Future<void> downloadFileLegacy(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName, null);
    } else {
      await downloadFileNative(bytes, fileName);
    }
  }
  
  static Future<void> downloadFileNative(Uint8List bytes, String fileName) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, save to downloads directory
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final downloadsPath = '${directory.path}/Download';
          final downloadsDir = Directory(downloadsPath);
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          final file = File('$downloadsPath/$fileName');
          await file.writeAsBytes(bytes);

          AppLogger.info(
            'File saved to: ${file.path}',
            category: LogCategory.general,
          );
        } else {
          throw Exception('Could not access storage directory');
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // For desktop platforms, use file picker save dialog
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save file',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: _getFileExtensions(fileName),
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(bytes);

          AppLogger.info(
            'File saved to: $outputPath',
            category: LogCategory.general,
          );
        } else {
          AppLogger.info(
            'Save cancelled by user',
            category: LogCategory.general,
          );
        }
      } else {
        throw UnsupportedError('Platform not supported for file downloads');
      }
    } catch (e) {
      AppLogger.error(
        'Error saving file',
        error: e,
        category: LogCategory.general,
      );
      rethrow;
    }
  }

  static List<String> _getFileExtensions(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return ['pdf'];
      case 'xlsx':
      case 'xls':
        return ['xlsx', 'xls'];
      case 'csv':
        return ['csv'];
      case 'txt':
        return ['txt'];
      case 'json':
        return ['json'];
      default:
        return ['*'];
    }
  }
}