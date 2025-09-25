// lib/core/widgets/product_image_widget.dart
import 'package:flutter/material.dart';
import '../utils/product_image_helper.dart';

class ProductImageWidget extends StatelessWidget {
  final String sku;
  final bool useThumbnail;
  final double? width;
  final double? height;
  final BoxFit fit;
  
  const ProductImageWidget({
    super.key,
    required this.sku,
    this.useThumbnail = false,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });
  
  @override
  Widget build(BuildContext context) {
    if (sku.isEmpty) {
      return _buildPlaceholder();
    }
    
    // Clean the SKU
    final cleanSku = sku.toUpperCase().trim();
    
    // Get the appropriate image path
    String imagePath;
    List<String> fallbackPaths = [];
    
    if (useThumbnail) {
      // For thumbnails, the folder structure is different - folders have suffixes
      // First try without suffix (for products that have their own folder)
      imagePath = 'assets/thumbnails/$cleanSku/$cleanSku.jpg';
      fallbackPaths = [
        // Most common patterns
        'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
        'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
        'assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg',
        // With -L suffix
        'assets/thumbnails/$cleanSku-L/$cleanSku-L.jpg',
        // Just the folder without suffix might exist
        'assets/thumbnails/$cleanSku/$cleanSku.jpg',
        // Try with parentheses
        'assets/thumbnails/$cleanSku(-L)/$cleanSku(-L).jpg',
        // Try removing any suffix from the SKU itself
        'assets/thumbnails/${cleanSku.replaceAll(RegExp(r"-L$"), "")}/${cleanSku.replaceAll(RegExp(r"-L$"), "")}.jpg',
        'assets/thumbnails/${cleanSku.replaceAll(RegExp(r"-L$"), "")}_Left/${cleanSku.replaceAll(RegExp(r"-L$"), "")}_Left.jpg',
      ];
    } else {
      // For screenshots, check if we have a mapped path
      imagePath = ProductImageHelper.getImagePath(cleanSku) ?? 
                  'assets/screenshots/$cleanSku/$cleanSku P.1.png';
      fallbackPaths = [
        'assets/screenshots/$cleanSku(-L)/$cleanSku(-L) P.1.png',
        'assets/screenshots/$cleanSku-L/$cleanSku-L P.1.png',
        'assets/screenshots/$cleanSku/P.1.png',
      ];
    }
    
    return Container(
      width: width,
      height: height,
      color: Colors.white,
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Try fallback paths
          return _tryFallbackPaths(fallbackPaths, 0);
        },
      ),
    );
  }
  
  Widget _tryFallbackPaths(List<String> paths, int index) {
    if (index >= paths.length) {
      return _buildPlaceholder();
    }
    
    return Image.asset(
      paths[index],
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return _tryFallbackPaths(paths, index + 1);
      },
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: (width ?? 100) * 0.3,
            color: Colors.grey[400],
          ),
          if (width != null && width! > 100)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No Image',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}