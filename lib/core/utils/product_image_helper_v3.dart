// lib/core/utils/product_image_helper_v3.dart

class ProductImageHelperV3 {
  // Cache for directory listings
  static Map<String, List<String>>? _directoryCache;
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  /// Get thumbnail path for product lists and grids (compressed)
  static String getThumbnailPath(String sku) {
    String cleanSku = sku.trim();
    
    // Try WebP first (best compression), then JPEG, then fallback to screenshot
    // WebP is supported on all modern browsers and Flutter
    return 'assets/thumbnails/$cleanSku/$cleanSku.webp';
  }
  
  /// Get the main image path for a product SKU (full quality for details)
  static String getMainImagePath(String sku, {bool useThumbnail = false}) {
    // If thumbnail is requested, use compressed version
    if (useThumbnail) {
      return getThumbnailPath(sku);
    }
    
    // Otherwise use full quality screenshot
    String cleanSku = sku.trim();
    
    // First try exact match with the actual naming pattern (with space)
    String exactPath = 'assets/screenshots/$cleanSku/$cleanSku P.1.png';
    
    // For web/Flutter, we can't check file existence, so we'll use a fallback approach
    // Try different naming patterns
    List<String> possiblePaths = [
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',  // Actual format with space
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',    // Without braces
      'assets/screenshots/$cleanSku/P.1.png',              // Without SKU prefix
      'assets/screenshots/$cleanSku/${cleanSku}_P.1.png',  // With underscore
      'assets/screenshots/$cleanSku/main.png',             // Alternative naming
    ];
    
    // Try to find a variant match using the first part of the SKU
    String baseSkuPattern = _extractBaseSku(cleanSku);
    if (baseSkuPattern.isNotEmpty && baseSkuPattern != cleanSku) {
      possiblePaths.addAll([
        'assets/screenshots/$baseSkuPattern/$baseSkuPattern P.1.png',
        'assets/screenshots/$baseSkuPattern/P.1.png',
      ]);
    }
    
    // Return the first path (we'll handle errors in the Image widget)
    return possiblePaths.first;
  }
  
  /// Get all image paths for a product (P.1, P.2, etc.)
  static List<String> getAllImagePaths(String sku) {
    String cleanSku = sku.trim();
    List<String> imagePaths = [];
    
    // Try to get up to 5 images with the actual naming pattern
    for (int i = 1; i <= 5; i++) {
      imagePaths.add('assets/screenshots/$cleanSku/$cleanSku P.$i.png');
    }
    
    return imagePaths;
  }
  
  /// Extract base SKU pattern for variant matching
  /// For example: "TSR-23SD-N6" -> "TSR-23"
  static String _extractBaseSku(String sku) {
    if (sku.isEmpty) return '';
    
    // Remove common suffixes
    String cleaned = sku
        .replaceAll(RegExp(r'-N\d*$'), '')  // Remove -N, -N6, etc.
        .replaceAll(RegExp(r'-V$'), '')     // Remove -V
        .replaceAll(RegExp(r'-G$'), '')     // Remove -G
        .replaceAll(RegExp(r'-PT$'), '')    // Remove -PT
        .replaceAll(RegExp(r'-TS$'), '')    // Remove -TS
        .replaceAll(RegExp(r'\(-.*\)$'), ''); // Remove parentheses variants
    
    // Try to extract pattern like "ABC-12" from "ABC-12-XYZ"
    RegExp pattern = RegExp(r'^([A-Z]+)-?(\d+)');
    Match? match = pattern.firstMatch(cleaned);
    
    if (match != null) {
      String prefix = match.group(1) ?? '';
      String numbers = match.group(2) ?? '';
      
      // Return the base pattern
      if (prefix.isNotEmpty && numbers.isNotEmpty) {
        return '$prefix-$numbers';
      } else if (prefix.isNotEmpty) {
        return prefix;
      }
    }
    
    // If no pattern matches, try to get the first two segments
    List<String> parts = sku.split('-');
    if (parts.length >= 2) {
      return '${parts[0]}-${parts[1]}';
    }
    
    return parts.first;
  }
  
  /// Find best matching SKU folder from available folders
  static String findBestMatchingSku(String searchSku, List<String> availableSkus) {
    // 1. Try exact match
    if (availableSkus.contains(searchSku)) {
      return searchSku;
    }
    
    // 2. Try case-insensitive match
    String upperSearch = searchSku.toUpperCase();
    for (String available in availableSkus) {
      if (available.toUpperCase() == upperSearch) {
        return available;
      }
    }
    
    // 3. Try base SKU match
    String basePattern = _extractBaseSku(searchSku);
    if (basePattern.isNotEmpty) {
      // Look for folders that start with the base pattern
      for (String available in availableSkus) {
        if (available.startsWith(basePattern)) {
          return available;
        }
      }
      
      // Try more flexible matching
      for (String available in availableSkus) {
        String availableBase = _extractBaseSku(available);
        if (availableBase == basePattern) {
          return available;
        }
      }
    }
    
    // 4. Try fuzzy matching based on similarity
    String? bestMatch;
    int bestScore = 0;
    
    for (String available in availableSkus) {
      int score = _calculateSimilarity(searchSku, available);
      if (score > bestScore && score > 50) { // At least 50% similar
        bestScore = score;
        bestMatch = available;
      }
    }
    
    return bestMatch ?? searchSku;
  }
  
  /// Calculate similarity score between two SKUs (0-100)
  static int _calculateSimilarity(String sku1, String sku2) {
    sku1 = sku1.toUpperCase();
    sku2 = sku2.toUpperCase();
    
    if (sku1 == sku2) return 100;
    
    // Check if one contains the other
    if (sku1.contains(sku2) || sku2.contains(sku1)) {
      return 80;
    }
    
    // Check common prefix
    int commonPrefix = 0;
    for (int i = 0; i < sku1.length && i < sku2.length; i++) {
      if (sku1[i] == sku2[i]) {
        commonPrefix++;
      } else {
        break;
      }
    }
    
    // Calculate score based on common prefix
    int maxLength = sku1.length > sku2.length ? sku1.length : sku2.length;
    return ((commonPrefix / maxLength) * 100).round();
  }
  
  /// Get a display-friendly image widget that handles errors gracefully
  static String getImagePathWithFallback(String sku) {
    // This will be the primary method used by the app
    String primaryPath = getMainImagePath(sku);
    
    // For variants, try to find the base SKU
    if (!primaryPath.contains('assets/screenshots/$sku/')) {
      String baseSku = _extractBaseSku(sku);
      if (baseSku.isNotEmpty && baseSku != sku) {
        return getMainImagePath(baseSku);
      }
    }
    
    return primaryPath;
  }
}