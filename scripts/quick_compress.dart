// Quick thumbnail generator - creates compressed thumbnails from screenshots
// Run with: dart run scripts/quick_compress.dart

import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  print('========================================');
  print('   Quick Thumbnail Generator');
  print('========================================\n');
  
  final screenshotsDir = Directory('assets/screenshots');
  final thumbnailsDir = Directory('assets/thumbnails');
  
  if (!screenshotsDir.existsSync()) {
    print('❌ Screenshots directory not found!');
    exit(1);
  }
  
  // Create thumbnails directory
  if (!thumbnailsDir.existsSync()) {
    thumbnailsDir.createSync(recursive: true);
    print('✅ Created thumbnails directory\n');
  }
  
  // Get all SKU folders
  final folders = screenshotsDir
      .listSync()
      .whereType<Directory>()
      .toList();
  
  print('Found ${folders.length} product folders\n');
  print('Processing (this may take a few minutes)...\n');
  
  int processed = 0;
  int failed = 0;
  
  for (final folder in folders) {
    final sku = folder.path.split(Platform.pathSeparator).last;
    
    // Look for the first image (P.1.png)
    final sourceImage = File('${folder.path}/$sku P.1.png');
    
    if (!sourceImage.existsSync()) {
      // Try alternative naming patterns
      final alternatives = [
        File('${folder.path}/P.1.png'),
        File('${folder.path}/${sku}_P.1.png'),
        File('${folder.path}/$sku.png'),
      ];
      
      bool found = false;
      for (final alt in alternatives) {
        if (alt.existsSync()) {
          sourceImage.path;
          found = true;
          break;
        }
      }
      
      if (!found) {
        // Just use any PNG in the folder
        final anyImage = folder
            .listSync()
            .whereType<File>()
            .firstWhere(
              (f) => f.path.endsWith('.png'),
              orElse: () => File(''),
            );
        
        if (!anyImage.existsSync()) {
          failed++;
          continue;
        }
      }
    }
    
    try {
      // Read and compress image
      final bytes = sourceImage.readAsBytesSync();
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        // Resize to max 600x600 maintaining aspect ratio
        img.Image resized;
        if (image.width > 600 || image.height > 600) {
          if (image.width > image.height) {
            resized = img.copyResize(image, width: 600);
          } else {
            resized = img.copyResize(image, height: 600);
          }
        } else {
          resized = image;
        }
        
        // Create SKU folder in thumbnails
        final thumbDir = Directory('${thumbnailsDir.path}/$sku');
        if (!thumbDir.existsSync()) {
          thumbDir.createSync();
        }
        
        // Save as compressed JPEG
        final jpegBytes = img.encodeJpg(resized, quality: 85);
        final outputFile = File('${thumbDir.path}/$sku.jpg');
        outputFile.writeAsBytesSync(jpegBytes);
        
        processed++;
        
        // Show progress every 50 items
        if (processed % 50 == 0) {
          print('  ✓ Processed $processed folders...');
        }
      }
    } catch (e) {
      failed++;
      print('  ✗ Failed to process $sku: $e');
    }
  }
  
  print('\n========================================');
  print('           Complete!');
  print('========================================');
  print('✅ Successfully processed: $processed folders');
  if (failed > 0) {
    print('❌ Failed: $failed folders');
  }
  print('\nThumbnails saved in: assets/thumbnails/');
  print('\nNext steps:');
  print('1. Run "flutter pub get" to refresh assets');
  print('2. Restart your app to see the changes');
}