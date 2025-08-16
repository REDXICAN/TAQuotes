// lib/features/products/presentation/screens/products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/product_image_helper_v2.dart' as ImageHelper;
import '../../../../core/services/excel_upload_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../widgets/excel_preview_dialog.dart';

// Products provider using Firebase directly
final productsProvider =
    FutureProvider.family<List<Product>, String?>((ref, category) async {
  // Products don't require authentication (public read access)
  try {
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('products').get();
    
    final List<Product> products = [];
    if (snapshot.exists && snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
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
  } catch (e) {
    AppLogger.error('Error loading products', error: e, category: LogCategory.database);
    return [];
  }
});

// Cart quantities provider to track quantity for each product
final productQuantitiesProvider = StateNotifierProvider<ProductQuantitiesNotifier, Map<String, int>>((ref) {
  return ProductQuantitiesNotifier();
});

class ProductQuantitiesNotifier extends StateNotifier<Map<String, int>> {
  ProductQuantitiesNotifier() : super({});

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      state = {...state}..remove(productId);
    } else {
      state = {...state, productId: quantity};
    }
  }

  int getQuantity(String productId) {
    return state[productId] ?? 0;
  }

  void increment(String productId) {
    final current = getQuantity(productId);
    setQuantity(productId, current + 1);
  }

  void decrement(String productId) {
    final current = getQuantity(productId);
    if (current > 0) {
      setQuantity(productId, current - 1);
    }
  }
}

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
  bool _isTableView = false;

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
                  // Grid/Table Toggle Button
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      icon: Icon(
                        _isTableView ? Icons.grid_view : Icons.table_chart,
                        color: theme.primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isTableView = !_isTableView;
                        });
                      },
                      tooltip: _isTableView ? 'Grid View' : 'Table View',
                      style: IconButton.styleFrom(
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 30,
                    color: theme.dividerColor,
                    margin: const EdgeInsets.only(right: 12),
                  ),
                  // All Filter
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

          // Products Grid or Table
          Expanded(
            child: _isSearching
                ? (_isTableView ? _buildProductsTable(searchResults ?? []) : _buildProductsGrid(searchResults ?? []))
                : productsAsync.when(
                    data: (products) => _isTableView ? _buildProductsTable(products) : _buildProductsGrid(products),
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

  Widget _buildQuantitySelector(Product product, WidgetRef ref, BuildContext context, ThemeData theme, dynamic dbService) {
    final quantities = ref.watch(productQuantitiesProvider);
    final quantity = quantities[product.id] ?? 0;
    final quantityNotifier = ref.read(productQuantitiesProvider.notifier);
    final textController = TextEditingController(text: quantity.toString());

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button
          InkWell(
            onTap: () async {
              if (quantity > 0) {
                quantityNotifier.decrement(product.id ?? '');
                try {
                  await dbService.addToCart(product.id ?? '', quantity - 1);
                  if (context.mounted && quantity == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.displayName} removed from cart'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating cart: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.remove,
                size: 16,
                color: quantity > 0 ? theme.primaryColor : theme.disabledColor,
              ),
            ),
          ),
          // Quantity input
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: textController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) async {
                final newQuantity = int.tryParse(value) ?? 0;
                quantityNotifier.setQuantity(product.id ?? '', newQuantity);
                
                if (newQuantity > 0) {
                  try {
                    await dbService.addToCart(product.id ?? '', newQuantity);
                    if (context.mounted && newQuantity > quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.displayName} quantity updated'),
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
                          content: Text('Error updating cart: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (quantity > 0) {
                  // Remove from cart if quantity is 0
                  try {
                    await dbService.addToCart(product.id ?? '', 0);
                  } catch (e) {
                    // Handle error silently
                  }
                }
              },
            ),
          ),
          // Plus button
          InkWell(
            onTap: () async {
              quantityNotifier.increment(product.id ?? '');
              final newQuantity = quantity + 1;
              
              try {
                await dbService.addToCart(product.id ?? '', newQuantity);
                if (context.mounted && quantity == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.sku ?? product.model} added to cart'),
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
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.add,
                size: 16,
                color: theme.primaryColor,
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
        // Responsive columns: 6 for desktop, 5 for tablet, 2 for phone
        final crossAxisCount = constraints.maxWidth > 900 ? 6 : 
                              constraints.maxWidth > 600 ? 5 : 2;
        // Portrait aspect ratio for cards (like paper sheet)
        final childAspectRatio = constraints.maxWidth > 600 ? 0.65 : 0.7;
        
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
  
  Widget _buildProductsTable(List<Product> products) {
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
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 30,
          headingRowColor: WidgetStateProperty.all(theme.primaryColor.withOpacity(0.1)),
          columns: const [
            DataColumn(label: Text('Image', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: products.map((product) {
            final imagePath = ImageHelper.ProductImageHelper.getImagePath(product.sku ?? product.model);
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/logos/turbo_air_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    product.sku ?? product.model,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      product.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(product.category)),
                DataCell(
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                DataCell(Text(product.stock.toString())),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () {
                          context.push('/products/${product.id}');
                        },
                        tooltip: 'View Details',
                      ),
                      const SizedBox(width: 8),
                      _buildQuantitySelector(product, ref, context, theme, ref.read(databaseServiceProvider)),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

}

class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  Widget _buildQuantitySelector(Product product, WidgetRef ref, BuildContext context, ThemeData theme, dynamic dbService) {
    final quantities = ref.watch(productQuantitiesProvider);
    final quantity = quantities[product.id] ?? 0;
    final quantityNotifier = ref.read(productQuantitiesProvider.notifier);
    final textController = TextEditingController(text: quantity.toString());

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button
          InkWell(
            onTap: () async {
              if (quantity > 0) {
                quantityNotifier.decrement(product.id ?? '');
                try {
                  await dbService.addToCart(product.id ?? '', quantity - 1);
                  if (context.mounted && quantity == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.displayName} removed from cart'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating cart: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.remove,
                size: 16,
                color: quantity > 0 ? theme.primaryColor : theme.disabledColor,
              ),
            ),
          ),
          // Quantity input
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: textController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) async {
                final newQuantity = int.tryParse(value) ?? 0;
                quantityNotifier.setQuantity(product.id ?? '', newQuantity);
                
                if (newQuantity > 0) {
                  try {
                    await dbService.addToCart(product.id ?? '', newQuantity);
                    if (context.mounted && newQuantity > quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.displayName} quantity updated'),
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
                          content: Text('Error updating cart: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (quantity > 0) {
                  // Remove from cart if quantity is 0
                  try {
                    await dbService.addToCart(product.id ?? '', 0);
                  } catch (e) {
                    // Handle error silently
                  }
                }
              },
            ),
          ),
          // Plus button
          InkWell(
            onTap: () async {
              quantityNotifier.increment(product.id ?? '');
              final newQuantity = quantity + 1;
              
              try {
                await dbService.addToCart(product.id ?? '', newQuantity);
                if (context.mounted && quantity == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.sku ?? product.model} added to cart'),
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
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.add,
                size: 16,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final imagePath = ImageHelper.ProductImageHelper.getImagePath(product.sku ?? product.model);
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
            // Product Image - Portrait orientation, covering most of column
            Expanded(
              flex: 4,
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
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/logos/turbo_air_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Product Info - More compact but readable
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.sku ?? product.model,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.displayName,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Price and Quantity Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Quantity Selector
                        _buildQuantitySelector(product, ref, context, theme, dbService),
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
