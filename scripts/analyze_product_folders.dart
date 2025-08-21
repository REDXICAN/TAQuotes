// Script to analyze product folders with smart SKU matching
// Run with: dart run scripts/analyze_product_folders.dart

import 'dart:io';

void main() async {
  print('========================================');
  print('   Smart Product Folder Analysis');
  print('========================================\n');
  
  // List of all 835 products from database (you mentioned there are 835)
  // This should be loaded from Firebase, but for now using a comprehensive set
  final validSkuPatterns = <String>{};
  
  // Read the screenshots directory
  final screenshotsDir = Directory('assets/screenshots');
  if (!screenshotsDir.existsSync()) {
    print('❌ Screenshots directory not found!');
    exit(1);
  }
  
  final allFolders = screenshotsDir
      .listSync()
      .whereType<Directory>()
      .map((dir) => dir.path.split(Platform.pathSeparator).last)
      .toList();
  
  print('Found ${allFolders.length} folders in screenshots directory\n');
  
  // Extract base patterns from folder names (first 3 letters + first 2 numbers)
  final folderPatterns = <String, List<String>>{};
  
  for (final folder in allFolders) {
    final basePattern = extractBasePattern(folder);
    if (basePattern.isNotEmpty) {
      folderPatterns.putIfAbsent(basePattern, () => []).add(folder);
    }
  }
  
  print('📊 Folder Analysis:');
  print('  • Total folders: ${allFolders.length}');
  print('  • Unique base patterns: ${folderPatterns.length}');
  print('  • Average variations per pattern: ${(allFolders.length / folderPatterns.length).toStringAsFixed(1)}');
  
  // Find patterns with most variations
  final sortedPatterns = folderPatterns.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  
  print('\n🔍 Top patterns with most variations:');
  for (final entry in sortedPatterns.take(20)) {
    print('  • ${entry.key}: ${entry.value.length} variations');
    if (entry.value.length <= 5) {
      for (final folder in entry.value) {
        print('      - $folder');
      }
    } else {
      // Show first 3 and last 2
      for (final folder in entry.value.take(3)) {
        print('      - $folder');
      }
      print('      ... ${entry.value.length - 5} more ...');
      for (final folder in entry.value.skip(entry.value.length - 2)) {
        print('      - $folder');
      }
    }
  }
  
  // Group by product lines
  final productLines = <String, int>{};
  for (final folder in allFolders) {
    final line = folder.split('-').first;
    productLines[line] = (productLines[line] ?? 0) + 1;
  }
  
  print('\n📦 Product lines:');
  final sortedLines = productLines.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  for (final entry in sortedLines.take(30)) {
    print('  • ${entry.key}: ${entry.value} products');
  }
  
  // Estimate actual unique products
  print('\n💡 Estimation:');
  print('  • Based on folder patterns, you likely have ~${folderPatterns.length} unique product models');
  print('  • The ${allFolders.length} folders include variations (different sizes, configurations)');
  print('  • If database has 835 products, ~${allFolders.length - 835} folders might be unused variations');
  
  // Save folder list for reference
  final outputFile = File('scripts/all_screenshot_folders.txt');
  outputFile.writeAsStringSync(allFolders.join('\n'));
  print('\n📝 All folder names saved to: scripts/all_screenshot_folders.txt');
  
  // Save pattern analysis
  final patternFile = File('scripts/folder_patterns.txt');
  final patternContent = folderPatterns.entries
      .map((e) => '${e.key}: ${e.value.join(", ")}')
      .join('\n');
  patternFile.writeAsStringSync(patternContent);
  print('📝 Pattern analysis saved to: scripts/folder_patterns.txt');
}

/// Extract base pattern from SKU (first 3 letters + first 2 numbers)
/// Examples:
/// - "TSR-23SD-N6" -> "TSR-23"
/// - "PRO-12R-N" -> "PRO-12"
/// - "M3R24-1-N" -> "M3R-24"
String extractBasePattern(String sku) {
  // Handle special cases first
  if (sku.isEmpty) return '';
  
  // Extract letters at the beginning
  final letterMatch = RegExp(r'^([A-Z]+)').firstMatch(sku);
  if (letterMatch == null) return '';
  
  final letters = letterMatch.group(1)!;
  
  // Look for numbers after letters (with or without dash)
  final remaining = sku.substring(letters.length);
  final numberMatch = RegExp(r'[-]?(\d+)').firstMatch(remaining);
  
  if (numberMatch == null) return letters;
  
  final numbers = numberMatch.group(1)!;
  
  // Take first 3 letters and first 2 digits
  final baseLetters = letters.length > 3 ? letters.substring(0, 3) : letters;
  final baseNumbers = numbers.length > 2 ? numbers.substring(0, 2) : numbers;
  
  return '$baseLetters-$baseNumbers';
}