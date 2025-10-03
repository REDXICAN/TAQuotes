import 'package:flutter/material.dart';
import '../services/app_logger.dart';

enum ImageType {
  thumbnail,
  screenshot,
}

class SimpleImageWidget extends StatefulWidget {
  final String sku;
  final bool useThumbnail;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? imageUrl;  // Firebase Storage URL support
  final ImageType? imageType;
  final int screenshotPage;

  const SimpleImageWidget({
    super.key,
    required this.sku,
    this.useThumbnail = true,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.imageUrl,
    this.imageType,
    this.screenshotPage = 1,
  });

  @override
  State<SimpleImageWidget> createState() => _SimpleImageWidgetState();
}

class _SimpleImageWidgetState extends State<SimpleImageWidget> {
  bool _disposed = false;

  // Advanced caching system from ProductImageDisplay
  static final Map<String, bool> _imageExistsCache = {};
  static const int _maxCacheSize = 500;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Cache management to prevent memory leaks
  void _manageCacheSize() {
    if (_imageExistsCache.length > _maxCacheSize) {
      final keysToRemove = _imageExistsCache.keys.take(_maxCacheSize ~/ 2).toList();
      for (final key in keysToRemove) {
        _imageExistsCache.remove(key);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_disposed) {
      return _buildPlaceholder();
    }

    // Log image URL data for debugging image loading issues
    if (widget.sku.isNotEmpty) {
      AppLogger.debug(
        'Image widget loading: sku=${widget.sku}, useThumbnail=${widget.useThumbnail}',
        data: {'imageUrl': widget.imageUrl},
      );
    }

    // Check if we have a valid Firebase Storage URL
    final hasValidFirebaseUrl = widget.imageUrl != null &&
                                widget.imageUrl!.isNotEmpty &&
                                (widget.imageUrl!.startsWith('https://') || widget.imageUrl!.startsWith('gs://'));
    
    // If we have a valid Firebase Storage URL, use it first
    if (hasValidFirebaseUrl) {
      return Image.network(
        widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: widget.width,
            height: widget.height,
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
          // Fall back to local asset images if network fails
          return _buildAssetImage();
        },
      );
    }

    if (widget.sku.isEmpty) {
      return _buildPlaceholder();
    }
    
    // Use local asset images as fallback
    return _buildAssetImage();
  }

  bool get _shouldUseThumbnail {
    if (widget.imageType != null) {
      return widget.imageType == ImageType.thumbnail;
    }
    return widget.useThumbnail;
  }
  
