// Smart product image widget with automatic fallback
import 'package:flutter/material.dart';

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
    final cleanSku = sku.trim();
    
    if (useThumbnail) {
      // Use actual thumbnails from assets/thumbnails folder
      return Container(
        color: const Color(0xFFFFFFFF), // White background for image area
        child: Image.asset(
          'assets/thumbnails/$cleanSku/$cleanSku.jpg',
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Try with _Left suffix
            return Image.asset(
              'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
              width: width,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Try with _Right suffix
                return Image.asset(
                  'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Try with _empty suffix
                    return Image.asset(
                      'assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg',
                      width: width,
                      height: height,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to screenshot P.1
                        return Image.asset(
                          'assets/screenshots/$cleanSku/$cleanSku P.1.png',
                          width: width,
                          height: height,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Try without space
                            return Image.asset(
                              'assets/screenshots/$cleanSku/${cleanSku}_P.1.png',
                              width: width,
                              height: height,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Try just P.1.png
                                return Image.asset(
                                  'assets/screenshots/$cleanSku/P.1.png',
                                  width: width,
                                  height: height,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Final fallback - icon
                                    return Icon(
                                      Icons.image_not_supported,
                                      size: width != null ? width! * 0.3 : 48,
                                      color: Colors.grey[400],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      );
    }
    
    // For full images (product details), use screenshot directly
    return _buildScreenshotImage(cleanSku);
  }
  
  Widget _buildScreenshotImage(String cleanSku) {
    // Try various naming patterns for screenshots
    return Image.asset(
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Try without space
        return Image.asset(
          'assets/screenshots/$cleanSku/${cleanSku}_P.1.png',
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            // Try without SKU prefix
            return Image.asset(
              'assets/screenshots/$cleanSku/P.1.png',
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                // Final fallback - icon
                return Container(
                  width: width,
                  height: height,
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.image_not_supported,
                    size: width != null ? width! * 0.3 : 48,
                    color: Colors.grey[400],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}