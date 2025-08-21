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
    Key? key,
    required this.sku,
    this.useThumbnail = false,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (sku.isEmpty) {
      return _buildPlaceholder();
    }
    
    // Clean the SKU
    final cleanSku = sku.toUpperCase().trim();
    
    // Get the appropriate image path
    String imagePath;
    if (useThumbnail) {
      // For thumbnails, use the thumbnail directory
      imagePath = 'assets/thumbnails/$cleanSku/$cleanSku.jpg';
    } else {
      // For screenshots, check if we have a mapped path
      imagePath = ProductImageHelper.getImagePath(cleanSku) ?? 
                  'assets/screenshots/$cleanSku/$cleanSku P.1.png';
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
          // Try alternative paths
          if (useThumbnail) {
            // Try with _Left suffix
            return Image.asset(
              'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                // Try with _Right suffix
                return Image.asset(
                  'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
                  width: width,
                  height: height,
                  fit: fit,
                  errorBuilder: (context, error, stackTrace) {
                    // Final fallback - placeholder
                    return _buildPlaceholder();
                  },
                );
              },
            );
          } else {
            // For screenshots, try alternative path
            return Image.asset(
              'assets/screenshots/$cleanSku/P.1.png',
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder();
              },
            );
          }
        },
      ),
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