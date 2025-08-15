// lib/features/products/presentation/screens/products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/product_image_helper.dart';
import '../../../../core/services/excel_upload_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../widgets/excel_preview_dialog.dart';

// Products provider using Firebase directly
final productsProvider =
    StreamProvider.family<List<Product>, String?>((ref, category) {
  final database = FirebaseDatabase.instance;
  
  return database.ref('products').onValue.map((event) {
    final List<Product> products = [];
    if (event.snapshot.value != null) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      data.forEach((key, value) {
        final productMap = Map<String, dynamic>.from(value);
        productMap['id'] = key;
        try {
          final product = Product.fromMap(productMap);
          if (category == null || category.isEmpty || product.category == category) {
            products.add(product);
          }
        } catch (e) {
          AppLogger.error('Error parsing product $key', error: e, category: LogCategory.database);
        }
      });
    }
    products.sort((a, b) => (a.sku ?? '').compareTo(b.sku ?? ''));
    return products;
  });
});

// Search provider
final searchQueryProvider = StateProvider<String>((ref) => '');
final searchResultsProvider = Provider<List<Product>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final productsAsync = ref.watch(productsProvider(null));
  
  if (query.isEmpty) return [];
  
  return productsAsync.when(
    data: (products) {
      return products.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) ||
               product.description.toLowerCase().contains(query.toLowerCase()) ||
               product.category.toLowerCase().contains(query.toLowerCase());
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String? selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleExcelUpload() async {
    try {
      setState(() => _isUploading = true);
      
      // Pick Excel file with better error handling
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls'],
          withData: true,
        );
      } catch (e) {
        AppLogger.error('FilePicker error', error: e, category: LogCategory.excel);
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to pick file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (result != null && result.files.single.bytes != null) {
        // Show progress dialog for parsing
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Reading Excel file...'),
                ],
              ),
            ),
          );
        }

        // Preview Excel
        final previewResult = await ExcelUploadService.previewExcel(
          result.files.single.bytes!,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close progress dialog
          
          if (previewResult['success'] == true) {
            // Show preview dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => ExcelPreviewDialog(
                previewData: previewResult,
                onConfirm: (products, clearExisting) async {
                  // Show upload progress
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      content: Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 20),
                          Text('Uploading ${products.length} products...'),
                        ],
                      ),
                    ),
                  );
                  
                  // Save products
                  final saveResult = await ExcelUploadService.saveProducts(
                    products,
                    clearExisting: clearExisting,
                  );
                  
                  if (mounted && context.mounted) {
                    Navigator.of(context).pop(); // Close progress dialog
                    
                    // Refresh products list
                    ref.invalidate(productsProvider);
                    
                    // Show result dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          saveResult['success'] == true 
                              ? 'Upload Successful' 
                              : 'Upload Failed',
                          style: TextStyle(
                            color: saveResult['success'] == true 
                                ? Colors.green 
                                : Colors.red,
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(saveResult['message'] ?? ''),
                            if (saveResult['success'] == true) ...[
                              const SizedBox(height: 8),
                              Text('Total Products: ${saveResult['totalProducts']}'),
                              Text('Successfully Saved: ${saveResult['successCount']}'),
                              if (saveResult['errorCount'] > 0) ...[
                                Text(
                                  'Errors: ${saveResult['errorCount']}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 8),
                                if (saveResult['errors'] != null && 
                                    (saveResult['errors'] as List).isNotEmpty)
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ListView.builder(
                                      itemCount: (saveResult['errors'] as List).length,
                                      itemBuilder: (context, index) => Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          saveResult['errors'][index],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            );
          } else {
            // Show error dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Failed to Read Excel'),
                content: Text(
                  previewResult['message'] ?? 'Failed to parse Excel file',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('Excel upload error', error: e, category: LogCategory.excel);
      if (mounted && context.mounted) {
        // Try to close any open dialogs
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get products based on search or category
    final searchResults = _isSearching ? ref.watch(searchResultsProvider) : null;
    final productsAsync = ref.watch(productsProvider(selectedCategory));

    // Check if current user is superadmin
    final isSuperAdmin = ExcelUploadService.isSuperAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      floatingActionButton: isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: _isUploading ? null : _handleExcelUpload,
              backgroundColor: theme.primaryColor,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Excel'),
              tooltip: 'Upload products from Excel file',
            )
          : null,
      body: Column(
        children: [
          // Search Bar
          Container(
            color: theme.primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by SKU, category or description',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          setState(() => _isSearching = false);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
                setState(() => _isSearching = value.isNotEmpty);
              },
            ),
          ),

          // Category Filter (only show when not searching)
          if (!_isSearching)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: selectedCategory == null,
                      onSelected: (_) {
                        setState(() => selectedCategory = null);
                      },
                    ),
                  ),
                  ...AppConfig.categories.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          '${entry.value.icon} ${entry.key.length > 15 ? '${entry.key.substring(0, 15)}...' : entry.key}',
                        ),
                        selected: selectedCategory == entry.key,
                        onSelected: (_) {
                          setState(() => selectedCategory = entry.key);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Products Grid
          Expanded(
            child: _isSearching
                ? _buildProductsGrid(searchResults ?? [])
                : productsAsync.when(
                    data: (products) => _buildProductsGrid(products),
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text('Error loading products: $error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref.invalidate(productsProvider(selectedCategory));
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<Product> products) {
    final theme = Theme.of(context);
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching
                  ? Icons.search_off
                  : Icons.inventory_2_outlined,
              size: 80,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching
                  ? 'No products found'
                  : 'No products in this category',
              style: theme.textTheme.headlineSmall,
            ),
            if (_isSearching) ...[
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns: 4 for desktop/tablet, 2 for phone
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        // Shorter cards with adjusted aspect ratio
        final childAspectRatio = constraints.maxWidth > 600 ? 0.85 : 0.8;
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(product: product);
          },
        );
      },
    );
  }
}

class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final imagePath = ProductImageHelper.getImagePath(product.sku ?? product.model);
    final dbService = ref.read(databaseServiceProvider);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push('/products/${product.id}');
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image - Made smaller
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.disabledColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Product Info - More compact
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.sku ?? product.model,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.displayName,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: const Icon(Icons.add_shopping_cart),
                            onPressed: () async {
                            try {
                              await dbService.addToCart(product.id ?? '', 1);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${product.displayName} added to cart'),
                                    action: SnackBarAction(
                                      label: 'View Cart',
                                      onPressed: () {
                                        context.go('/cart');
                                      },
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error adding to cart: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                            },
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
