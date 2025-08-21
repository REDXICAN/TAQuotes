// lib/features/products/presentation/screens/products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/product_image_helper_v3.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../../core/services/excel_upload_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/product_cache_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../widgets/excel_preview_dialog.dart';
import '../../widgets/zoomable_image_viewer.dart';

// Products provider using Firebase with offline cache
final productsProvider =
    FutureProvider.family<List<Product>, String?>((ref, category) async {
  // Try to get cached products first for faster loading
  try {
    // First try to get from cache for immediate display
    final cachedProducts = await ProductCacheService.instance.getCachedProducts(category: category);
    if (cachedProducts.isNotEmpty) {
      AppLogger.info('Using cached products', category: LogCategory.business, data: {'count': cachedProducts.length});
      // Still try to refresh from Firebase in background
      ProductCacheService.instance.cacheAllProducts().catchError((e) {
        AppLogger.error('Background cache refresh failed', error: e, category: LogCategory.business);
      });
      return cachedProducts;
    }
    
    // If no cache, fetch from Firebase
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
          // Filter by category if specified
          if (category == null || category.isEmpty) {
            products.add(product);
          } else {
            // Check if product category matches (case-insensitive and trim whitespace)
            final productCategory = product.category.trim().toLowerCase();
            final filterCategory = category.trim().toLowerCase();
            
            // Also check for partial matches (e.g., "Refrigeration" matches "REACH-IN REFRIGERATION")
            if (productCategory == filterCategory || 
                productCategory.contains(filterCategory) ||
                filterCategory.contains(productCategory)) {
              products.add(product);
            }
          }
        } catch (e) {
          AppLogger.error('Error parsing product $key', error: e, category: LogCategory.database);
        }
      });
    }
    
    // Log categories found for debugging
    if (products.isNotEmpty) {
      final uniqueCategories = products.map((p) => p.category).toSet().toList();
      AppLogger.info('Found categories in products: $uniqueCategories', category: LogCategory.database);
    }
    
    products.sort((a, b) => (a.sku ?? '').compareTo(b.sku ?? ''));
    return products;
  } catch (e) {
    AppLogger.error('Error loading products: $e', category: LogCategory.database);
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
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final searchResultsProvider = Provider<List<Product>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  
  if (query.isEmpty) return [];
  
  // Always search ALL products, not filtered by category
  final productsAsync = ref.watch(productsProvider(null));
  
  return productsAsync.when(
    data: (allProducts) {
      // Search in SKU, name, description, category, and model
      return allProducts.where((product) {
        final sku = (product.sku ?? '').toLowerCase();
        final model = (product.model ?? '').toLowerCase();
        final name = product.name.toLowerCase();
        final description = product.description.toLowerCase();
        final category = product.category.toLowerCase();
        
        // Check if query matches any field
        return sku.contains(query) ||
               model.contains(query) ||
               name.contains(query) ||
               description.contains(query) ||
               category.contains(query);
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

class _ProductsScreenState extends ConsumerState<ProductsScreen> with SingleTickerProviderStateMixin {
  String? selectedProductLine;
  Product? selectedProduct;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _detailsScrollController = ScrollController();
  final ScrollController _tabScrollController = ScrollController();
  bool _isSearching = false;
  bool _isUploading = false;
  bool _isTableView = false;
  int _visibleItemCount = 24; // Initial items to show
  TabController? _tabController;
  List<String> _productTypes = ['All'];
  String _selectedProductType = 'All';
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Tab controller will be initialized when product types are loaded
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      // Load more items when near bottom
      setState(() {
        _visibleItemCount += 24; // Load 24 more items
      });
    }
  }
  
  // Extract unique product lines from products
  Set<String> _getProductLines(List<Product> products) {
    final lines = <String>{};
    for (final product in products) {
      final sku = product.sku ?? product.model ?? '';
      if (sku.length >= 3) {
        // Get first 3 letters of SKU as product line
        final line = sku.substring(0, 3).toUpperCase();
        if (RegExp(r'^[A-Z]{3}$').hasMatch(line)) {
          lines.add(line);
        }
      }
    }
    return lines;
  }
  
  // Extract unique product types from products
  Set<String> _getProductTypes(List<Product> products) {
    final types = <String>{};
    for (final product in products) {
      if (product.productType != null && product.productType!.isNotEmpty) {
        types.add(product.productType!);
      }
    }
    return types;
  }
  
  // Extract unique categories from products
  Set<String> _getCategories(List<Product> products) {
    final categories = <String>{};
    for (final product in products) {
      if (product.category.isNotEmpty) {
        categories.add(product.category);
      }
    }
    return categories;
  }
  
  // Filter products by product type or category
  List<Product> _filterByProductType(List<Product> products, String type) {
    if (type == 'All') return products;
    
    // Check if it's a category filter instead of product type
    return products.where((product) {
      // First check if it matches a category
      if (product.category == type) return true;
      // Then check product type
      if (product.productType == type) return true;
      return false;
    }).toList();
  }
  
  // Filter products by product line
  List<Product> _filterByProductLine(List<Product> products, String? line) {
    if (line == null) return products;
    return products.where((product) {
      final sku = product.sku ?? product.model ?? '';
      return sku.toUpperCase().startsWith(line);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _detailsScrollController.dispose();
    _tabScrollController.dispose();
    _tabController?.dispose();
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

    // Get products based on category
    final productsAsync = ref.watch(productsProvider(null));

    // Check if current user is superadmin
    final isSuperAdmin = ExcelUploadService.isSuperAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: theme.primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black), // Make text black
              decoration: InputDecoration(
                hintText: 'Search by SKU, category or description',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[700]),
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

          // Filters Row (only show when not searching)
          if (!_isSearching)
            Container(
              height: ResponsiveHelper.isMobile(context) ? 50 : 55,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getValue(
                  context,
                  mobile: 12,
                  tablet: 16,
                  desktop: 20,
                ),
              ),
              child: Row(
                children: [
                  // Grid/Table Toggle Button - Hide on very small screens
                  if (!ResponsiveHelper.useCompactLayout(context)) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: Icon(
                          _isTableView ? Icons.grid_view : Icons.table_chart,
                          color: theme.primaryColor,
                          size: ResponsiveHelper.getIconSize(context),
                        ),
                        onPressed: () {
                          setState(() {
                            _isTableView = !_isTableView;
                          });
                        },
                        tooltip: _isTableView ? 'Grid View' : 'Table View',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          minimumSize: Size(
                            ResponsiveHelper.isMobile(context) ? 36 : 40,
                            ResponsiveHelper.isMobile(context) ? 36 : 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  // All Filter Button
                  FilterChip(
                    label: const Text('All'),
                    selected: selectedProductLine == null,
                    onSelected: (_) {
                      setState(() {
                        selectedProductLine = null;
                        _visibleItemCount = 24;
                      });
                      ref.invalidate(productsProvider);
                    },
                  ),
                  const SizedBox(width: 8),
                  
                  // Product Line Dropdown
                  productsAsync.when(
                    data: (allProducts) {
                      // Get all product lines without category filtering
                      final productLines = _getProductLines(allProducts).toList()..sort();
                      
                      if (productLines.isEmpty) return const SizedBox.shrink();
                      
                      return Container(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveHelper.getValue(
                            context,
                            mobile: 120,
                            tablet: 150,
                            desktop: 180,
                          ),
                        ),
                          child: PopupMenuButton<String?>(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedProductLine != null 
                                    ? theme.primaryColor.withOpacity(0.2)
                                    : theme.dividerColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selectedProductLine != null
                                      ? theme.primaryColor
                                      : theme.dividerColor,
                                  width: selectedProductLine != null ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    size: 18,
                                    color: selectedProductLine != null
                                        ? theme.primaryColor
                                        : null,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      selectedProductLine ?? 'Product Line',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.isMobile(context) ? 13 : 14,
                                        fontWeight: selectedProductLine != null
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ),
                            ),
                            onSelected: (value) {
                              setState(() {
                                selectedProductLine = value;
                                _visibleItemCount = 24; // Reset pagination
                              });
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String?>(
                                value: null,
                                child: Text('All Product Lines'),
                              ),
                              const PopupMenuDivider(),
                              ...productLines.map((line) => 
                                PopupMenuItem<String>(
                                  value: line,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          line,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${allProducts.where((p) => (p.sku ?? p.model ?? '').toUpperCase().startsWith(line)).length} products',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  
                  const Spacer(),
                  
                  // Clear/Reset button
                  if (selectedProductLine != null || _searchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: Icon(
                          Icons.clear_all,
                          color: theme.primaryColor,
                          size: ResponsiveHelper.getIconSize(context),
                        ),
                        onPressed: () {
                          setState(() {
                            selectedProductLine = null;
                            _isSearching = false;
                          });
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                        tooltip: 'Clear all filters',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          minimumSize: Size(
                            ResponsiveHelper.isMobile(context) ? 36 : 40,
                            ResponsiveHelper.isMobile(context) ? 36 : 40,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Products display - Split view for table/list, Grid for cards
          Expanded(
            child: _isSearching
                ? Consumer(
                    builder: (context, ref, child) {
                      final searchResults = ref.watch(searchResultsProvider);
                      if (searchResults.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products found for "${_searchController.text}"',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try searching by SKU, name, or category',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _isTableView 
                          ? _buildSplitView(searchResults) 
                          : _buildProductsGrid(searchResults);
                    },
                  )
                : productsAsync.when(
                    data: (products) {
                      // Apply category filter
                      List<Product> filteredProducts = _filterByProductType(products, _selectedProductType);
                      
                      // Then apply product line filter if selected
                      if (selectedProductLine != null) {
                        filteredProducts = _filterByProductLine(filteredProducts, selectedProductLine);
                      }
                      
                      if (filteredProducts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products found',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedProductLine != null
                                    ? 'No products for line "$selectedProductLine"'
                                    : 'Try adjusting your filters',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.disabledColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    selectedProductLine = null;
                                    _visibleItemCount = 24;
                                  });
                                },
                                child: const Text('Clear Filters'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return _isTableView 
                          ? _buildSplitView(filteredProducts) 
                          : _buildProductsGrid(filteredProducts);
                    },
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
                              ref.invalidate(productsProvider(null));
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
                        content: Text('${product.sku ?? product.model} removed from cart'),
                        duration: const Duration(seconds: 2),
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
            alignment: Alignment.center,
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
              size: ResponsiveHelper.getIconSize(context, baseSize: 80),
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching
                  ? 'No products found'
                  : 'No products in this category',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: theme.textTheme.headlineSmall!.fontSize! * ResponsiveHelper.getFontScale(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (_isSearching) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Try a different search term',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.disabledColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = ResponsiveHelper.getGridColumns(context);
        final isCompact = ResponsiveHelper.useCompactLayout(context);
        final screenWidth = MediaQuery.of(context).size.width;
        
        // Adjust aspect ratio based on screen size - shorter cards
        double childAspectRatio;
        if (ResponsiveHelper.isMobile(context)) {
          childAspectRatio = 0.55;  // Shorter cards for phones
        } else if (ResponsiveHelper.isTablet(context)) {
          childAspectRatio = 0.65;  // Shorter cards for tablets
        } else {
          childAspectRatio = 0.7;   // Shorter cards for desktop
        }
        
        // Minimal spacing to maximize card usage
        final spacing = ResponsiveHelper.getValue(
          context,
          mobile: 8.0,
          tablet: 10.0,
          desktop: 12.0,
        );
        
        // Limit visible items for better performance
        final itemsToShow = products.length > _visibleItemCount 
            ? products.sublist(0, _visibleItemCount.clamp(0, products.length))
            : products;
        
        return GridView.builder(
          controller: _scrollController,
          padding: ResponsiveHelper.getScreenPadding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: itemsToShow.length,
          cacheExtent: 200, // Cache items slightly off-screen
          itemBuilder: (context, index) {
            final product = itemsToShow[index];
            return ProductCard(
              key: ValueKey(product.id),
              product: product,
            );
          },
        );
      },
    );
  }
  
  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(2).split('.');
    final wholePart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '\$$wholePart.${parts[1]}';
  }
  
  // Compact quantity selector for list view
  Widget _buildCompactQuantitySelector(Product product, WidgetRef ref, BuildContext context, ThemeData theme, dynamic dbService) {
    final quantities = ref.watch(productQuantitiesProvider);
    final quantity = quantities[product.id] ?? 0;
    final quantityNotifier = ref.read(productQuantitiesProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor, width: 0.5),
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
                } catch (e) {
                  // Handle error silently
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.remove,
                size: 14,
                color: quantity > 0 ? theme.primaryColor : theme.disabledColor,
              ),
            ),
          ),
          // Quantity display
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text(
              quantity.toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          // Plus button
          InkWell(
            onTap: () async {
              quantityNotifier.increment(product.id ?? '');
              final newQuantity = quantity + 1;
              
              try {
                await dbService.addToCart(product.id ?? '', newQuantity);
              } catch (e) {
                // Handle error silently
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.add,
                size: 14,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Split view with product list on left and details on right
  Widget _buildSplitView(List<Product> products) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }
    
    // For mobile and tablet, use a different layout
    if (isMobile || isTablet) {
      return _buildProductsTable(products);
    }
    
    // Auto-select first product if none selected
    if (selectedProduct == null && products.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          selectedProduct = products.first;
        });
      });
    }
    
    return Row(
      children: [
        // Left side - Product List (25% on desktop)
        Container(
          width: screenWidth * 0.25,
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(
              right: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // List header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.list, size: 20, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Products (${products.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Product list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = selectedProduct?.id == product.id;
                    
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedProduct = product;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected 
                                  ? theme.primaryColor 
                                  : Colors.transparent,
                              width: 3,
                            ),
                            bottom: BorderSide(
                              color: theme.dividerColor.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.sku ?? product.model,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected 
                                    ? theme.primaryColor 
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatPrice(product.price),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                                // Compact quantity selector
                                SizedBox(
                                  width: 100,
                                  height: 28,
                                  child: _buildCompactQuantitySelector(
                                    product,
                                    ref,
                                    context,
                                    theme,
                                    ref.read(databaseServiceProvider),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Right side - Product Details (80%)
        Expanded(
          child: selectedProduct != null
              ? _buildProductDetailsPanel(selectedProduct!)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 100,
                        color: theme.disabledColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a product to view details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
  
  // Product details panel for split view
  Widget _buildProductDetailsPanel(Product product) {
    final theme = Theme.of(context);
    final imagePath = ProductImageHelperV3.getImagePathWithFallback(
      product.sku ?? product.model ?? '',
    );
    
    return SingleChildScrollView(
      controller: _detailsScrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with SKU and Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.sku ?? product.model,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.displayName,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatPrice(product.price),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Product Images - Show P.1 and P.2
          _buildProductImagesSection(product, theme),
          const SizedBox(height: 24),
          
          // Specifications
          Text(
            'Specifications',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Specs grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                _buildSpecRow('Category', product.category),
                if (product.subcategory != null && product.subcategory!.isNotEmpty)
                  _buildSpecRow('Subcategory', product.subcategory!),
                _buildSpecRow('Description', product.description),
                if (product.dimensions != null && product.dimensions!.isNotEmpty)
                  _buildSpecRow('Dimensions', product.dimensions!),
                if (product.weight != null && product.weight!.isNotEmpty)
                  _buildSpecRow('Weight', product.weight!),
                if (product.voltage != null && product.voltage!.isNotEmpty)
                  _buildSpecRow('Voltage', product.voltage!),
                if (product.amperage != null && product.amperage!.isNotEmpty)
                  _buildSpecRow('Amperage', product.amperage!),
                if (product.phase != null && product.phase!.isNotEmpty)
                  _buildSpecRow('Phase', product.phase!),
                if (product.frequency != null && product.frequency!.isNotEmpty)
                  _buildSpecRow('Frequency', product.frequency!),
                if (product.plugType != null && product.plugType!.isNotEmpty)
                  _buildSpecRow('Plug Type', product.plugType!),
                if (product.temperatureRange != null && product.temperatureRange!.isNotEmpty)
                  _buildSpecRow('Temperature Range', product.temperatureRange!),
                if (product.refrigerant != null && product.refrigerant!.isNotEmpty)
                  _buildSpecRow('Refrigerant', product.refrigerant!),
                if (product.compressor != null && product.compressor!.isNotEmpty)
                  _buildSpecRow('Compressor', product.compressor!),
                if (product.capacity != null && product.capacity!.isNotEmpty)
                  _buildSpecRow('Capacity', product.capacity!),
                if (product.doors != null && product.doors! > 0)
                  _buildSpecRow('Doors', product.doors.toString()),
                if (product.shelves != null && product.shelves! > 0)
                  _buildSpecRow('Shelves', product.shelves.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductImagesSection(Product product, ThemeData theme) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final imagePath1 = ProductImageHelperV3.getImagePathWithFallback(product.sku ?? product.model ?? '');
    
    // Generate multiple image paths (P.1, P.2, P.3, P.4)
    final sku = product.sku ?? product.model ?? '';
    final imagePath2 = 'assets/screenshots/$sku/$sku P.2.png';
    final List<String> imagePaths = [
      imagePath1,
      imagePath2,
      'assets/screenshots/$sku/$sku P.3.png',
      'assets/screenshots/$sku/$sku P.4.png',
    ];
    
    // Function to open zoomable viewer
    void openImageViewer(int initialIndex) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        builder: (context) => ZoomableImageViewer(
          imagePaths: imagePaths,
          initialIndex: initialIndex,
          productName: '${product.sku ?? product.model} - ${product.displayName}',
        ),
      );
    }
    
    // For mobile, use PageView for slider
    if (isMobile) {
      final PageController pageController = PageController();
      
      return Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            PageView(
              controller: pageController,
              children: [
            // Page 1
            GestureDetector(
              onTap: () => openImageViewer(0),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Center(
                            child: Image.asset(
                              imagePath1,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/logos/turbo_air_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_not_supported,
                                  size: 100,
                                  color: theme.disabledColor,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Page 1', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            // Page 2
            GestureDetector(
              onTap: () => openImageViewer(1),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Center(
                            child: Image.asset(
                              imagePath2,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 60,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Page 2 not available',
                                style: TextStyle(
                                  color: theme.disabledColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Page 2', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
            // Page indicators
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // For desktop and tablet, show side by side
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
        maxWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // P.1 Image
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Page 1',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => openImageViewer(0),
                      child: Stack(
                        children: [
                          Center(
                            child: Image.asset(
                              imagePath1,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/logos/turbo_air_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_not_supported,
                                  size: 100,
                                  color: theme.disabledColor,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Container(
            width: 1,
            color: theme.dividerColor,
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
          // P.2 Image
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Page 2',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Image.asset(
                      imagePath2,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 80,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Page 2 not available',
                                style: TextStyle(
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
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
            DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: products.map((product) {
            // Use thumbnail for table view (compressed, fast loading)
            final imagePath = ProductImageHelperV3.getThumbnailPath(product.sku ?? product.model ?? '');
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
                DataCell(
                  Text(
                    _formatPrice(product.price),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
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
                      IconButton(
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        onPressed: () async {
                          final dbService = ref.read(databaseServiceProvider);
                          try {
                            await dbService.addToCart(product.id ?? '', 1);
                            if (context.mounted) {
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
                        tooltip: 'Add to Cart',
                      ),
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
                        content: Text('${product.sku ?? product.model} removed from cart'),
                        duration: const Duration(seconds: 2),
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
            alignment: Alignment.center,
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
    final dbService = ref.read(databaseServiceProvider);
    final isCompact = ResponsiveHelper.useCompactLayout(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final fontScale = ResponsiveHelper.getFontScale(context);

    // Format price with commas
    String formatPrice(double price) {
      final parts = price.toStringAsFixed(2).split('.');
      final wholePart = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '\$$wholePart.${parts[1]}';
    }

    return Card(
      elevation: ResponsiveHelper.getValue(context, mobile: 1, tablet: 2, desktop: 2),
      child: InkWell(
        onTap: () {
          context.push('/products/${product.id}');
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            AspectRatio(
              aspectRatio: isMobile ? 1.2 : 1.0, // More rectangular on mobile
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF), // Pure white background for images
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ProductImageWidget(
                    sku: product.sku ?? product.model ?? '',
                    useThumbnail: true,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            // Product Info - Compact with larger text
            Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.sku ?? product.model,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.displayName,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 12,
                      height: 1.2,
                    ),
                    maxLines: isMobile ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Price and Quantity Selector
                  if (isMobile)
                    // Mobile layout - stacked
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatPrice(product.price),
                          style: TextStyle(
                            fontSize: 20,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: _buildQuantitySelector(product, ref, context, theme, dbService),
                        ),
                      ],
                    )
                  else
                    // Desktop/Tablet - side by side
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            formatPrice(product.price),
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildQuantitySelector(product, ref, context, theme, dbService),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
