import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Checking product images for all 835 products...\n');
  
  // Get all products from Firebase
  final database = FirebaseDatabase.instance;
  final snapshot = await database.ref('products').get();
  
  if (!snapshot.exists || snapshot.value == null) {
    print('No products found in database');
    return;
  }
  
  final productsData = Map<String, dynamic>.from(snapshot.value as Map);
  print('Found ${productsData.length} products in database\n');
  
  // Check local directories
  final screenshotsDir = Directory('assets/screenshots');
  final thumbnailsDir = Directory('assets/thumbnails');
  
  // Get all screenshot directories
  final screenshotFolders = screenshotsDir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(Platform.pathSeparator).last)
      .toSet();
  
  // Get all thumbnail directories
  final thumbnailFolders = thumbnailsDir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(Platform.pathSeparator).last)
      .toSet();
  
  print('Screenshot folders: ${screenshotFolders.length}');
  print('Thumbnail folders: ${thumbnailFolders.length}\n');
  
  // Track statistics
  int hasScreenshot = 0;
  int hasThumbnail = 0;
  int hasBoth = 0;
  int hasNeither = 0;
  List<String> missingScreenshots = [];
  List<String> missingThumbnails = [];
  List<String> missingBoth = [];
  
  // Check each product
  productsData.forEach((key, value) {
    final productData = Map<String, dynamic>.from(value);
    final sku = productData['sku'] ?? productData['model'] ?? key;
    
    bool hasScreenshotFolder = false;
    bool hasThumbnailFolder = false;
    
    // Check for exact match
    if (screenshotFolders.contains(sku)) {
      hasScreenshotFolder = true;
    } else {
      // Check for variations (with _Left, _Right, etc)
      hasScreenshotFolder = screenshotFolders.any((folder) => 
        folder.startsWith(sku) || folder == sku.replaceAll(' ', '_'));
    }
    
    if (thumbnailFolders.contains(sku)) {
      hasThumbnailFolder = true;
    } else {
      // Check for variations
      hasThumbnailFolder = thumbnailFolders.any((folder) => 
        folder.startsWith(sku) || folder == sku.replaceAll(' ', '_'));
    }
    
    // Update statistics
    if (hasScreenshotFolder && hasThumbnailFolder) {
      hasBoth++;
    } else if (hasScreenshotFolder && !hasThumbnailFolder) {
      hasScreenshot++;
      missingThumbnails.add(sku);
    } else if (!hasScreenshotFolder && hasThumbnailFolder) {
      hasThumbnail++;
      missingScreenshots.add(sku);
    } else {
      hasNeither++;
      missingBoth.add(sku);
    }
  });
  
  // Print results
  print('=== RESULTS ===\n');
  print('Products with both screenshot and thumbnail: $hasBoth');
  print('Products with only screenshot: $hasScreenshot');
  print('Products with only thumbnail: $hasThumbnail');
  print('Products with neither: $hasNeither');
  print('Total products: ${productsData.length}\n');
  
  // Show missing thumbnails (first 20)
  if (missingThumbnails.isNotEmpty) {
    print('\n=== MISSING THUMBNAILS (${missingThumbnails.length} total) ===');
    missingThumbnails.take(20).forEach((sku) {
      print('  - $sku');
    });
    if (missingThumbnails.length > 20) {
      print('  ... and ${missingThumbnails.length - 20} more');
    }
  }
  
  // Show missing screenshots (first 20)
  if (missingScreenshots.isNotEmpty) {
    print('\n=== MISSING SCREENSHOTS (${missingScreenshots.length} total) ===');
    missingScreenshots.take(20).forEach((sku) {
      print('  - $sku');
    });
    if (missingScreenshots.length > 20) {
      print('  ... and ${missingScreenshots.length - 20} more');
    }
  }
  
  // Show missing both (first 20)
  if (missingBoth.isNotEmpty) {
    print('\n=== MISSING BOTH (${missingBoth.length} total) ===');
    missingBoth.take(20).forEach((sku) {
      print('  - $sku');
    });
    if (missingBoth.length > 20) {
      print('  ... and ${missingBoth.length - 20} more');
    }
  }
  
  // Check for orphaned folders (folders without products)
  print('\n=== ORPHANED FOLDERS ===');
  
  final productSkus = productsData.values
      .map((v) => (v as Map)['sku'] ?? (v as Map)['model'] ?? '')
      .where((s) => s.toString().isNotEmpty)
      .toSet();
  
  final orphanedScreenshots = screenshotFolders.where((folder) => 
    !productSkus.any((sku) => folder.startsWith(sku.toString()))).toList();
  
  final orphanedThumbnails = thumbnailFolders.where((folder) => 
    !productSkus.any((sku) => folder.startsWith(sku.toString()))).toList();
  
  if (orphanedScreenshots.isNotEmpty) {
    print('\nOrphaned screenshot folders (${orphanedScreenshots.length}):');
    orphanedScreenshots.take(10).forEach((folder) {
      print('  - $folder');
    });
    if (orphanedScreenshots.length > 10) {
      print('  ... and ${orphanedScreenshots.length - 10} more');
    }
  }
  
  if (orphanedThumbnails.isNotEmpty) {
    print('\nOrphaned thumbnail folders (${orphanedThumbnails.length}):');
    orphanedThumbnails.take(10).forEach((folder) {
      print('  - $folder');
    });
    if (orphanedThumbnails.length > 10) {
      print('  ... and ${orphanedThumbnails.length - 10} more');
    }
  }
  
  print('\n=== SUMMARY ===');
  print('Coverage: ${((hasBoth / productsData.length) * 100).toStringAsFixed(1)}% have both images');
  print('Screenshots coverage: ${(((hasBoth + hasScreenshot) / productsData.length) * 100).toStringAsFixed(1)}%');
  print('Thumbnails coverage: ${(((hasBoth + hasThumbnail) / productsData.length) * 100).toStringAsFixed(1)}%');
  
  exit(0);
}