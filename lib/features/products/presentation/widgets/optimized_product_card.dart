// lib/features/products/presentation/widgets/optimized_product_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

// Cache for successful image paths to prevent repeated lookups
class ImagePathCache {
  static final Map<String, String?> _cache = {};
  static const int maxCacheSize = 1000;

  static String? getCachedPath(String key) => _cache[key];

  static void setCachedPath(String key, String? path) {
    if (_cache.length >= maxCacheSize) {
      // Remove oldest entries
      final keysToRemove = _cache.keys.take(100).toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
      }
    }
    _cache[key] = path;
  }
}

// Memoized stock calculation provider
final productStockProvider = Provider.family<int, Product>((ref, product) {
  if (product.warehouseStock == null || product.warehouseStock!.isEmpty) {
    return product.stock;
  }

  return product.warehouseStock!.values
      .fold<int>(0, (sum, stock) => sum + (stock.available ?? 0));
});

class OptimizedProductCard extends ConsumerStatefulWidget {
  final Product product;
  final bool useThumbnail;

  const OptimizedProductCard({
    super.key,
    required this.product,
    this.useThumbnail = true,
  });

  @override
  ConsumerState<OptimizedProductCard> createState() => _OptimizedProductCardState();
}

class _OptimizedProductCardState extends ConsumerState<OptimizedProductCard>
    with AutomaticKeepAliveClientMixin {
  int _quantity = 1;
  bool _isAddingToCart = false;
  String? _cachedImageUrl;

  @override
  bool get wantKeepAlive => false; // Don't keep alive to save memory

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  void _initializeImage() {
    // Check cache first
    final cacheKey = '${widget.product.id}_${widget.useThumbnail}';
    _cachedImageUrl = ImagePathCache.getCachedPath(cacheKey);

    if (_cachedImageUrl == null) {
      // Determine the image URL to use
      if (widget.useThumbnail && widget.product.thumbnailUrl != null) {
        _cachedImageUrl = widget.product.thumbnailUrl;
      } else if (widget.product.imageUrl != null) {
        _cachedImageUrl = widget.product.imageUrl;
      }

      // Cache the result
      ImagePathCache.setCachedPath(cacheKey, _cachedImageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final totalStock = ref.watch(productStockProvider(widget.product));
    final isOutOfStock = totalStock <= 0;

    // Responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final cardPadding = isDesktop ? 16.0 : 12.0;
    final imageHeight = isDesktop ? 140.0 : 120.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to product detail
          Navigator.pushNamed(
            context,
            '/products/${widget.product.id}',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with optimized loading
            AspectRatio(
              aspectRatio: 1.2,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _buildOptimizedImage(imageHeight),
              ),
            ),

            // Product info
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SKU/Model
                    Text(
                      widget.product.sku ?? widget.product.model,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Name
                    Text(
                      widget.product.name ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Price
                    Text(
                      '\$${PriceFormatter.formatPrice(widget.product.price)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Stock status
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOutOfStock ? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOutOfStock ? 'Out of Stock' : '$totalStock in stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOutOfStock ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Quantity and Add to Cart
                    if (!isOutOfStock) ...[
                      Row(
                        children: [
                          // Quantity selector
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (_quantity > 1) {
                                      setState(() => _quantity--);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.remove, size: 16),
                                  ),
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 30),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    _quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    if (_quantity < totalStock) {
                                      setState(() => _quantity++);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.add, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Add to cart button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isAddingToCart
                                  ? null
                                  : () => _addToCart(context, ref),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isAddingToCart
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.shopping_cart_outlined, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Out of Stock', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizedImage(double height) {
    // Use Firebase Storage URL if available
    if (_cachedImageUrl != null && _cachedImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _cachedImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 200),
        memCacheHeight: height.toInt(),
        memCacheWidth: (height * 1.2).toInt(),
      );
    }

    // Fallback to placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.sku ?? widget.product.model,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(BuildContext context, WidgetRef ref) async {
    setState(() => _isAddingToCart = true);

    try {
      final cartItem = CartItem(
        product: widget.product,
        quantity: _quantity,
        addedAt: DateTime.now(),
        sequenceNumber: '',
      );

      await ref.read(cartProvider.notifier).addItem(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.product.displayName} added to cart',
            ),
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Reset quantity
        setState(() {
          _quantity = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }
}