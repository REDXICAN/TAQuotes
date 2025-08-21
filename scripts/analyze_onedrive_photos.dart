// Script to analyze OneDrive photos and show exact matching
// Run with: dart run scripts/analyze_onedrive_photos.dart

import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  print('========================================');
  print('   OneDrive Photo Analysis');
  print('========================================\n');
  
  // Source directory with product photos
  final sourceDir = Directory('O:\\OneDrive\\Documentos\\-- TurboAir\\4 Gráfico\\Fotos de Equipos');
  
  if (!sourceDir.existsSync()) {
    print('❌ Source directory not found: ${sourceDir.path}');
    print('Please ensure the OneDrive folder is accessible');
    exit(1);
  }
  
  print('📂 Analyzing folders 01 to 12...\n');
  
  final Map<String, List<String>> photosByFolder = {};
  final Map<String, int> skuCounts = {};
  final Set<String> uniqueSkus = {};
  
  // Process folders 01 to 12
  for (int folderNum = 1; folderNum <= 12; folderNum++) {
    final folderName = folderNum.toString().padLeft(2, '0');
    final folderPath = Directory('${sourceDir.path}\\$folderName');
    
    if (!folderPath.existsSync()) {
      continue;
    }
    
    // Get all files in this folder
    final files = folderPath
        .listSync()
        .whereType<File>()
        .map((f) => path.basename(f.path))
        .toList()
      ..sort();
    
    photosByFolder[folderName] = files;
    
    // Extract SKUs
    for (final file in files) {
      if (_isImageFile(file)) {
        final sku = _extractSKU(file);
        if (sku.isNotEmpty) {
          uniqueSkus.add(sku);
          skuCounts[sku] = (skuCounts[sku] ?? 0) + 1;
        }
      }
    }
  }
  
  print('📊 Summary:');
  print('  • Folders with photos: ${photosByFolder.length}');
  print('  • Total unique SKUs found: ${uniqueSkus.length}');
  print('  • Total photo files: ${photosByFolder.values.expand((e) => e).length}\n');
  
  // Show folder contents
  for (final entry in photosByFolder.entries) {
    print('📁 Folder ${entry.key}: ${entry.value.length} files');
    
    // Group by SKU for this folder
    final skusInFolder = <String, List<String>>{};
    for (final file in entry.value) {
      if (_isImageFile(file)) {
        final sku = _extractSKU(file);
        if (sku.isNotEmpty) {
          skusInFolder.putIfAbsent(sku, () => []).add(file);
        }
      }
    }
    
    // Show first few files as examples
    for (final skuEntry in skusInFolder.entries.take(5)) {
      print('  ${skuEntry.key}:');
      for (final file in skuEntry.value) {
        print('    - $file');
      }
    }
    if (skusInFolder.length > 5) {
      print('  ... and ${skusInFolder.length - 5} more SKUs');
    }
    print('');
  }
  
  // List all unique SKUs found
  print('\n📋 All unique SKUs found (${uniqueSkus.length}):');
  final sortedSkus = uniqueSkus.toList()..sort();
  
  // Group SKUs by prefix for better readability
  final skusByPrefix = <String, List<String>>{};
  for (final sku in sortedSkus) {
    final prefix = sku.split('-').first;
    skusByPrefix.putIfAbsent(prefix, () => []).add(sku);
  }
  
  for (final entry in skusByPrefix.entries) {
    print('\n${entry.key} series (${entry.value.length} products):');
    for (final sku in entry.value.take(10)) {
      final count = skuCounts[sku] ?? 0;
      print('  • $sku (${count} photo${count > 1 ? 's' : ''})');
    }
    if (entry.value.length > 10) {
      print('  ... and ${entry.value.length - 10} more');
    }
  }
  
  // Save full list to file
  final listFile = File('scripts/onedrive_photos_list.txt');
  final buffer = StringBuffer();
  
  buffer.writeln('OneDrive Photos Analysis');
  buffer.writeln('Generated: ${DateTime.now()}');
  buffer.writeln('=====================================\n');
  
  for (final entry in photosByFolder.entries) {
    buffer.writeln('Folder ${entry.key}:');
    for (final file in entry.value) {
      buffer.writeln('  $file');
    }
    buffer.writeln('');
  }
  
  buffer.writeln('\nUnique SKUs (${uniqueSkus.length}):');
  for (final sku in sortedSkus) {
    buffer.writeln('  $sku');
  }
  
  listFile.writeAsStringSync(buffer.toString());
  print('\n📝 Full list saved to: scripts/onedrive_photos_list.txt');
  
  print('\n💡 Ready to import!');
  print('Run: dart run scripts/import_product_photos.dart');
}

/// Check if a file is an image
bool _isImageFile(String filePath) {
  final ext = path.extension(filePath).toLowerCase();
  return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
}

/// Extract SKU from filename
String _extractSKU(String fileName) {
  // Remove file extension
  final nameWithoutExt = path.basenameWithoutExtension(fileName);
  
  // Remove page indicators and clean up
  String cleaned = nameWithoutExt
      .replaceAll(RegExp(r'\s*P\.\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*P\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'_P\.\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'_P\d+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(\d+\)$'), '')
      .replaceAll(RegExp(r'\s*-\s*\d+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
      .trim();
  
  // Validate SKU format
  if (cleaned.isEmpty || !RegExp(r'^[A-Z]').hasMatch(cleaned)) {
    return '';
  }
  
  return cleaned;
}