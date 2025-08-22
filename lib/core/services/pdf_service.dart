// lib/core/services/pdf_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'app_logger.dart';

class PdfService {
  static const String pdfBasePath = r'O:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\TURBO_VISION_SIMPLIFIED\pdfs';
  
  /// Find PDF file for a given SKU using matching logic
  /// First tries exact match with first 3 letters + 2 numbers
  /// Then falls back to broader matching
  static Future<File?> findPdfForSku(String sku) async {
    try {
      // Clean and prepare SKU
      final cleanSku = sku.toUpperCase().trim();
      
      AppLogger.info('Searching for PDF for SKU: $cleanSku', 
        category: LogCategory.business,
        data: {'basePath': pdfBasePath}
      );
      
      // Check if PDF directory exists
      final pdfDir = Directory(pdfBasePath);
      if (!await pdfDir.exists()) {
        AppLogger.error('PDF directory does not exist: $pdfBasePath', 
          category: LogCategory.business
        );
        return null;
      }
      
      // List all PDF files in directory
      final pdfFiles = await pdfDir
          .list()
          .where((entity) => entity is File && entity.path.toLowerCase().endsWith('.pdf'))
          .cast<File>()
          .toList();
      
      AppLogger.debug('Found ${pdfFiles.length} PDF files in directory', 
        category: LogCategory.business
      );
      
      // Try exact match first
      for (final file in pdfFiles) {
        final fileName = path.basenameWithoutExtension(file.path).toUpperCase();
        if (fileName == cleanSku) {
          AppLogger.info('Found exact PDF match: ${file.path}', 
            category: LogCategory.business
          );
          return file;
        }
      }
      
      // Extract pattern for matching (first 3 letters + 2 numbers)
      String? pattern;
      if (cleanSku.length >= 5) {
        // Extract first 3 letters
        final letters = cleanSku.substring(0, 3);
        // Find where numbers start
        int numberIndex = -1;
        for (int i = 3; i < cleanSku.length - 1; i++) {
          if (RegExp(r'\d').hasMatch(cleanSku[i]) && 
              RegExp(r'\d').hasMatch(cleanSku[i + 1])) {
            numberIndex = i;
            break;
          }
        }
        
        if (numberIndex > 0 && numberIndex + 2 <= cleanSku.length) {
          final numbers = cleanSku.substring(numberIndex, numberIndex + 2);
          pattern = '$letters$numbers';
          
          AppLogger.debug('Using pattern for matching: $pattern', 
            category: LogCategory.business
          );
          
          // Try pattern match
          for (final file in pdfFiles) {
            final fileName = path.basenameWithoutExtension(file.path).toUpperCase();
            if (fileName.startsWith(pattern)) {
              AppLogger.info('Found pattern match PDF: ${file.path}', 
                category: LogCategory.business
              );
              return file;
            }
          }
        }
      }
      
      // Broad fallback: Check if SKU starts with file name or vice versa
      for (final file in pdfFiles) {
        final fileName = path.basenameWithoutExtension(file.path).toUpperCase();
        
        // Remove common suffixes for matching
        final cleanFileName = fileName
            .replaceAll(RegExp(r'-N\d?$'), '')
            .replaceAll(RegExp(r'_N\d?$'), '');
        final cleanSkuForMatch = cleanSku
            .replaceAll(RegExp(r'-N\d?$'), '')
            .replaceAll(RegExp(r'_N\d?$'), '');
        
        if (cleanFileName == cleanSkuForMatch || 
            cleanFileName.startsWith(cleanSkuForMatch) ||
            cleanSkuForMatch.startsWith(cleanFileName)) {
          AppLogger.info('Found broad match PDF: ${file.path}', 
            category: LogCategory.business
          );
          return file;
        }
      }
      
      AppLogger.warning('No PDF found for SKU: $cleanSku', 
        category: LogCategory.business
      );
      return null;
      
    } catch (e, stackTrace) {
      AppLogger.error('Error finding PDF for SKU: $sku', 
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.business
      );
      return null;
    }
  }
  
  /// Check if a PDF exists for the given SKU
  static Future<bool> hasPdfForSku(String sku) async {
    final file = await findPdfForSku(sku);
    return file != null;
  }
  
  /// Get the file size of a PDF in MB
  static Future<double?> getPdfSizeInMb(File pdfFile) async {
    try {
      final bytes = await pdfFile.length();
      return bytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      AppLogger.error('Error getting PDF size', error: e, category: LogCategory.business);
      return null;
    }
  }
  
  /// Upload PDF to Firebase Storage if needed (for web deployment)
  /// Returns the download URL or null if upload fails
  static Future<String?> uploadPdfToFirebase(File pdfFile, String sku) async {
    try {
      // This would be implemented when needed for web deployment
      // For now, return null as we're using local files
      AppLogger.info('PDF upload to Firebase not yet implemented', 
        category: LogCategory.business
      );
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Error uploading PDF to Firebase', 
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.business
      );
      return null;
    }
  }
}