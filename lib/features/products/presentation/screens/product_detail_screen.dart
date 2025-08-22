// lib/features/products/presentation/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

                      // Product name
                      Text(
                        product.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                                  onPressed: _quantity > 1
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
                                  onPressed: () => setState(() => _quantity++),
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
                      const SizedBox(height: 32),

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

                          // Product name
                          Text(
                            product.displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                                      onPressed: _quantity > 1
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
                                      onPressed: () => setState(() => _quantity++),
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
                          const SizedBox(height: 32),

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

  Widget _buildSpecSection(Product product) {
    // Debug: Print all product fields to console
    print('=== PRODUCT DATA DEBUG ===');
    print('SKU: ${product.sku}');
    print('Model: ${product.model}');
    print('Category: ${product.category}');
    print('Subcategory: ${product.subcategory}');
    print('ProductType: ${product.productType}');
    print('Voltage: ${product.voltage}');
    print('Amperage: ${product.amperage}');
    print('Phase: ${product.phase}');
    print('Frequency: ${product.frequency}');
    print('Plug Type: ${product.plugType}');
    print('Dimensions: ${product.dimensions}');
    print('Dimensions Metric: ${product.dimensionsMetric}');
    print('Weight: ${product.weight}');
    print('Weight Metric: ${product.weightMetric}');
    print('Temperature Range: ${product.temperatureRange}');
    print('Temperature Range Metric: ${product.temperatureRangeMetric}');
    print('Refrigerant: ${product.refrigerant}');
    print('Compressor: ${product.compressor}');
    print('Capacity: ${product.capacity}');
    print('Doors: ${product.doors}');
    print('Shelves: ${product.shelves}');
    print('Features: ${product.features}');
    print('Certifications: ${product.certifications}');
    print('========================');
    
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
                  spec.value!,
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
