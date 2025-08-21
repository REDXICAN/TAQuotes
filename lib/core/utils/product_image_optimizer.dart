// lib/core/utils/product_image_optimizer.dart

/// Optimized product image handler with thumbnail support
class ProductImageOptimizer {
  // With 835 products in the database but 1053 image folders available,
  // we use compressed thumbnails for lists and original screenshots for details
  
  /// Get thumbnail path for product lists and grids
  /// Uses compressed JPEG thumbnails for fast loading
  static String getThumbnailPath(String sku) {
    final cleanSku = sku.trim().toUpperCase();
    
    // First try compressed thumbnail
    // These are 600x600 max, JPEG compressed at 85% quality
    return 'assets/thumbnails/$cleanSku/$cleanSku.jpg';
    
    // ProductImageHelperV3 will fallback to screenshots if thumbnail doesn't exist
  }
  
  /// Get full-size image path for product details
  /// These are the original high-quality images
  static String getDetailImagePath(String sku, int imageNumber) {
    final cleanSku = sku.trim().toUpperCase();
    
    // Return the specific image number
    // The ProductImageHelperV3 will handle fallbacks if the image doesn't exist
    return 'assets/screenshots/$cleanSku/$cleanSku P.$imageNumber.png';
  }
  
  /// Get all available images for a product
  static List<String> getAllProductImages(String sku) {
    final cleanSku = sku.trim().toUpperCase();
    
    // Most products have 3-5 images
    // We'll return all possible paths and let the image widget handle missing ones
    final List<String> images = [];
    for (int i = 1; i <= 5; i++) {
      images.add('assets/screenshots/$cleanSku/$cleanSku P.$i.png');
    }
    
    return images;
  }
  
  /// Check if a product likely has images available
  /// Since we have 1053 folders for 835 products, most should have images
  static bool hasImages(String sku) {
    // This is an optimistic check - assume most products have images
    // The actual image loading will handle missing images gracefully
    return sku.trim().isNotEmpty;
  }
}