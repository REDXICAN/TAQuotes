import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  print('Analyzing product images...\n');
  
  // Get all products from database
  final database = FirebaseDatabase.instance;
  final snapshot = await database.ref('products').get();
  
  Set<String> databaseSKUs = {};
  
  if (snapshot.exists && snapshot.value != null) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    data.forEach((key, value) {
      final product = Map<String, dynamic>.from(value);
      final sku = product['sku'] ?? product['model'] ?? '';
      if (sku.isNotEmpty) {
        databaseSKUs.add(sku.toString().toUpperCase());
      }
    });
  }
  
  print('Found ${databaseSKUs.length} products in database\n');
  
  // Get all image folders
  final screenshotsDir = Directory('assets/screenshots');
  final imageFolders = screenshotsDir.listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(Platform.pathSeparator).last.toUpperCase())
      .toSet();
  
  print('Found ${imageFolders.length} image folders\n');
  
  // Find unused folders
  final unusedFolders = imageFolders.difference(databaseSKUs);
  final missingImages = databaseSKUs.difference(imageFolders);
  
  print('Unused image folders (${unusedFolders.length}):');
  for (final folder in unusedFolders.take(50)) {
    print('  - $folder');
  }
  if (unusedFolders.length > 50) {
    print('  ... and ${unusedFolders.length - 50} more');
  }
  
  print('\nProducts without images (${missingImages.length}):');
  for (final sku in missingImages.take(50)) {
    print('  - $sku');
  }
  if (missingImages.length > 50) {
    print('  ... and ${missingImages.length - 50} more');
  }
  
  // Calculate sizes
  int totalSize = 0;
  int unusedSize = 0;
  
  for (final folder in Directory('assets/screenshots').listSync().whereType<Directory>()) {
    final folderName = folder.path.split(Platform.pathSeparator).last.toUpperCase();
    int folderSize = 0;
    
    for (final file in folder.listSync().whereType<File>()) {
      folderSize += file.lengthSync();
    }
    
    totalSize += folderSize;
    if (unusedFolders.contains(folderName)) {
      unusedSize += folderSize;
    }
  }
  
  print('\n--- Summary ---');
  print('Total image size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
  print('Unused image size: ${(unusedSize / 1024 / 1024).toStringAsFixed(2)} MB');
  print('Potential savings: ${(unusedSize / 1024 / 1024).toStringAsFixed(2)} MB');
  
  // Write results to file
  final outputFile = File('image_analysis_results.txt');
  final buffer = StringBuffer();
  
  buffer.writeln('Image Analysis Results');
  buffer.writeln('======================');
  buffer.writeln('Database products: ${databaseSKUs.length}');
  buffer.writeln('Image folders: ${imageFolders.length}');
  buffer.writeln('Unused folders: ${unusedFolders.length}');
  buffer.writeln('Missing images: ${missingImages.length}');
  buffer.writeln('Total size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
  buffer.writeln('Unused size: ${(unusedSize / 1024 / 1024).toStringAsFixed(2)} MB');
  buffer.writeln('\nUnused folders to delete:');
  
  for (final folder in unusedFolders) {
    buffer.writeln(folder);
  }
  
  await outputFile.writeAsString(buffer.toString());
  print('\nResults written to image_analysis_results.txt');
}