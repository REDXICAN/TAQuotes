import 'package:flutter/material.dart';

class SimpleProductImage extends StatelessWidget {
  final String sku;
  final ImageType imageType;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int screenshotPage;

  const SimpleProductImage({
    super.key,
    required this.sku,
    required this.imageType,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.screenshotPage = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (sku.isEmpty) {
      return _buildPlaceholder();
    }

    // Keep original SKU for special cases
    final originalSku = sku.trim().toUpperCase();
    // Clean SKU - remove parentheses and extra spaces for standard paths
    final cleanSku = originalSku.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    // Build the image path based on type
    String imagePath;
    if (imageType == ImageType.thumbnail) {
      // Try different thumbnail patterns
      imagePath = _getThumbnailPath(cleanSku);
    } else {
      // Screenshot path - try with original SKU first (might have special chars)
      imagePath = 'assets/screenshots/$originalSku/$originalSku P.$screenshotPage.png';
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
          // If primary path fails, try fallback paths
          if (imageType == ImageType.thumbnail) {
            return _buildThumbnailWithFallbacks(cleanSku);
          } else {
            return _buildScreenshotWithFallbacks(originalSku, cleanSku);
          }
        },
      ),
    );
  }

  String _getThumbnailPath(String cleanSku) {
    // Check for special suffixes first
    if (cleanSku.contains('-L')) {
      return 'assets/thumbnails/${cleanSku}/${cleanSku}.jpg';
    }
    // Standard thumbnail path
    return 'assets/thumbnails/$cleanSku/$cleanSku.jpg';
  }

  Widget _buildThumbnailWithFallbacks(String cleanSku) {
    // List of fallback paths to try
    final fallbackPaths = [
      'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
      'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
      'assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg',
      'assets/thumbnails/${cleanSku}-L/${cleanSku}-L.jpg',
      // Try screenshot as last resort
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',
    ];

    return _tryMultiplePaths(fallbackPaths, 0);
  }

  Widget _buildScreenshotWithFallbacks(String originalSku, String cleanSku) {
    // Try alternative screenshot paths including special character versions
    final fallbackPaths = [
      // Try clean SKU paths
      'assets/screenshots/$cleanSku/$cleanSku P.$screenshotPage.png',
      'assets/screenshots/$cleanSku/P.$screenshotPage.png',
      // Try with (-L) suffix
      'assets/screenshots/$cleanSku(-L)/$cleanSku(-L) P.$screenshotPage.png',
      'assets/screenshots/${cleanSku}-L/${cleanSku}-L P.$screenshotPage.png',
      // Try with parentheses variations
      'assets/screenshots/$originalSku/$originalSku P.$screenshotPage.png',
      // Fall back to P.1 if specific page not found
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',
      'assets/screenshots/$cleanSku(-L)/$cleanSku(-L) P.1.png',
      'assets/screenshots/${cleanSku}-L/${cleanSku}-L P.1.png',
      'assets/screenshots/$originalSku/$originalSku P.1.png',
      'assets/screenshots/$cleanSku/P.1.png',
    ];

    return _tryMultiplePaths(fallbackPaths, 0);
  }

  Widget _tryMultiplePaths(List<String> paths, int index) {
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
        return _tryMultiplePaths(paths, index + 1);
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: (width ?? 100) * 0.3,
            color: Colors.grey[400],
          ),
          if (width != null && width! > 100) ...[
            const SizedBox(height: 8),
            Text(
              sku.isNotEmpty ? sku : 'No Image',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

enum ImageType {
  thumbnail,
  screenshot,
}