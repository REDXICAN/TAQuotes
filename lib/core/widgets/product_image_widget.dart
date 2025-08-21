// Smart product image widget with automatic fallback
import 'package:flutter/material.dart';
import 'dart:io';

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
      // Use actual thumbnails from assets/thumbnails folder with proper fallback chain
      return Container(
        color: const Color(0xFFFFFFFF), // White background for image area
        child: _buildThumbnailWithFallback(cleanSku),
      );
    }
    
    // For full images (product details), use screenshot directly
    return _buildScreenshotImage(cleanSku);
  }
  
  Widget _buildThumbnailWithFallback(String cleanSku) {
    // Create pattern for broad matching - first 3 letters and first 2 numbers
    String? pattern = _extractPattern(cleanSku);
    
    // List of potential paths to try
    final paths = <String>[];
    
    // Add exact match paths first
    paths.add('assets/thumbnails/$cleanSku/$cleanSku.jpg');
    paths.add('assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg');
    paths.add('assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg');
    paths.add('assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg');
    
    // If we have a pattern, add broad match paths
    if (pattern != null) {
      // Try pattern-based matching for common variations
      paths.add('assets/thumbnails/$pattern/$pattern.jpg');
      paths.add('assets/thumbnails/${pattern}_Left/${pattern}_Left.jpg');
      paths.add('assets/thumbnails/${pattern}_Right/${pattern}_Right.jpg');
      paths.add('assets/thumbnails/${pattern}_empty/${pattern}_empty.jpg');
      
      // Try with common suffixes
      final baseSku = cleanSku.split('-').take(3).join('-');
      if (baseSku != cleanSku) {
        paths.add('assets/thumbnails/$baseSku/$baseSku.jpg');
        paths.add('assets/thumbnails/${baseSku}_Left/${baseSku}_Left.jpg');
        paths.add('assets/thumbnails/${baseSku}_Right/${baseSku}_Right.jpg');
        paths.add('assets/thumbnails/${baseSku}_empty/${baseSku}_empty.jpg');
      }
    }
    
    // Build nested error handlers
    return _tryLoadImages(paths, 0);
  }
  
  // Extract pattern: first 3 letters + first 2 numbers
  String? _extractPattern(String sku) {
    final letters = StringBuffer();
    final numbers = StringBuffer();
    
    for (int i = 0; i < sku.length; i++) {
      final char = sku[i];
      if (RegExp(r'[A-Za-z]').hasMatch(char) && letters.length < 3) {
        letters.write(char.toUpperCase());
      } else if (RegExp(r'[0-9]').hasMatch(char) && numbers.length < 2) {
        numbers.write(char);
      }
      
      if (letters.length == 3 && numbers.length == 2) {
        break;
      }
    }
    
    if (letters.length == 3 && numbers.length == 2) {
      return '$letters-$numbers';
    }
    return null;
  }
  
  Widget _tryLoadImages(List<String> paths, int index) {
    if (index >= paths.length) {
      // All paths failed, fallback to screenshot
      return _buildScreenshotImage(sku.trim());
    }
    
    return Image.asset(
      paths[index],
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Try next path
        return _tryLoadImages(paths, index + 1);
      },
    );
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