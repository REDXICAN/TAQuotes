// Script to copy product photos from local OneDrive folders
// Run with: dart run scripts/copy_product_photos.dart

import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  print('========================================');
  print('   Product Photo Copy from OneDrive');
  print('========================================\n');
  
  // Source directory with product photos
  final sourceBase = 'O:\\OneDrive\\Documentos\\-- TurboAir\\4 Gráfico\\Fotos de Equipos';
  
  // Folder mappings (01-12)
  final folders = {
    '01': '01_Reach-ins',
    '02': '02_Food prep',
    '03': '03_Undercounter',
    '04': '04_Worktop',
    '05': '05_Glass door',
    '06': '06_Display Case',
    '07': '07_Underbar',
    '08': '08_Chef base',
    '09': '09_Ice cream',
    '10': '10_Milk Cooler',
    '11': '11_Sushi',
    '12': '12_Accessory',
  };
  
  // Target directory for screenshots
  final targetDir = Directory('assets/screenshots');
  
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
    print('✅ Created screenshots directory\n');
  }
  
  int totalPhotosFound = 0;
  int totalPhotosCopied = 0;
  int foldersProcessed = 0;
  final Map<String, List<String>> copiedFiles = {};
  final List<String> errors = [];
  
  print('📂 Processing folders 01 to 12...\n');
  
  for (final entry in folders.entries) {
    final folderNum = entry.key;
    final folderName = entry.value;
    final sourceFolder = Directory('$sourceBase\\$folderName');
    
    if (!sourceFolder.existsSync()) {
      print('⚠️  Folder not found: $folderName');
      continue;
    }
    
    print('📁 [$folderNum] Processing $folderName...');
    foldersProcessed++;
    
    // Get all image files
    final imageFiles = sourceFolder
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => _isImageFile(f.path))
        .toList();
    
    print('   Found ${imageFiles.length} images');
    totalPhotosFound += imageFiles.length;
    
    for (final imageFile in imageFiles) {
      final fileName = path.basename(imageFile.path);
      
      // Extract SKU from filename
      final sku = _extractSKU(fileName);
      
      if (sku.isEmpty) {
        errors.add('Could not extract SKU from: $folderName/$fileName');
        continue;
      }
      
      // Create target folder for this SKU
      final targetFolder = Directory('${targetDir.path}\\$sku');
      if (!targetFolder.existsSync()) {
        targetFolder.createSync();
      }
      
      // Determine target filename with proper naming convention
      final targetFileName = _getTargetFileName(sku, fileName);
      final targetFile = File('${targetFolder.path}\\$targetFileName');
      
      try {
        // Copy the file
        await imageFile.copy(targetFile.path);
        totalPhotosCopied++;
        
        // Track what was copied
        copiedFiles.putIfAbsent(sku, () => []).add(targetFileName);
        
        // Show progress every 100 files
        if (totalPhotosCopied % 100 == 0) {
          print('   Progress: $totalPhotosCopied files copied...');
        }
        
      } catch (e) {
        errors.add('Failed to copy $fileName: $e');
      }
    }
  }
  
  print('\n========================================');
  print('           Copy Complete!');
  print('========================================\n');
  
  print('📊 Summary:');
  print('  • Folders processed: $foldersProcessed');
  print('  • Total photos found: $totalPhotosFound');
  print('  • Photos copied: $totalPhotosCopied');
  print('  • Unique products: ${copiedFiles.length}');
  
  // Show some examples of what was copied
  print('\n📸 Sample products with photos:');
  final samples = copiedFiles.keys.take(10).toList();
  for (final sku in samples) {
    final files = copiedFiles[sku]!;
    print('  • $sku: ${files.length} photo${files.length > 1 ? 's' : ''}');
  }
  if (copiedFiles.length > 10) {
    print('  ... and ${copiedFiles.length - 10} more products');
  }
  
  if (errors.isNotEmpty) {
    print('\n⚠️  Errors (${errors.length}):');
    for (final error in errors.take(5)) {
      print('  - $error');
    }
    if (errors.length > 5) {
      print('  ... and ${errors.length - 5} more errors');
    }
  }
  
  // Save report
  final reportFile = File('scripts/photo_copy_report.txt');
  final buffer = StringBuffer();
  
  buffer.writeln('Product Photo Copy Report');
  buffer.writeln('Generated: ${DateTime.now()}');
  buffer.writeln('=====================================\n');
  
  buffer.writeln('Summary:');
  buffer.writeln('  Folders processed: $foldersProcessed');
  buffer.writeln('  Total photos found: $totalPhotosFound');
  buffer.writeln('  Photos copied: $totalPhotosCopied');
  buffer.writeln('  Unique products: ${copiedFiles.length}\n');
  
  buffer.writeln('Products with photos:');
  final sortedSkus = copiedFiles.keys.toList()..sort();
  for (final sku in sortedSkus) {
    buffer.writeln('$sku: ${copiedFiles[sku]!.join(', ')}');
  }
  
  if (errors.isNotEmpty) {
    buffer.writeln('\nErrors:');
    for (final error in errors) {
      buffer.writeln('  $error');
    }
  }
  
  reportFile.writeAsStringSync(buffer.toString());
  print('\n📝 Detailed report saved to: scripts/photo_copy_report.txt');
  
  print('\n✅ Next steps:');
  print('  1. Run thumbnail generation: dart run scripts/generate_optimized_thumbnails.dart');
  print('  2. Run: flutter pub get');
  print('  3. Test the app with new images');
}

bool _isImageFile(String filePath) {
  final ext = path.extension(filePath).toLowerCase();
  return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
}

String _extractSKU(String fileName) {
  // Remove file extension
  final nameWithoutExt = path.basenameWithoutExtension(fileName);
  
  // Clean up the name
  String cleaned = nameWithoutExt
      .replaceAll(RegExp(r'\s*P\.\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*P\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'_P\.\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'_P\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(\d+\)$'), '')
      .replaceAll(RegExp(r'\s*-\s*\d+$'), '')
      .trim();
  
  // Validate SKU format
  if (cleaned.isEmpty || !RegExp(r'^[A-Z]').hasMatch(cleaned)) {
    return '';
  }
  
  return cleaned;
}

String _getTargetFileName(String sku, String originalFileName) {
  final lowerName = originalFileName.toLowerCase();
  
  // Determine page number
  String pageNum = '1';
  if (lowerName.contains('p.2') || lowerName.contains('p2')) {
    pageNum = '2';
  } else if (lowerName.contains('p.3') || lowerName.contains('p3')) {
    pageNum = '3';
  } else if (lowerName.contains('p.4') || lowerName.contains('p4')) {
    pageNum = '4';
  } else if (lowerName.contains('p.5') || lowerName.contains('p5')) {
    pageNum = '5';
  }
  
  // Return standard naming: "SKU P.1.png"
  return '$sku P.$pageNum.png';
}