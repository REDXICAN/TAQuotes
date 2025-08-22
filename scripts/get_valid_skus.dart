// Script to get all valid SKUs from Firebase and identify truly unused folders
// Run with: dart run scripts/get_valid_skus.dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:turbo_air_quotes/firebase_options.dart';

void main() async {
  print('========================================');
  print('   Getting Valid SKUs from Database');
  print('========================================\n');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  try {
    // Get all products from database
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('products').get();
    
    if (!snapshot.exists) {
      print('❌ No products found in database!');
      exit(1);
    }
    
    final products = snapshot.value as Map<dynamic, dynamic>;
    final validSkus = <String>{};
    
    // Extract all SKUs
    products.forEach((key, value) {
      if (value is Map) {
        final sku = value['sku'] as String?;
        final model = value['model'] as String?;
        
        if (sku != null && sku.isNotEmpty) {
          validSkus.add(sku.trim());
        } else if (model != null && model.isNotEmpty) {
          validSkus.add(model.trim());
        }
      }
    });
    
    print('Found ${validSkus.length} products in database\n');
    
    // Now check screenshots folder
    final screenshotsDir = Directory('assets/screenshots');
    if (!screenshotsDir.existsSync()) {
      print('❌ Screenshots directory not found!');
      exit(1);
    }
    
    final allFolders = screenshotsDir
        .listSync()
        .whereType<Directory>()
        .toList();
    
    print('Found ${allFolders.length} folders in screenshots directory\n');
    
    // Find truly unused folders
    final unusedFolders = <String>[];
    final usedFolders = <String>[];
    final missingInScreenshots = <String>[];
    
    // Check which folders are actually unused
    for (final folder in allFolders) {
      final folderName = folder.path.split(Platform.pathSeparator).last;
      
      if (validSkus.contains(folderName)) {
        usedFolders.add(folderName);
      } else {
        unusedFolders.add(folderName);
      }
    }
    
    // Check which products don't have screenshot folders
    for (final sku in validSkus) {
      final folderPath = Directory('assets/screenshots/$sku');
      if (!folderPath.existsSync()) {
        missingInScreenshots.add(sku);
      }
    }
    
    print('========================================');
    print('           Analysis Results');
    print('========================================');
    print('📊 Database:');
    print('  • Total products: ${validSkus.length}');
    print('\n📁 Screenshots folder:');
    print('  • Total folders: ${allFolders.length}');
    print('  • Used folders: ${usedFolders.length}');
    print('  • Unused folders: ${unusedFolders.length}');
    print('\n⚠️  Products without screenshots: ${missingInScreenshots.length}');
    
    if (missingInScreenshots.isNotEmpty) {
      print('\nProducts missing screenshots:');
      for (final sku in missingInScreenshots.take(20)) {
        print('  - $sku');
      }
      if (missingInScreenshots.length > 20) {
        print('  ... and ${missingInScreenshots.length - 20} more');
      }
    }
    
    if (unusedFolders.isNotEmpty) {
      print('\n🗑️  Truly unused folders (${unusedFolders.length}):');
      for (final folder in unusedFolders.take(20)) {
        print('  - $folder');
      }
      if (unusedFolders.length > 20) {
        print('  ... and ${unusedFolders.length - 20} more');
      }
      
      // Calculate size of unused folders
      int totalSize = 0;
      for (final folderName in unusedFolders) {
        final folder = Directory('assets/screenshots/$folderName');
        if (folder.existsSync()) {
          await for (final entity in folder.list(recursive: true)) {
            if (entity is File) {
              totalSize += await entity.length();
            }
          }
        }
      }
      
      print('\n💾 Storage used by unused folders: ${_formatBytes(totalSize)}');
    } else {
      print('\n✅ All folders are being used by products in the database!');
    }
    
    // Save the valid SKUs to a file for reference
    final outputFile = File('scripts/valid_skus.txt');
    outputFile.writeAsStringSync(validSkus.join('\n'));
    print('\n📝 Valid SKUs saved to: scripts/valid_skus.txt');
    
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
  
  exit(0);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}