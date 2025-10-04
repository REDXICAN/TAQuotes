// lib/core/widgets/product_thumbnail_widget.dart
import 'package:flutter/material.dart';

class ProductThumbnailWidget extends StatelessWidget {
  final String? sku;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const ProductThumbnailWidget({
    super.key,
    this.sku,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    // Try network image first if URL provided
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (imageUrl!.startsWith('http')) {
        return Image.network(
          imageUrl!,
          width: width,
          height: height,
          fit: fit,
          // Optimize image decoding for thumbnails
          cacheWidth: width != null && width!.isFinite
            ? (width! * 2).toInt()  // 2x for high DPI displays
            : 200, // Default thumbnail cache width
          cacheHeight: height != null && height!.isFinite
            ? (height! * 2).toInt()
            : 200, // Default thumbnail cache height
          errorBuilder: (context, error, stackTrace) => _buildFallback(context),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoading(context);
          },
        );
      }
    }

    // Try asset image based on SKU
    if (sku != null && sku!.isNotEmpty) {
      final cleanSku = _cleanSku(sku!);
      final assetPath = 'assets/thumbnails/$cleanSku/$cleanSku.jpg';
      
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Try alternative paths
          final altPaths = [
            'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
            'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
            'assets/images/products/$cleanSku.jpg',
          ];
          
          for (final path in altPaths) {
            return Image.asset(
              path,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildFallback(context),
            );
          }
          return _buildFallback(context);
        },
      );
    }

    return _buildFallback(context);
  }

  String _cleanSku(String sku) {
    return sku
        .replaceAll(RegExp(r'\([^)]*\)'), '') // Remove parentheses content
        .trim()
        .toUpperCase();
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (placeholder != null) return placeholder!;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 32,
            color: Colors.grey[400],
          ),
          if (sku != null) ...[
            const SizedBox(height: 4),
            Text(
              sku!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}