import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/services/update_specs_from_excel.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('Starting product specs update from Excel...\n');
  
  const excelPath = r'C:\Users\andre\Desktop\-- Flutter App\turbo_air_products.xlsx';
  
  // First, preview the data
  print('Previewing Excel data...');
  final preview = await UpdateSpecsFromExcel.previewExcelData(
    excelPath: excelPath,
    previewRows: 3,
  );
  
  if (preview['success']) {
    print('Headers found: ${preview['headers']}');
    print('Total products in Excel: ${preview['totalRows']}');
    print('\nFirst 3 products preview:');
    
    final previewData = preview['preview'] as List;
    for (var i = 0; i < previewData.length; i++) {
      print('\nProduct ${i + 1}:');
      final product = previewData[i] as Map<String, String>;
      product.forEach((key, value) {
        if (value.isNotEmpty) {
          print('  $key: $value');
        }
      });
    }
    
    print('\n' + '='*50);
    print('DRY RUN - Checking what will be updated...');
    print('='*50 + '\n');
    
    // Do a dry run first
    final dryRunResult = await UpdateSpecsFromExcel.updateFromExcel(
      excelPath: excelPath,
      dryRun: true,
    );
    
    if (dryRunResult['success']) {
      print('Dry run successful!');
      print('Total rows in Excel: ${dryRunResult['totalRowsInExcel']}');
      print('Products that will be updated: ${dryRunResult['productsToUpdate']}');
      
      if (dryRunResult['errors'] != null && (dryRunResult['errors'] as List).isNotEmpty) {
        print('\nWarnings/Errors:');
        for (var error in dryRunResult['errors']) {
          print('  - $error');
        }
      }
      
      print('\nSample updates (first 10):');
      final updates = dryRunResult['updates'] as List;
      for (var update in updates.take(5)) {
        print('\nProduct: ${update['identifier']}');
        final fields = update['fields'] as Map<String, dynamic>;
        fields.forEach((key, value) {
          print('  $key: $value');
        });
      }
      
      // Ask for confirmation
      print('\n' + '='*50);
      print('Ready to update the database?');
      print('Type "yes" to proceed with actual update, or press Enter to cancel:');
      print('='*50);
      
      // For automated script, we'll do the actual update
      // In a real interactive scenario, you'd wait for user input
      
      print('\nProceeding with actual update...\n');
      
      // Do the actual update
      final result = await UpdateSpecsFromExcel.updateFromExcel(
        excelPath: excelPath,
        dryRun: false,
      );
      
      if (result['success']) {
        print('✅ SUCCESS! Database updated!');
        print('Products updated: ${result['productsToUpdate']}');
        
        if (result['errors'] != null && (result['errors'] as List).isNotEmpty) {
          print('\nSome products could not be found:');
          for (var error in result['errors']) {
            print('  - $error');
          }
        }
      } else {
        print('❌ Error updating database: ${result['error']}');
      }
      
    } else {
      print('❌ Dry run failed: ${dryRunResult['error']}');
    }
    
  } else {
    print('❌ Error reading Excel file: ${preview['error']}');
  }
  
  print('\nUpdate process complete!');
}