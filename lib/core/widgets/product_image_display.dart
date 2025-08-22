// lib/core/widgets/product_image_display.dart
import 'package:flutter/material.dart';

enum ImageType {
  thumbnail,
  screenshot,
}

class ProductImageDisplay extends StatefulWidget {
  final String sku;
  final ImageType imageType;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int screenshotPage;
  final String? imageUrl;  // Add imageUrl parameter
  
  const ProductImageDisplay({
    super.key,
    required this.sku,
    required this.imageType,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.screenshotPage = 1,
    this.imageUrl,  // Accept imageUrl
  });
  
  @override
  State<ProductImageDisplay> createState() => _ProductImageDisplayState();
}

class _ProductImageDisplayState extends State<ProductImageDisplay> {
  String? _currentPath;
  final List<String> _attemptedPaths = [];
  bool _isLoading = true;
  bool _disposed = false;
  
  // OPTIMIZATION: Cache for image existence checks
  static final Map<String, bool> _imageExistsCache = {};
  static const int _maxCacheSize = 500;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  @override
  void didUpdateWidget(ProductImageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sku != widget.sku || 
        oldWidget.imageType != widget.imageType ||
        oldWidget.screenshotPage != widget.screenshotPage) {
      _loadImage();
    }
  }
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  void _loadImage() {
    if (_disposed) return;
    
    setState(() {
      _isLoading = true;
      _attemptedPaths.clear();
    });
    
    // Get the appropriate path based on image type
    if (widget.imageType == ImageType.thumbnail) {
      _tryLoadThumbnail();
    } else {
      _tryLoadScreenshot();
    }
  }
  
  // OPTIMIZATION: Manage cache size to prevent memory leaks
  void _manageCacheSize() {
    if (_imageExistsCache.length > _maxCacheSize) {
      final keysToRemove = _imageExistsCache.keys.take(_maxCacheSize ~/ 2).toList();
      for (final key in keysToRemove) {
        _imageExistsCache.remove(key);
      }
    }
  }
  
  void _tryLoadThumbnail() {
    // Keep original SKU for paths that might have parentheses
    final originalSku = widget.sku.trim().toUpperCase();
    // Clean SKU without parentheses for standard paths
    final cleanSku = originalSku.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    // List of paths to try in order - include both original and clean SKU patterns
    final pathsToTry = [
      // Try exact match first
      'assets/thumbnails/$originalSku/$originalSku.jpg',
      'assets/thumbnails/$cleanSku/$cleanSku.jpg',
      // Try with suffixes
      'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
      'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
      'assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg',
      // Try with -L suffix (common pattern)
      'assets/thumbnails/${cleanSku}-L/${cleanSku}-L.jpg',
      // Fallback to screenshot P.1 if no thumbnail
      'assets/screenshots/$originalSku/$originalSku P.1.png',
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',
      'assets/screenshots/$originalSku/P.1.png',
      'assets/screenshots/$cleanSku/P.1.png',
    ];
    
    _currentPath = pathsToTry[0];
    _attemptedPaths.addAll(pathsToTry);
    
    setState(() {
      _isLoading = false;
    });
  }
  
  void _tryLoadScreenshot() {
    // Keep original SKU for paths that might have parentheses
    final originalSku = widget.sku.trim().toUpperCase();
    // Clean SKU without parentheses for standard paths
    final cleanSku = originalSku.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    // List of paths to try in order - include both original and clean SKU patterns
    final pathsToTry = [
      // Try with original SKU (might have parentheses)
      'assets/screenshots/$originalSku/$originalSku P.${widget.screenshotPage}.png',
      'assets/screenshots/$cleanSku/$cleanSku P.${widget.screenshotPage}.png',
      'assets/screenshots/$originalSku/P.${widget.screenshotPage}.png',
      'assets/screenshots/$cleanSku/P.${widget.screenshotPage}.png',
      // If specific page not found, try P.1 as fallback
      'assets/screenshots/$originalSku/$originalSku P.1.png',
      'assets/screenshots/$cleanSku/$cleanSku P.1.png',
      'assets/screenshots/$originalSku/P.1.png',
      'assets/screenshots/$cleanSku/P.1.png',
    ];
    
    _currentPath = pathsToTry[0];
    _attemptedPaths.addAll(pathsToTry);
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Widget _buildImageWithFallback() {
    // Always try asset images first since we have them locally
    // Only use network images if explicitly no local assets exist
    return _buildAssetImageWithFallback();
  }
  
  Widget _buildAssetImageWithFallback() {
    if (_currentPath == null || _attemptedPaths.isEmpty) {
      return _buildPlaceholder();
    }
    
    Widget buildImageAtIndex(int index) {
      if (index >= _attemptedPaths.length || _disposed) {
        return _buildPlaceholder();
      }
      
      final imagePath = _attemptedPaths[index];
      
      // OPTIMIZATION: Check cache first
      if (_imageExistsCache.containsKey(imagePath)) {
        if (_imageExistsCache[imagePath] == false) {
          // Known to not exist, try next
          return buildImageAtIndex(index + 1);
        }
      }
      
      return Image.asset(
        imagePath,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        // OPTIMIZATION: Proper caching and error handling
        cacheWidth: widget.width?.toInt(),
        cacheHeight: widget.height?.toInt(),
        errorBuilder: (context, error, stackTrace) {
          // Cache negative result to avoid repeated attempts
          _imageExistsCache[imagePath] = false;
          _manageCacheSize();
          
          // Try next path
          return buildImageAtIndex(index + 1);
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null) {
            // Cache positive result
            _imageExistsCache[imagePath] = true;
            _manageCacheSize();
          }
          return child;
        },
      );
    }
    
    return buildImageAtIndex(0);
  }
  
  Widget _buildPlaceholder() {
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
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white,
      child: _buildImageWithFallback(),
    );
  }
}