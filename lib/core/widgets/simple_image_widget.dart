import 'package:flutter/material.dart';

class SimpleImageWidget extends StatelessWidget {
  final String sku;
  final bool useThumbnail;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? imageUrl;  // Add Firebase Storage URL support
  
  const SimpleImageWidget({
    super.key,
    required this.sku,
    this.useThumbnail = true,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.imageUrl,
  });
  
  @override
  Widget build(BuildContext context) {
    // Check if we have a valid Firebase Storage URL (not null and not empty)
    // Firebase Storage URLs should start with 'https://' or 'gs://'
    final hasValidFirebaseUrl = imageUrl != null && 
                                imageUrl!.isNotEmpty && 
                                (imageUrl!.startsWith('https://') || imageUrl!.startsWith('gs://'));
    
    // If we have a valid Firebase Storage URL, use it
    if (hasValidFirebaseUrl) {
      return Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[100],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fall back to asset images if network fails
          return _buildAssetImage();
        },
      );
    }
    
    if (sku.isEmpty) {
      return _buildPlaceholder();
    }
    
    // Use local asset images
    return _buildAssetImage();
  }
  
  Widget _buildAssetImage() {
    
    // Clean SKU - just uppercase and trim
    final cleanSku = sku.toUpperCase().trim();
    
    // Build list of paths to try
    final List<String> pathsToTry = [];
    
    if (useThumbnail) {
      // Try exact match first
      pathsToTry.add('assets/thumbnails/$cleanSku/$cleanSku.jpg');
      
      // Try with common suffixes
      pathsToTry.add('assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg');
      pathsToTry.add('assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg');
      pathsToTry.add('assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg');
      
      // Try without -N or -N6 suffix
      final skuWithoutN = cleanSku.replaceAll(RegExp(r'-N\d?$'), '');
      if (skuWithoutN != cleanSku) {
        pathsToTry.add('assets/thumbnails/$skuWithoutN/$skuWithoutN.jpg');
        pathsToTry.add('assets/thumbnails/${skuWithoutN}_Left/${skuWithoutN}_Left.jpg');
      }
      
      // Fallback to screenshot
      pathsToTry.add('assets/screenshots/$cleanSku/$cleanSku P.1.png');
    } else {
      // Screenshots
      pathsToTry.add('assets/screenshots/$cleanSku/$cleanSku P.1.png');
      pathsToTry.add('assets/screenshots/$cleanSku/P.1.png');
    }
    
    return _ImageWithFallback(
      paths: pathsToTry,
      width: width,
      height: height,
      fit: fit,
      placeholder: _buildPlaceholder(),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 24,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            sku,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ImageWithFallback extends StatefulWidget {
  final List<String> paths;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;
  
  const _ImageWithFallback({
    required this.paths,
    required this.placeholder,
    this.width,
    this.height,
    required this.fit,
  });
  
  @override
  State<_ImageWithFallback> createState() => _ImageWithFallbackState();
}

class _ImageWithFallbackState extends State<_ImageWithFallback> {
  int _currentIndex = 0;
  bool _allFailed = false;
  
  @override
  Widget build(BuildContext context) {
    if (_allFailed || _currentIndex >= widget.paths.length) {
      return widget.placeholder;
    }
    
    return Image.asset(
      widget.paths[_currentIndex],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        // Try next image
        if (_currentIndex < widget.paths.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentIndex++;
              });
            }
          });
        } else {
          // All paths failed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allFailed = true;
              });
            }
          });
        }
        // Return placeholder while we try next
        return widget.placeholder;
      },
    );
  }
}