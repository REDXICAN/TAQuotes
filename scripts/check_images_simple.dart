import 'dart:io';
import 'dart:convert';

void main() async {
  print('Checking product images for all products...\n');
  
  // Get products from Firebase via REST API
  final client = HttpClient();
  final request = await client.getUrl(
    Uri.parse('https://taquotes-default-rtdb.firebaseio.com/products.json'),
  );
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  final productsData = json.decode(responseBody) as Map<String, dynamic>;
  
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
  int hasBoth = 0;
  int hasOnlyScreenshot = 0;
  int hasOnlyThumbnail = 0;
  int hasNeither = 0;
  List<String> missingThumbnails = [];
  List<String> missingScreenshots = [];
  List<String> missingBoth = [];
  
  // Check each product
  productsData.forEach((key, value) {
    final productData = Map<String, dynamic>.from(value);
    final sku = (productData['sku'] ?? productData['model'] ?? key).toString();
    
    // Find matching folders (exact or with suffix like _Left, _Right)
    final matchingScreenshots = screenshotFolders.where((folder) => 
      folder == sku || folder.startsWith('${sku}_') || folder.startsWith('$sku-')
    ).toList();
    
    final matchingThumbnails = thumbnailFolders.where((folder) => 
      folder == sku || folder.startsWith('${sku}_') || folder.startsWith('$sku-')
    ).toList();
    
    final hasScreenshotFolder = matchingScreenshots.isNotEmpty;
    final hasThumbnailFolder = matchingThumbnails.isNotEmpty;
    
    // Update statistics
    if (hasScreenshotFolder && hasThumbnailFolder) {
      hasBoth++;
    } else if (hasScreenshotFolder && !hasThumbnailFolder) {
      hasOnlyScreenshot++;
      missingThumbnails.add('$sku (has: ${matchingScreenshots.join(", ")})');
    } else if (!hasScreenshotFolder && hasThumbnailFolder) {
      hasOnlyThumbnail++;
      missingScreenshots.add('$sku (has: ${matchingThumbnails.join(", ")})');
    } else {
      hasNeither++;
      missingBoth.add(sku);
    }
  });
  
  // Print results
  print('=== RESULTS ===\n');
  print('✅ Products with both screenshot and thumbnail: $hasBoth');
  print('📸 Products with only screenshot: $hasOnlyScreenshot');
  print('🖼️ Products with only thumbnail: $hasOnlyThumbnail');
  print('❌ Products with neither: $hasNeither');
  print('📊 Total products: ${productsData.length}\n');
  
  // Show missing thumbnails
  if (missingThumbnails.isNotEmpty) {
    print('\n=== MISSING THUMBNAILS (${missingThumbnails.length} total) ===');
    missingThumbnails.take(30).forEach((sku) {
      print('  - $sku');
    });
    if (missingThumbnails.length > 30) {
      print('  ... and ${missingThumbnails.length - 30} more');
    }
  }
  
  // Show missing screenshots  
  if (missingScreenshots.isNotEmpty) {
    print('\n=== MISSING SCREENSHOTS (${missingScreenshots.length} total) ===');
    missingScreenshots.take(30).forEach((sku) {
      print('  - $sku');
    });
    if (missingScreenshots.length > 30) {
      print('  ... and ${missingScreenshots.length - 30} more');
    }
  }
  
  // Show missing both
  if (missingBoth.isNotEmpty) {
    print('\n=== MISSING BOTH (${missingBoth.length} total) ===');
    missingBoth.take(30).forEach((sku) {
      print('  - $sku');
    });
    if (missingBoth.length > 30) {
      print('  ... and ${missingBoth.length - 30} more');
    }
  }
  
  // Check for CRT-77 specifically
  print('\n=== CRT-77 PRODUCTS CHECK ===');
  final crt77Products = productsData.entries
      .where((e) => e.value['sku']?.toString().contains('CRT-77') == true ||
                    e.value['model']?.toString().contains('CRT-77') == true)
      .toList();
  
  for (var entry in crt77Products) {
    final sku = entry.value['sku'] ?? entry.value['model'] ?? entry.key;
    final matchingScreenshots = screenshotFolders.where((f) => f.contains(sku.toString())).toList();
    final matchingThumbnails = thumbnailFolders.where((f) => f.contains(sku.toString())).toList();
    print('  $sku:');
    print('    Screenshots: ${matchingScreenshots.isEmpty ? "NONE" : matchingScreenshots.join(", ")}');
    print('    Thumbnails: ${matchingThumbnails.isEmpty ? "NONE" : matchingThumbnails.join(", ")}');
  }
  
  print('\n=== SUMMARY ===');
  final coverage = (hasBoth / productsData.length) * 100;
  final screenshotCoverage = ((hasBoth + hasOnlyScreenshot) / productsData.length) * 100;
  final thumbnailCoverage = ((hasBoth + hasOnlyThumbnail) / productsData.length) * 100;
  
  print('📈 Complete coverage: ${coverage.toStringAsFixed(1)}% have both images');
  print('📸 Screenshots coverage: ${screenshotCoverage.toStringAsFixed(1)}%');
  print('🖼️ Thumbnails coverage: ${thumbnailCoverage.toStringAsFixed(1)}%');
  
  client.close();
}