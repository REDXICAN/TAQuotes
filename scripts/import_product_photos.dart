// Script to import product photos from OneDrive and match them to the correct folders
// Run with: dart run scripts/import_product_photos.dart

import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  print('========================================');
  print('   Product Photo Import & Matching');
  print('========================================\n');
  
  // Source directory with product photos
  final sourceDir = Directory('O:\\OneDrive\\Documentos\\-- TurboAir\\4 Gráfico\\Fotos de Equipos');
  
  // Target directory for screenshots
  final targetDir = Directory('assets/screenshots');
  
  if (!sourceDir.existsSync()) {
    print('❌ Source directory not found: ${sourceDir.path}');
    print('Please ensure the OneDrive folder is accessible');
    exit(1);
  }
  
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
    print('✅ Created screenshots directory\n');
  }
  
  print('📂 Scanning source folders 01 to 12...\n');
  
  int totalPhotosFound = 0;
  int totalPhotosMatched = 0;
  int totalPhotosCopied = 0;
  final Map<String, List<String>> matchResults = {};
  final List<String> unmatchedPhotos = [];
  
  // Process folders 01 to 12
  for (int folderNum = 1; folderNum <= 12; folderNum++) {
    final folderName = folderNum.toString().padLeft(2, '0');
    final folderPath = Directory('${sourceDir.path}\\$folderName');
    
    if (!folderPath.existsSync()) {
      print('⚠️  Folder $folderName not found, skipping...');
      continue;
    }
    
    print('📁 Processing folder $folderName...');
    
    // Get all image files in this folder
    final imageFiles = folderPath
        .listSync()
        .whereType<File>()
        .where((f) => _isImageFile(f.path))
        .toList();
    
    print('   Found ${imageFiles.length} images');
    totalPhotosFound += imageFiles.length;
    
    for (final imageFile in imageFiles) {
      final fileName = path.basename(imageFile.path);
      
      // Extract SKU from filename
      // Expected formats: "SKU.jpg", "SKU P.1.png", "SKU_P.1.jpg", etc.
      final sku = _extractSKU(fileName);
      
      if (sku.isEmpty) {
        unmatchedPhotos.add('$folderName/$fileName');
        continue;
      }
      
      // Find or create the target folder
      final targetFolder = Directory('${targetDir.path}\\$sku');
      
      // Create folder if it doesn't exist
      if (!targetFolder.existsSync()) {
        targetFolder.createSync();
      }
      
      // Determine the target filename
      String targetFileName;
      if (fileName.contains('P.1') || fileName.contains('P1')) {
        targetFileName = '$sku P.1.png';
      } else if (fileName.contains('P.2') || fileName.contains('P2')) {
        targetFileName = '$sku P.2.png';
      } else if (fileName.contains('P.3') || fileName.contains('P3')) {
        targetFileName = '$sku P.3.png';
      } else if (fileName.contains('P.4') || fileName.contains('P4')) {
        targetFileName = '$sku P.4.png';
      } else if (fileName.contains('P.5') || fileName.contains('P5')) {
        targetFileName = '$sku P.5.png';
      } else {
        // Default to P.1 if no page number is specified
        targetFileName = '$sku P.1.png';
      }
      
      final targetFile = File('${targetFolder.path}\\$targetFileName');
      
      try {
        // Copy the file
        await imageFile.copy(targetFile.path);
        totalPhotosCopied++;
        
        // Track the match
        matchResults.putIfAbsent(sku, () => []).add('$folderName/$fileName → $sku/$targetFileName');
        totalPhotosMatched++;
        
      } catch (e) {
        print('   ❌ Failed to copy $fileName: $e');
      }
    }
  }
  
  print('\n========================================');
  print('           Import Complete!');
  print('========================================\n');
  
  print('📊 Statistics:');
  print('  • Total photos found: $totalPhotosFound');
  print('  • Photos matched: $totalPhotosMatched');
  print('  • Photos copied: $totalPhotosCopied');
  print('  • Unique products: ${matchResults.length}');
  
  if (unmatchedPhotos.isNotEmpty) {
    print('\n⚠️  Unmatched photos (${unmatchedPhotos.length}):');
    for (final photo in unmatchedPhotos.take(10)) {
      print('  - $photo');
    }
    if (unmatchedPhotos.length > 10) {
      print('  ... and ${unmatchedPhotos.length - 10} more');
    }
  }
  
  // Save match results to file
  final reportFile = File('scripts/photo_import_report.txt');
  final buffer = StringBuffer();
  
  buffer.writeln('Product Photo Import Report');
  buffer.writeln('Generated: ${DateTime.now()}');
  buffer.writeln('=====================================\n');
  
  buffer.writeln('Summary:');
  buffer.writeln('  Total photos found: $totalPhotosFound');
  buffer.writeln('  Photos matched: $totalPhotosMatched');
  buffer.writeln('  Photos copied: $totalPhotosCopied');
  buffer.writeln('  Unique products: ${matchResults.length}\n');
  
  buffer.writeln('Matched Products:');
  final sortedSkus = matchResults.keys.toList()..sort();
  for (final sku in sortedSkus) {
    buffer.writeln('\n$sku:');
    for (final match in matchResults[sku]!) {
      buffer.writeln('  $match');
    }
  }
  
  if (unmatchedPhotos.isNotEmpty) {
    buffer.writeln('\nUnmatched Photos:');
    for (final photo in unmatchedPhotos) {
      buffer.writeln('  $photo');
    }
  }
  
  reportFile.writeAsStringSync(buffer.toString());
  print('\n📝 Detailed report saved to: scripts/photo_import_report.txt');
  
  print('\n✅ Next steps:');
  print('  1. Run thumbnail generation script');
  print('  2. Run "flutter pub get"');
  print('  3. Test the app with new images');
}

/// Check if a file is an image
bool _isImageFile(String filePath) {
  final ext = path.extension(filePath).toLowerCase();
  return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
}

/// Extract SKU from filename
/// Handles various naming patterns
String _extractSKU(String fileName) {
  // Remove file extension
  final nameWithoutExt = path.basenameWithoutExtension(fileName);
  
  // Remove common suffixes like P.1, P.2, etc.
  String cleaned = nameWithoutExt
      .replaceAll(RegExp(r'\s*P\.\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*P\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'_P\.\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'_P\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(\d+\)$'), '') // Remove (1), (2), etc.
      .replaceAll(RegExp(r'\s*-\s*\d+$'), '') // Remove -1, -2, etc.
      .trim();
  
  // Validate that this looks like a SKU
  // SKUs typically start with letters and contain hyphens
  if (cleaned.isEmpty || !RegExp(r'^[A-Z]').hasMatch(cleaned)) {
    return '';
  }
  
  return cleaned;
}