  Widget _buildAssetImage() {
    // Keep original SKU for paths that might have parentheses
    final originalSku = widget.sku.trim().toUpperCase();
    // Clean SKU without parentheses for standard paths
    final cleanSku = originalSku.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

    // Build list of paths to try
    final List<String> pathsToTry = [];

    if (_shouldUseThumbnail) {
      // Try exact match first with both original and clean SKU
      pathsToTry.add('assets/thumbnails/$originalSku/$originalSku.jpg');
      pathsToTry.add('assets/thumbnails/$cleanSku/$cleanSku.jpg');

      // Try with common suffixes
      pathsToTry.add('assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg');
      pathsToTry.add('assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg');
      pathsToTry.add('assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg');
      pathsToTry.add('assets/thumbnails/$cleanSku-L/$cleanSku-L.jpg');

      // Try without -N or -N6 suffix
      final skuWithoutN = cleanSku.replaceAll(RegExp(r'-N\d?$'), '');
      if (skuWithoutN != cleanSku) {
        pathsToTry.add('assets/thumbnails/$skuWithoutN/$skuWithoutN.jpg');
        pathsToTry.add('assets/thumbnails/${skuWithoutN}_Left/${skuWithoutN}_Left.jpg');
      }

      // Fallback to screenshot P.1
      pathsToTry.add('assets/screenshots/$originalSku/$originalSku P.1.png');
      pathsToTry.add('assets/screenshots/$cleanSku/$cleanSku P.1.png');
      pathsToTry.add('assets/screenshots/$originalSku/P.1.png');
      pathsToTry.add('assets/screenshots/$cleanSku/P.1.png');
    } else {
      // Screenshots with page support
      final page = widget.screenshotPage;
      // Try with original SKU (might have parentheses)
      pathsToTry.add('assets/screenshots/$originalSku/$originalSku P.$page.png');
      pathsToTry.add('assets/screenshots/$cleanSku/$cleanSku P.$page.png');
      pathsToTry.add('assets/screenshots/$originalSku/P.$page.png');
      pathsToTry.add('assets/screenshots/$cleanSku/P.$page.png');

      // If specific page not found, try P.1 as fallback
      if (page != 1) {
        pathsToTry.add('assets/screenshots/$originalSku/$originalSku P.1.png');
        pathsToTry.add('assets/screenshots/$cleanSku/$cleanSku P.1.png');
        pathsToTry.add('assets/screenshots/$originalSku/P.1.png');
        pathsToTry.add('assets/screenshots/$cleanSku/P.1.png');
      }
    }

    return _ImageWithFallback(
      paths: pathsToTry,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: _buildPlaceholder(),
      cacheManager: _manageCacheSize,
      imageExistsCache: _imageExistsCache,
    );
  }
  
  Widget _buildPlaceholder() {
    // Try to use default product icon as fallback
    return Image.asset(
      'assets/icons/default_product.png',
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        // If default icon fails, show original placeholder
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: (widget.width ?? 100) * 0.3,
                color: Colors.grey[400],
              ),
              if (widget.width != null && widget.width! > 100) ...[
                const SizedBox(height: 8),
                Text(
                  widget.sku.isNotEmpty ? widget.sku : 'No Image',
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
      },
    );
  }
}

class _ImageWithFallback extends StatefulWidget {
  final List<String> paths;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;
  final VoidCallback cacheManager;
  final Map<String, bool> imageExistsCache;

  const _ImageWithFallback({
    required this.paths,
    required this.placeholder,
    this.width,
    this.height,
    required this.fit,
    required this.cacheManager,
    required this.imageExistsCache,
  });
  
  @override
  State<_ImageWithFallback> createState() => _ImageWithFallbackState();
}

class _ImageWithFallbackState extends State<_ImageWithFallback> {
  int _currentIndex = 0;
  bool _allFailed = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allFailed || _currentIndex >= widget.paths.length || _disposed) {
      return widget.placeholder;
    }

    return _buildImageAtIndex(_currentIndex);
  }

  Widget _buildImageAtIndex(int index) {
    if (index >= widget.paths.length || _disposed) {
      return widget.placeholder;
    }

    final imagePath = widget.paths[index];

    // Check cache first to avoid repeated attempts
    if (widget.imageExistsCache.containsKey(imagePath)) {
      if (widget.imageExistsCache[imagePath] == false) {
        // Known to not exist, try next
        return _buildImageAtIndex(index + 1);
      }
    }

    return Image.asset(
      imagePath,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.width != null && widget.width!.isFinite ? widget.width!.toInt() : null,
      cacheHeight: widget.height != null && widget.height!.isFinite ? widget.height!.toInt() : null,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          // Cache positive result
          widget.imageExistsCache[imagePath] = true;
          widget.cacheManager();
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        // Cache negative result to avoid repeated attempts
        widget.imageExistsCache[imagePath] = false;
        widget.cacheManager();

        // Try next path
        if (index < widget.paths.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_disposed) {
              setState(() {
                _currentIndex = index + 1;
              });
            }
          });
          return widget.placeholder;
        } else {
          // All paths failed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_disposed) {
              setState(() {
                _allFailed = true;
              });
            }
          });
          return widget.placeholder;
        }
      },
    );
  }
}