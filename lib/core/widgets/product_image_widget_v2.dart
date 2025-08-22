import 'package:flutter/material.dart';

class ProductImageWidgetV2 extends StatelessWidget {
  final String sku;
  final bool useThumbnail;
  final double? width;
  final double? height;
  final BoxFit fit;
  
  const ProductImageWidgetV2({
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
    
    // Clean the SKU - remove parentheses and trim
    final cleanSku = sku.toUpperCase().trim().replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    if (useThumbnail) {
      return _buildThumbnailImage(cleanSku);
    } else {
      return _buildScreenshotImage(cleanSku);
    }
  }
  
  Widget _buildThumbnailImage(String cleanSku) {
    // List of paths to try for thumbnails
    final pathsToTry = [
      // Most products have their own folder
      'assets/thumbnails/$cleanSku/$cleanSku.jpg',
      // Some have _Left suffix
      'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
      // Some have _Right suffix
      'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
      // Some have _empty suffix
      'assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg',
      // Try with -L suffix
      'assets/thumbnails/${cleanSku}-L/${cleanSku}-L.jpg',
      // Fallback to screenshot if no thumbnail
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',
    ];
    
    return _tryLoadImage(pathsToTry, 0);
  }
  
  Widget _buildScreenshotImage(String cleanSku) {
    // List of paths to try for screenshots
    final pathsToTry = [
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',
      'assets/screenshots/$cleanSku/P.1.png',
      'assets/screenshots/${cleanSku}-L/${cleanSku}-L P.1.png',
      'assets/screenshots/$cleanSku(-L)/$cleanSku(-L) P.1.png',
    ];
    
    return _tryLoadImage(pathsToTry, 0);
  }
  
  Widget _tryLoadImage(List<String> paths, int index) {
    if (index >= paths.length) {
      return _buildPlaceholder();
    }
    
    return Image.asset(
      paths[index],
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Try next path
        return _tryLoadImage(paths, index + 1);
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          // Image loaded successfully
          return Container(
            width: width,
            height: height,
            color: Colors.white,
            child: child,
          );
        }
        // Still loading
        return Container(
          width: width,
          height: height,
          color: Colors.grey[100],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
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
                sku.isNotEmpty ? sku : 'No Image',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}