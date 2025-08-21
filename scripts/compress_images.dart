// Dart script to compress images using Flutter's image package
// Run with: dart run scripts/compress_images.dart

import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

void main() async {
  print('==========================================');
  print('     Product Image Compression Tool');
  print('==========================================\n');

  final sourceDir = Directory('assets/screenshots');
  final thumbnailDir = Directory('assets/thumbnails');
  
  // Configuration
  const int maxWidth = 600;
  const int maxHeight = 600;
  const int jpegQuality = 85;
  const bool createDetailImages = true; // Also create compressed detail images
  
  if (!sourceDir.existsSync()) {
    print('❌ Source directory not found: ${sourceDir.path}');
    exit(1);
  }
  
  // Create thumbnails directory
  if (!thumbnailDir.existsSync()) {
    thumbnailDir.createSync(recursive: true);
    print('✅ Created thumbnails directory\n');
  }
  
  // Get all product folders
  final productFolders = sourceDir
      .listSync()
      .whereType<Directory>()
      .toList();
  
  print('Found ${productFolders.length} product folders to process\n');
  
  int processed = 0;
  int errors = 0;
  int totalOriginalSize = 0;
  int totalCompressedSize = 0;
  
  for (final folder in productFolders) {
    final sku = path.basename(folder.path);
    processed++;
    
    // Create SKU folder in thumbnails
    final thumbFolder = Directory('${thumbnailDir.path}/$sku');
    if (!thumbFolder.existsSync()) {
      thumbFolder.createSync();
    }
    
    // Progress indicator
    final progress = (processed / productFolders.length * 100).toStringAsFixed(1);
    stdout.write('\rProcessing: $sku [$progress%] ');
    
    // Process images in this folder
    final images = folder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png') || f.path.endsWith('.jpg'))
        .toList();
    
    for (final imageFile in images) {
      try {
        final originalSize = imageFile.lengthSync();
        totalOriginalSize += originalSize;
        
        // Read image
        final bytes = imageFile.readAsBytesSync();
        final image = img.decodeImage(bytes);
        
        if (image == null) continue;
        
        // Determine output filename
        final imageName = path.basename(imageFile.path);
        final isThumbnail = imageName.contains('P.1');
        
        if (isThumbnail || createDetailImages) {
          // Resize image maintaining aspect ratio
          img.Image resized;
          if (image.width > maxWidth || image.height > maxHeight) {
            if (image.width > image.height) {
              resized = img.copyResize(image, width: maxWidth);
            } else {
              resized = img.copyResize(image, height: maxHeight);
            }
          } else {
            resized = image;
          }
          
          // Apply slight sharpening for better quality after resize
          resized = img.adjustColor(resized, contrast: 1.1);
          
          // Save as JPEG with compression
          final outputName = imageName.replaceAll('.png', '.jpg');
          final outputPath = '${thumbFolder.path}/$outputName';
          
          // For main thumbnail, also save a simple "SKU.jpg" version
          if (isThumbnail) {
            final thumbPath = '${thumbFolder.path}/$sku.jpg';
            File(thumbPath).writeAsBytesSync(
              img.encodeJpg(resized, quality: jpegQuality)
            );
          }
          
          // Save the regular compressed version
          final compressedBytes = img.encodeJpg(resized, quality: jpegQuality);
          File(outputPath).writeAsBytesSync(compressedBytes);
          
          totalCompressedSize += compressedBytes.length;
        }
      } catch (e) {
        errors++;
        // Silent error handling to not clutter output
      }
    }
  }
  
  print('\n\n==========================================');
  print('           Compression Complete!');
  print('==========================================\n');
  
  // Calculate results
  final originalMB = (totalOriginalSize / 1024 / 1024).toStringAsFixed(2);
  final compressedMB = (totalCompressedSize / 1024 / 1024).toStringAsFixed(2);
  final savedMB = ((totalOriginalSize - totalCompressedSize) / 1024 / 1024).toStringAsFixed(2);
  final reduction = totalOriginalSize > 0 
      ? ((1 - (totalCompressedSize / totalOriginalSize)) * 100).toStringAsFixed(1)
      : '0';
  
  print('📊 Results:');
  print('  • Processed: $processed folders');
  print('  • Errors: $errors');
  print('  • Original size: $originalMB MB');
  print('  • Compressed size: $compressedMB MB');
  print('  • Space saved: $savedMB MB ($reduction% reduction)\n');
  
  print('✅ Thumbnails created in: ${thumbnailDir.path}\n');
  
  print('Next steps:');
  print('  1. Update pubspec.yaml to include new thumbnails folder');
  print('  2. Run "flutter pub get" to update assets');
  print('  3. Update image helpers to use compressed thumbnails\n');
}