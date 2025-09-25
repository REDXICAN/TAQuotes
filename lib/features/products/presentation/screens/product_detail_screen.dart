// lib/features/products/presentation/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../widgets/product_detail_images.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/price_formatter.dart';

// Product detail provider
final productDetailProvider =
    FutureProvider.family<Product?, String>((ref, productId) async {
  final dbService = ref.watch(databaseServiceProvider);
  final productData = await dbService.getProduct(productId);

  if (productData == null) return null;
  return Product.fromJson(productData);
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  String _note = '';
  bool _showNoteField = false;
  String? _cartItemId;
  final _noteController = TextEditingController();
  Map<String, String> _preservedComments = {}; // Store preserved comments in memory

  @override
  void initState() {
    super.initState();
    _checkExistingCartItem();
    _loadPreservedComment();
  }

  Future<void> _checkExistingCartItem() async {
    final dbService = ref.read(databaseServiceProvider);
    final cartItems = await dbService.getCartItems().first;
    
    for (var item in cartItems) {
      if (item['product_id'] == widget.productId) {
        setState(() {
          _cartItemId = item['id'];
          _quantity = item['quantity'] ?? 1;
          _note = item['note'] ?? '';
          _noteController.text = _note;
          _showNoteField = _cartItemId != null;
        });
        break;
      }
    }
  }

  Future<void> _loadPreservedComment() async {
    // Load preserved comment from database if item was previously removed
    final dbService = ref.read(databaseServiceProvider);
    final preservedComment = await dbService.getPreservedComment(widget.productId);
    if (preservedComment != null && _note.isEmpty) {
      setState(() {
        _note = preservedComment;
        _noteController.text = preservedComment;
      });
    }
  }

  Future<void> _updateQuantity(int newQuantity) async {
    if (newQuantity < 0) return;
    
    final dbService = ref.read(databaseServiceProvider);
    
    if (newQuantity == 0 && _cartItemId != null) {
      // Preserve the comment before removing from cart
      if (_note.isNotEmpty) {
        await dbService.preserveComment(widget.productId, _note);
      }
      
      // Remove from cart
      await dbService.removeFromCart(_cartItemId!);
      
      setState(() {
        _quantity = 0;
        _cartItemId = null;
        _showNoteField = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item removed from cart${_note.isNotEmpty ? ' (note preserved)' : ''}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (newQuantity > 0) {
      setState(() {
        _quantity = newQuantity;
      });
      
      if (_cartItemId != null) {
        // Update existing cart item
        await dbService.updateCartItem(_cartItemId!, quantity: newQuantity);
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final theme = Theme.of(context);
    final dbService = ref.watch(databaseServiceProvider);

    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Product Details',
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => context.go('/cart'),
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(
              child: Text('Product not found'),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 768;
              final screenHeight = MediaQuery.of(context).size.height;
              
              if (isWideScreen) {
                // Desktop/Tablet: Specs on left (25%), images on right (75%)
                return SizedBox(
                  height: screenHeight - 100, // Full height minus app bar
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column: Product info and specs (25%) - scrollable
                        SizedBox(
                          width: constraints.maxWidth * 0.25,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                      // SKU and Category
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.sku ?? '',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark 
                                  ? Colors.grey[800] 
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Product name with Top Seller star for superadmins
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Top Seller toggle for superadmins only
                          Consumer(
                            builder: (context, ref, _) {
                              final authState = ref.watch(authStateProvider);
                              final isSuperAdmin = authState.value?.email == 'andres@turboairmexico.com';
                              
                              if (isSuperAdmin) {
                                return IconButton(
                                  icon: Icon(
                                    product.isTopSeller ? Icons.star : Icons.star_border,
                                    color: product.isTopSeller ? Colors.amber : Colors.grey,
                                    size: 28,
                                  ),
                                  tooltip: product.isTopSeller ? 'Remove Top Seller' : 'Mark as Top Seller',
                                  onPressed: () async {
                                    try {
                                      final dbService = ref.read(databaseServiceProvider);
                                      await dbService.updateProduct(
                                        widget.productId,
                                        {'isTopSeller': !product.isTopSeller},
                                      );
                                      // Refresh the product data
                                      ref.invalidate(productDetailProvider(widget.productId));
                                      
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            product.isTopSeller
                                                ? 'Removed from Top Sellers'
                                                : 'Marked as Top Seller',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error updating product: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      }
                                    }
                                  },
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            PriceFormatter.formatNumber(product.price),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Price may vary based on configuration',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),

                      // Warehouse Stock Information
                      if (product.warehouseStock != null && product.warehouseStock!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.blue.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warehouse,
                                    size: 20,
                                    color: theme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Stock Availability',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Total Stock Summary
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: () {
                                        // Calculate total stock
                                        int totalStock = 0;
                                        for (var entry in product.warehouseStock!.entries) {
                                          final available = entry.value.available;
                                          final reserved = entry.value.reserved;
                                          totalStock += (available - reserved);
                                        }
                                        
                                        if (totalStock > 50) {
                                          return Colors.green.withOpacity(0.2);
                                        } else if (totalStock > 10) {
                                          return Colors.orange.withOpacity(0.2);
                                        } else if (totalStock > 0) {
                                          return Colors.red.withOpacity(0.2);
                                        } else {
                                          return Colors.grey.withOpacity(0.2);
                                        }
                                      }(),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: () {
                                          // Calculate total stock
                                          int totalStock = 0;
                                          for (var entry in product.warehouseStock!.entries) {
                                            final available = entry.value.available;
                                            final reserved = entry.value.reserved;
                                            totalStock += (available - reserved);
                                          }
                                          
                                          if (totalStock > 50) {
                                            return Colors.green;
                                          } else if (totalStock > 10) {
                                            return Colors.orange;
                                          } else if (totalStock > 0) {
                                            return Colors.red;
                                          } else {
                                            return Colors.grey;
                                          }
                                        }(),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Total: ${() {
                                        int totalStock = 0;
                                        for (var entry in product.warehouseStock!.entries) {
                                          final available = entry.value.available;
                                          final reserved = entry.value.reserved;
                                          totalStock += (available - reserved);
                                        }
                                        return totalStock;
                                      }()} units',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: () {
                                          // Calculate total stock
                                          int totalStock = 0;
                                          for (var entry in product.warehouseStock!.entries) {
                                            final available = entry.value.available;
                                            final reserved = entry.value.reserved;
                                            totalStock += (available - reserved);
                                          }
                                          
                                          if (totalStock > 50) {
                                            return Colors.green;
                                          } else if (totalStock > 10) {
                                            return Colors.orange;
                                          } else if (totalStock > 0) {
                                            return Colors.red;
                                          } else {
                                            return Colors.grey;
                                          }
                                        }(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...product.warehouseStock!.entries.map((entry) {
                                final warehouse = entry.key;
                                final stock = entry.value;
                                final available = stock.available;
                                final reserved = stock.reserved;
                                final totalStock = available - reserved;
                                
                                // Determine stock status color
                                Color stockColor;
                                String stockStatus;
                                if (totalStock > 20) {
                                  stockColor = Colors.green;
                                  stockStatus = 'In Stock';
                                } else if (totalStock > 5) {
                                  stockColor = Colors.orange;
                                  stockStatus = 'Low Stock';
                                } else if (totalStock > 0) {
                                  stockColor = Colors.red;
                                  stockStatus = 'Critical';
                                } else {
                                  stockColor = Colors.grey;
                                  stockStatus = 'Out of Stock';
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.brightness == Brightness.dark
                                              ? Colors.grey[800]
                                              : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          warehouse,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(
                                              totalStock > 0
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              size: 16,
                                              color: stockColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              stockStatus,
                                              style: TextStyle(
                                                color: stockColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '($totalStock available)',
                                              style: TextStyle(
                                                color: theme.brightness == Brightness.dark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 8),
                              Text(
                                'Stock levels are updated in real-time',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Quantity selector and Add to Cart
                      Row(
                        children: [
                          // Quantity selector
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _cartItemId != null && _quantity > 0
                                      ? () => _updateQuantity(_quantity - 1)
                                      : _quantity > 1
                                          ? () => setState(() => _quantity--)
                                          : null,
                                ),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    _quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _cartItemId != null 
                                      ? () => _updateQuantity(_quantity + 1)
                                      : () => setState(() => _quantity++),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Add to Cart button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await dbService.addToCart(
                                      widget.productId, _quantity);
                                  
                                  // Get the cart item ID for the newly added item
                                  final cartItems = await dbService.getCartItems().first;
                                  for (var item in cartItems) {
                                    if (item['product_id'] == widget.productId) {
                                      setState(() {
                                        _cartItemId = item['id'];
                                        _showNoteField = true;
                                      });
                                      
                                      // Restore preserved comment if exists
                                      if (_note.isNotEmpty) {
                                        await dbService.updateCartItem(
                                          item['id'],
                                          note: _note,
                                        );
                                        // Clear preserved comment after restoring
                                        await dbService.clearPreservedComment(widget.productId);
                                      }
                                      break;
                                    }
                                  }

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Added $_quantity ${product.sku ?? product.model} to cart'),
                                        backgroundColor: Colors.green,
                                        action: SnackBarAction(
                                          label: 'View Cart',
                                          textColor: Colors.white,
                                          onPressed: () => context.go('/cart'),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Error adding to cart: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                              label: const Text('Add to Cart'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                side: const BorderSide(color: Colors.blue),
                                foregroundColor: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Add Note button and field (shows after adding to cart)
                      if (_showNoteField) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Add Note'),
                                  content: TextField(
                                    controller: _noteController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      hintText: 'Add a note for this product...',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) => _note = value,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (_cartItemId != null) {
                                          await dbService.updateCartItem(
                                            _cartItemId!,
                                            note: _note,
                                          );
                                          Navigator.pop(dialogContext);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Note saved'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Save Note'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.note_add, color: Colors.green),
                            label: Text(_note.isEmpty ? 'Add Note' : 'Edit Note'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              side: const BorderSide(color: Colors.green),
                              foregroundColor: Colors.green,
                            ),
                          ),
                        ),
                        if (_note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.note, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _note,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      
                      const SizedBox(height: 32),

                      // Download PDF button
                      if (product.pdfUrl != null && product.pdfUrl!.isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                // Open PDF URL in browser
                                final uri = Uri.parse(product.pdfUrl!);
                                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                  throw 'Could not launch ${product.pdfUrl}';
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error opening PDF: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            label: const Text('Download Spec File'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Specifications
                      Text(
                        'Specifications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSpecSection(product),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right column: Images (75%) - full height
                        Expanded(
                          child: ProductDetailImages(
                            sku: product.sku ?? product.model,
                            imageUrl: product.imageUrl,
                            imageUrl2: product.imageUrl2,
                            thumbnailUrl: product.thumbnailUrl,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                } else {
                  // Mobile: Stack vertically with specs first, then images
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Product info and specifications first
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SKU and Category
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.sku ?? '',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.category,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Product name with Top Seller star for superadmins
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.displayName,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Top Seller toggle for superadmins only
                              Consumer(
                                builder: (context, ref, _) {
                                  final authState = ref.watch(authStateProvider);
                                  final isSuperAdmin = authState.value?.email == 'andres@turboairmexico.com';
                                  
                                  if (isSuperAdmin) {
                                    return IconButton(
                                      icon: Icon(
                                        product.isTopSeller ? Icons.star : Icons.star_border,
                                        color: product.isTopSeller ? Colors.amber : Colors.grey,
                                        size: 28,
                                      ),
                                      tooltip: product.isTopSeller ? 'Remove Top Seller' : 'Mark as Top Seller',
                                      onPressed: () async {
                                        try {
                                          final dbService = ref.read(databaseServiceProvider);
                                          await dbService.updateProduct(
                                            widget.productId,
                                            {'isTopSeller': !product.isTopSeller},
                                          );
                                          // Refresh the product data
                                          ref.invalidate(productDetailProvider(widget.productId));
                                          
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                product.isTopSeller
                                                    ? 'Removed from Top Sellers'
                                                    : 'Marked as Top Seller',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error updating product: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          }
                                        }
                                      },
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '\$',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                PriceFormatter.formatNumber(product.price),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Price may vary based on configuration',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),

                          // Warehouse Stock Information (Mobile)
                          if (product.warehouseStock != null && product.warehouseStock!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.blue.withOpacity(0.3)
                                      : Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.warehouse,
                                        size: 20,
                                        color: theme.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Stock Availability',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Total Stock Summary for Mobile
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: () {
                                            // Calculate total stock
                                            int totalStock = 0;
                                            for (var entry in product.warehouseStock!.entries) {
                                              final available = entry.value.available;
                                              final reserved = entry.value.reserved;
                                              totalStock += (available - reserved);
                                            }
                                            
                                            if (totalStock > 50) {
                                              return Colors.green.withOpacity(0.2);
                                            } else if (totalStock > 10) {
                                              return Colors.orange.withOpacity(0.2);
                                            } else if (totalStock > 0) {
                                              return Colors.red.withOpacity(0.2);
                                            } else {
                                              return Colors.grey.withOpacity(0.2);
                                            }
                                          }(),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: () {
                                              // Calculate total stock
                                              int totalStock = 0;
                                              for (var entry in product.warehouseStock!.entries) {
                                                final available = entry.value.available;
                                                final reserved = entry.value.reserved;
                                                totalStock += (available - reserved);
                                              }
                                              
                                              if (totalStock > 50) {
                                                return Colors.green;
                                              } else if (totalStock > 10) {
                                                return Colors.orange;
                                              } else if (totalStock > 0) {
                                                return Colors.red;
                                              } else {
                                                return Colors.grey;
                                              }
                                            }(),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${() {
                                            int totalStock = 0;
                                            for (var entry in product.warehouseStock!.entries) {
                                              final available = entry.value.available;
                                              final reserved = entry.value.reserved;
                                              totalStock += (available - reserved);
                                            }
                                            return totalStock;
                                          }()} total',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: () {
                                              // Calculate total stock
                                              int totalStock = 0;
                                              for (var entry in product.warehouseStock!.entries) {
                                                final available = entry.value.available;
                                                final reserved = entry.value.reserved;
                                                totalStock += (available - reserved);
                                              }
                                              
                                              if (totalStock > 50) {
                                                return Colors.green;
                                              } else if (totalStock > 10) {
                                                return Colors.orange;
                                              } else if (totalStock > 0) {
                                                return Colors.red;
                                              } else {
                                                return Colors.grey;
                                              }
                                            }(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...product.warehouseStock!.entries.map((entry) {
                                    final warehouse = entry.key;
                                    final stock = entry.value;
                                    final available = stock.available;
                                    final reserved = stock.reserved;
                                    final totalStock = available - reserved;
                                    
                                    // Determine stock status color
                                    Color stockColor;
                                    String stockStatus;
                                    if (totalStock > 20) {
                                      stockColor = Colors.green;
                                      stockStatus = 'In Stock';
                                    } else if (totalStock > 5) {
                                      stockColor = Colors.orange;
                                      stockStatus = 'Low Stock';
                                    } else if (totalStock > 0) {
                                      stockColor = Colors.red;
                                      stockStatus = 'Critical';
                                    } else {
                                      stockColor = Colors.grey;
                                      stockStatus = 'Out of Stock';
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.brightness == Brightness.dark
                                                  ? Colors.grey[800]
                                                  : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              warehouse,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  totalStock > 0
                                                      ? Icons.check_circle
                                                      : Icons.cancel,
                                                  size: 16,
                                                  color: stockColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  stockStatus,
                                                  style: TextStyle(
                                                    color: stockColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '($totalStock available)',
                                                  style: TextStyle(
                                                    color: theme.brightness == Brightness.dark
                                                        ? Colors.grey[400]
                                                        : Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Stock levels are updated in real-time',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Quantity selector and Add to Cart
                          Row(
                            children: [
                              // Quantity selector
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _cartItemId != null && _quantity > 0
                                          ? () => _updateQuantity(_quantity - 1)
                                          : _quantity > 1
                                              ? () => setState(() => _quantity--)
                                              : null,
                                    ),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        _quantity.toString(),
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _cartItemId != null 
                                          ? () => _updateQuantity(_quantity + 1)
                                          : () => setState(() => _quantity++),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Add to Cart button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await dbService.addToCart(
                                          widget.productId, _quantity);
                                      
                                      // Get the cart item ID for the newly added item
                                      final cartItems = await dbService.getCartItems().first;
                                      for (var item in cartItems) {
                                        if (item['product_id'] == widget.productId) {
                                          setState(() {
                                            _cartItemId = item['id'];
                                            _showNoteField = true;
                                          });
                                          
                                          // Restore preserved comment if exists
                                          if (_note.isNotEmpty) {
                                            await dbService.updateCartItem(
                                              item['id'],
                                              note: _note,
                                            );
                                            // Clear preserved comment after restoring
                                            await dbService.clearPreservedComment(widget.productId);
                                          }
                                          break;
                                        }
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Added $_quantity ${product.sku ?? product.model} to cart'),
                                            backgroundColor: Colors.green,
                                            action: SnackBarAction(
                                              label: 'View Cart',
                                              textColor: Colors.white,
                                              onPressed: () => context.go('/cart'),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error adding to cart: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.add_shopping_cart),
                                  label: const Text('Add to Cart'),
                                  style: ElevatedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Add Note button and field (shows after adding to cart)
                          if (_showNoteField) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Add Note'),
                                    content: TextField(
                                      controller: _noteController,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        hintText: 'Add a note for this product...',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) => _note = value,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          if (_cartItemId != null) {
                                            await dbService.updateCartItem(
                                              _cartItemId!,
                                              note: _note,
                                            );
                                            Navigator.pop(dialogContext);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Note saved'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('Save Note'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.note_add, color: Colors.green),
                              label: Text(
                                _note.isEmpty ? 'Add Note' : 'Edit Note',
                                style: const TextStyle(color: Colors.green),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              ),
                            ),
                            if (_note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.note, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _note,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          
                          const SizedBox(height: 32),

                          // Download PDF button
                          if (product.pdfUrl != null && product.pdfUrl!.isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    // Open PDF URL in browser
                                    final uri = Uri.parse(product.pdfUrl!);
                                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                      throw 'Could not launch ${product.pdfUrl}';
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error opening PDF: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                label: const Text('Download Spec File'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  side: const BorderSide(color: Colors.red),
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Specifications
                          Text(
                            'Specifications',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildSpecSection(product),
                          const SizedBox(height: 32),
                          
                          // Product Images section - placed below specifications
                          Text(
                            'Product Images',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Images widget - full viewport height for mobile
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: ProductDetailImages(
                              sku: product.sku ?? product.model,
                              imageUrl: product.imageUrl,
                              imageUrl2: product.imageUrl2,
                              thumbnailUrl: product.thumbnailUrl,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  );
                }
              },
            );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(productDetailProvider(widget.productId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanEncodingIssues(String text) {
    // Fix common UTF-8 encoding issues with degree symbols
    return text
        .replaceAll('Â°F', '°F')  // Fix Fahrenheit
        .replaceAll('Â°C', '°C')  // Fix Celsius
        .replaceAll('Â°', '°')    // Fix any other degree symbols
        .replaceAll('Â', '');      // Remove any remaining Â characters
  }

  Widget _buildSpecSection(Product product) {
    // Debug: Log all product fields
    AppLogger.debug('Product data', category: LogCategory.ui, data: {
      'SKU': product.sku,
      'Model': product.model,
      'Category': product.category,
      'Subcategory': product.subcategory,
      'ProductType': product.productType,
      'Voltage': product.voltage,
      'Amperage': product.amperage,
      'Phase': product.phase,
      'Frequency': product.frequency,
      'PlugType': product.plugType,
      'Dimensions': product.dimensions,
      'DimensionsMetric': product.dimensionsMetric,
      'Weight': product.weight,
      'WeightMetric': product.weightMetric,
      'TemperatureRange': product.temperatureRange,
      'TemperatureRangeMetric': product.temperatureRangeMetric,
      'Refrigerant': product.refrigerant,
      'Compressor': product.compressor,
      'Capacity': product.capacity,
      'Doors': product.doors,
      'Shelves': product.shelves,
      'Features': product.features,
      'Certifications': product.certifications,
    });
    
    final specs = <String, String?>{
      'Category': product.category,
      'Subcategory': product.subcategory,
      'Type': product.productType,
      'Voltage': product.voltage,
      'Amperage': product.amperage,
      'Phase': product.phase,
      'Frequency': product.frequency,
      'Plug Type': product.plugType,
      'Dimensions': product.dimensions,
      'Dimensions (Metric)': product.dimensionsMetric,
      'Weight': product.weight,
      'Weight (Metric)': product.weightMetric,
      'Temperature Range': product.temperatureRange,
      'Temperature Range (Metric)': product.temperatureRangeMetric,
      'Refrigerant': product.refrigerant,
      'Compressor': product.compressor,
      'Capacity': product.capacity,
      'Doors': product.doors?.toString(),
      'Shelves': product.shelves?.toString(),
      'Features': product.features,
      'Certifications': product.certifications,
    };

    final validSpecs = specs.entries.where((e) => e.value != null && e.value!.isNotEmpty).toList();

    if (validSpecs.isEmpty) {
      return const Text('No specifications available');
    }

    return Column(
      children: validSpecs.map((spec) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  spec.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _cleanEncodingIssues(spec.value!),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: spec.key == 'Features' || spec.key == 'Certifications' ? null : 2,
                  overflow: spec.key == 'Features' || spec.key == 'Certifications'
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
