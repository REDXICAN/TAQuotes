// lib/core/utils/product_image_helper_v2.dart

/// NOTE: This is version 2 of ProductImageHelper - NOT IN USE
/// The app currently uses the main ProductImageHelper (product_image_helper.dart)
/// This version was kept for reference but is not actively used
class ProductImageHelper {
  // Cache for checking if folders exist
  static final Map<String, bool> _folderExistsCache = {};
  
  static String getImagePath(String? sku) {
    if (sku == null || sku.isEmpty) {
      return 'assets/logos/turbo_air_logo.png';
    }
    
    // Clean the SKU - remove parentheses content
    String cleanSku = sku.toUpperCase().trim();
    cleanSku = cleanSku.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    // The actual path format is: folder/folder P.1.png (with space)
    // Try exact match first
    String exactPath = 'assets/screenshots/$cleanSku/$cleanSku P.1.png';
    
    // For web, we can't check if file exists, so we'll try the most likely patterns
    // Most folders follow the pattern: SKU/SKU P.1.png
    return exactPath;
  }
  
  static String _extractBaseModel(String sku) {
    // Extract pattern like PRO-12, M3F24, TSR-23, etc.
    
    // Remove parentheses and their contents
    sku = sku.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    // Common patterns:
    // PRO-12R-N -> PRO-12
    // M3F24-1-N -> M3F24
    // TSR-23SD-N6 -> TSR-23
    
    // Try to match pattern: LETTERS + optional dash + NUMBERS
    RegExp pattern = RegExp(r'^([A-Z]+[-]?\d+)');
    Match? match = pattern.firstMatch(sku);
    
    if (match != null) {
      return match.group(1)!;
    }
    
    // For patterns like EF19-1-N-V, extract EF19
    pattern = RegExp(r'^([A-Z]+\d+)');
    match = pattern.firstMatch(sku);
    
    if (match != null) {
      return match.group(1)!;
    }
    
    return '';
  }
  
  static bool _isLikelyMatch(String sku, String variant) {
    // Check if variant is likely to be a match for the SKU
    String skuBase = _extractBaseModel(sku);
    String variantBase = _extractBaseModel(variant);
    
    if (skuBase.isEmpty || variantBase.isEmpty) {
      return false;
    }
    
    // If bases match, it's likely a match
    return skuBase == variantBase || variant.startsWith(skuBase) || sku.startsWith(variant);
  }
  
  // For getting multiple product images (for detail view)
  static List<String> getAllProductImages(String? sku) {
    if (sku == null || sku.isEmpty) {
      return ['assets/logos/turbo_air_logo.png'];
    }
    
    String cleanSku = sku.toUpperCase().trim();
    cleanSku = cleanSku.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    List<String> images = [];
    
    // Only 2 images available: P.1.png and P.2.png
    for (int i = 1; i <= 2; i++) {
      images.add('assets/screenshots/$cleanSku/$cleanSku P.$i.png');
    }
    
    return images;
  }
}