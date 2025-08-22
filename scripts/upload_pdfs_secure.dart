import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path/path.dart' as path;
// Import Firebase options from the main app
import '../lib/firebase_options.dart';

Future<void> uploadProductPDFs() async {
  print('Initializing Firebase...');
  
  // Initialize Firebase using the app's firebase_options.dart
  // This file should be properly secured and gitignored
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final database = FirebaseDatabase.instance;
  final storage = FirebaseStorage.instance;
  
  // Local PDF directory path
  final localPath = r'O:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\TURBO_VISION_SIMPLIFIED\pdfs';
  final pdfDir = Directory(localPath);
  
  if (!await pdfDir.exists()) {
    print('❌ PDF directory not found: $localPath');
    print('Please ensure the path is correct and accessible.');
    return;
  }
  
  // Get all PDF files
  final pdfFiles = pdfDir.listSync()
    .where((f) => f.path.toLowerCase().endsWith('.pdf'))
    .cast<File>()
    .toList();
  
  if (pdfFiles.isEmpty) {
    print('No PDF files found in directory');
    return;
  }
  
  print('Found ${pdfFiles.length} PDF files to process\n');
  
  // Statistics
  int uploaded = 0;
  int skipped = 0;
  int failed = 0;
  
  for (var pdfFile in pdfFiles) {
    final fileName = path.basename(pdfFile.path);
    final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
    
    // Try to extract SKU from filename
    String sku = fileNameWithoutExt
        .replaceAll(RegExp(r'[-_](manual|spec|datasheet|guide)', caseSensitive: false), '')
        .toUpperCase()
        .trim();
    
    print('Processing: $fileName (SKU: $sku)');
    
    try {
      // Check if product exists in database
      final productQuery = await database.ref('products')
          .orderByChild('sku')
          .equalTo(sku)
          .once();
      
      String? productKey;
      if (productQuery.snapshot.exists) {
        final data = productQuery.snapshot.value as Map;
        productKey = data.keys.first;
      } else {
        // Try to find by model if SKU doesn't match
        final modelQuery = await database.ref('products')
            .orderByChild('model')
            .equalTo(sku)
            .once();
        
        if (modelQuery.snapshot.exists) {
          final data = modelQuery.snapshot.value as Map;
          productKey = data.keys.first;
        }
      }
      
      if (productKey == null) {
        print('  ⚠️ No product found for SKU/Model: $sku - Skipping');
        skipped++;
        continue;
      }
      
      // Upload PDF to Firebase Storage
      final storageRef = storage.ref('pdfs/$sku/$fileName');
      
      // Check if file already exists
      try {
        await storageRef.getDownloadURL();
        print('  ⏭️ PDF already exists in storage - Skipping');
        skipped++;
        continue;
      } catch (e) {
        // File doesn't exist, proceed with upload
      }
      
      print('  ⬆️ Uploading to Firebase Storage...');
      final uploadTask = await storageRef.putFile(pdfFile);
      
      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await storageRef.getDownloadURL();
        
        // Update product with PDF URL
        await database.ref('products/$productKey').update({
          'pdfUrl': downloadUrl,
          'hasPdf': true,
          'pdfFileName': fileName,
        });
        
        print('  ✅ Successfully uploaded and linked to product');
        uploaded++;
      } else {
        print('  ❌ Upload failed');
        failed++;
      }
      
    } catch (e) {
      print('  ❌ Error: $e');
      failed++;
    }
  }
  
  print('\n' + '=' * 50);
  print('Upload Complete!');
  print('Successfully uploaded: $uploaded');
  print('Skipped: $skipped');
  print('Failed: $failed');
  print('Total processed: ${pdfFiles.length}');
  print('=' * 50);
}

void main() async {
  try {
    await uploadProductPDFs();
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}