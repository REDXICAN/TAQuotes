// lib/features/products/presentation/screens/products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/product_image_helper.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/widgets/simple_image_widget.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/services/excel_upload_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/product_cache_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../widgets/excel_preview_dialog.dart';
import '../../widgets/zoomable_image_viewer.dart';

// Products provider using StreamProvider for real-time updates without heavy caching
final productsProvider =
    StreamProvider.family<List<Product>, String?>((ref, category) {
  try {
    final database = FirebaseDatabase.instance;
    
    // Keep Firebase persistence synced for faster initial load
    database.ref('products').keepSynced(true);
    
    // Return a stream that listens to products changes
    return database.ref('products').onValue.map((event) {
      final List<Product> products = [];
      
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        data.forEach((key, value) {
          final productMap = Map<String, dynamic>.from(value);
          productMap['id'] = key;
          try {
            final product = Product.fromMap(productMap);
            // Filter by category if specified
            if (category == null || category.isEmpty) {
              products.add(product);
            } else {
              // Check if product category matches
              final productCategory = product.category.trim().toLowerCase();
              final filterCategory = category.trim().toLowerCase();
              
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
      
      // Sort products: By total stock quantity (highest first), then top sellers, then by SKU
      products.sort((a, b) {
        // Calculate total stock for both products
        int getTotalStock(Product product) {
          if (product.warehouseStock == null || product.warehouseStock!.isEmpty) {
            return 0;
          }
          int total = 0;
          for (var entry in product.warehouseStock!.entries) {
            final available = entry.value.available;
            final reserved = entry.value.reserved;
            total += (available - reserved);
          }
          return total;
        }

        final totalStockA = getTotalStock(a);
        final totalStockB = getTotalStock(b);

        // First sort by total stock (highest first)
        if (totalStockA != totalStockB) {
          return totalStockB.compareTo(totalStockA);
        }

        // Then sort by isTopSeller (true comes before false)
        if (a.isTopSeller != b.isTopSeller) {
          return a.isTopSeller ? -1 : 1;
        }

        // Finally sort by SKU
        return (a.sku ?? '').compareTo(b.sku ?? '');
      });
      return products;
    });
  } catch (e) {
    AppLogger.error('Error streaming products: $e', category: LogCategory.database);
    return Stream.value([]);
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
final selectedWarehouseProvider = StateProvider<String?>((ref) => null);

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
  final ScrollController _tabScrollController = ScrollController();
  bool _isSearching = false;
  bool _isUploading = false;
  int _visibleItemCount = 24; // Show 24 items initially on web
  TabController? _tabController;
  List<String> _productTypes = ['All'];
  String _selectedProductType = 'All';
  String? _selectedWarehouse; // Warehouse filter state
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Tab controller will be initialized when product types are loaded
    
    // Set initial visible count based on platform
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final isVerticalScreen = screenHeight > screenWidth && screenWidth >= 1000 && screenWidth <= 1100;
      
      setState(() {
        if (isVerticalScreen) {
          _visibleItemCount = 35; // Show 35 products on vertical 1080x1920 screens
        } else {
          _visibleItemCount = screenWidth > 1200 ? 24 : 12; // 24 for desktop, 12 for mobile/tablet
        }
      });
    });
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      // Load more items when near bottom
      setState(() {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isVerticalScreen = screenHeight > screenWidth && screenWidth >= 1000 && screenWidth <= 1100;
        
        final increment = isVerticalScreen ? 35 : (screenWidth > 1200 ? 24 : 12);
        _visibleItemCount += increment;
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

  // Filter products by warehouse availability
  List<Product> _filterByWarehouse(List<Product> products, String? warehouse) {
    if (warehouse == null) return products;
    return products.where((product) {
      // Check if product has stock in the selected warehouse
      if (product.warehouseStock == null || product.warehouseStock!.isEmpty) {
        return false; // No stock data means not available
      }
      final warehouseStock = product.warehouseStock![warehouse];
      if (warehouseStock == null) return false;

      // Check if there's available stock (available - reserved > 0)
      final availableStock = warehouseStock.available - warehouseStock.reserved;
      return availableStock > 0;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
              backgroundColor: Theme.of(context).colorScheme.error,
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
      appBar: const AppBarWithClient(
        title: 'Products',
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: theme.appBarTheme.backgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search by SKU, category or description',
                hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.7),
                ),
                prefixIcon: Icon(Icons.search, 
                  color: theme.colorScheme.onPrimary.withOpacity(0.7)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, 
                          color: theme.colorScheme.onPrimary.withOpacity(0.7)),
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
                  // All Filter Button
                  FilterChip(
                    label: const Text('All'),
                    selected: selectedProductLine == null,
                    onSelected: (_) {
                      setState(() {
                        selectedProductLine = null;
                        final screenWidth = MediaQuery.of(context).size.width;
                        _visibleItemCount = screenWidth > 1200 ? 24 : 12;
                      });
                      ref.invalidate(productsProvider);
                    },
                  ),
                  const SizedBox(width: 8),

                  // Warehouse Filter Dropdown
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveHelper.getValue(
                        context,
                        mobile: 130,
                        tablet: 160,
                        desktop: 190,
                      ),
                    ),
                    child: PopupMenuButton<String?>(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedWarehouse != null
                              ? theme.primaryColor.withOpacity(0.2)
                              : theme.dividerColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedWarehouse != null
                                ? theme.primaryColor
                                : theme.dividerColor,
                            width: _selectedWarehouse != null ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warehouse,
                              size: 18,
                              color: _selectedWarehouse != null
                                  ? theme.primaryColor
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _selectedWarehouse ?? 'Warehouse',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.isMobile(context) ? 13 : 14,
                                  fontWeight: _selectedWarehouse != null
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
                          _selectedWarehouse = value;
                          final screenWidth = MediaQuery.of(context).size.width;
                          _visibleItemCount = screenWidth > 1200 ? 24 : 12;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('All Warehouses'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'CA1',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('CA1'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: '999',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('999'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'CA',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('CA'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'CA2',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('CA2'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'CA3',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('CA3'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'CA4',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('CA4'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'COCZ',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('COCZ'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'COPZ',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('COPZ'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'INT',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('INT'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'MEE',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('MEE'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'PU',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('PU'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'SI',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('SI'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'XCA',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('XCA'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'XPU',
                          child: Row(
                            children: [
                              Icon(Icons.warehouse, size: 16),
                              SizedBox(width: 8),
                              Text('XPU'),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                                final screenWidth = MediaQuery.of(context).size.width;
                                _visibleItemCount = screenWidth > 1200 ? 24 : 12; // Reset pagination
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
                  if (selectedProductLine != null || _selectedWarehouse != null || _searchController.text.isNotEmpty)
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
                            _selectedWarehouse = null;
                            _isSearching = false;
                          });
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                        tooltip: 'Clear all filters',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          minimumSize: Size(
                            ResponsiveHelper.getTouchTargetSize(context),
                            ResponsiveHelper.getTouchTargetSize(context),
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
                      return _buildProductsGrid(searchResults);
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

                      // Apply warehouse filter if selected
                      if (_selectedWarehouse != null) {
                        filteredProducts = _filterByWarehouse(filteredProducts, _selectedWarehouse);
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
                                    _selectedWarehouse = null;
                                    final screenWidth = MediaQuery.of(context).size.width;
                                    _visibleItemCount = screenWidth > 1200 ? 24 : 12;
                                  });
                                },
                                child: const Text('Clear Filters'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return _buildProductsGrid(filteredProducts);
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                        backgroundColor: Theme.of(context).colorScheme.error,
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
            width: ResponsiveHelper.isVerticalDisplay(context) ? 50 : 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Center(
              child: TextField(
                controller: textController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontSize: ResponsiveHelper.isVerticalDisplay(context) ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
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
                          backgroundColor: Theme.of(context).colorScheme.error,
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
                      backgroundColor: Theme.of(context).colorScheme.error,
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
        
        // Adjust aspect ratio based on screen size - taller cards for vertical
        double childAspectRatio;
        if (ResponsiveHelper.isVerticalDisplay(context)) {
          childAspectRatio = 0.52;  // Taller cards to prevent overlap on vertical screens
        } else if (ResponsiveHelper.isMobile(context)) {
          childAspectRatio = 0.55;  // Shorter cards for phones
        } else if (ResponsiveHelper.isTablet(context)) {
          childAspectRatio = 0.65;  // Shorter cards for tablets
        } else {
          childAspectRatio = 0.7;   // Shorter cards for desktop
        }
        
        // Increased spacing for vertical screens to prevent overlap
        final spacing = ResponsiveHelper.isVerticalDisplay(context) 
            ? 20.0  // More space between rows for vertical screens
            : ResponsiveHelper.getValue(
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
          cacheExtent: 100, // Reduced cache to prevent loading too many images at once
          addAutomaticKeepAlives: false, // Don't keep items alive when scrolled away
          addRepaintBoundaries: true, // Optimize repainting
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                        backgroundColor: Theme.of(context).colorScheme.error,
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
            width: ResponsiveHelper.isVerticalDisplay(context) ? 50 : 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Center(
              child: TextField(
                controller: textController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontSize: ResponsiveHelper.isVerticalDisplay(context) ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
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
                          backgroundColor: Theme.of(context).colorScheme.error,
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
                      backgroundColor: Theme.of(context).colorScheme.error,
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
    final isVertical = ResponsiveHelper.isVerticalDisplay(context);
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

    // Calculate total stock across all warehouses
    int calculateTotalStock() {
      if (product.warehouseStock == null || product.warehouseStock!.isEmpty) {
        return 0;
      }
      
      int total = 0;
      for (var entry in product.warehouseStock!.entries) {
        final available = entry.value.available;
        final reserved = entry.value.reserved;
        total += (available - reserved);
      }
      return total;
    }

    final totalStock = calculateTotalStock();
    
    // Determine stock status
    Color stockColor;
    String stockText;
    IconData stockIcon;
    if (totalStock > 50) {
      stockColor = Colors.green;
      stockText = 'In Stock ($totalStock)';
      stockIcon = Icons.check_circle;
    } else if (totalStock > 10) {
      stockColor = Colors.orange;
      stockText = 'Low Stock ($totalStock)';
      stockIcon = Icons.warning;
    } else if (totalStock > 0) {
      stockColor = Colors.red;
      stockText = 'Critical ($totalStock)';
      stockIcon = Icons.error;
    } else {
      stockColor = Colors.grey;
      stockText = 'Out of Stock';
      stockIcon = Icons.cancel;
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
              aspectRatio: isVertical ? 0.9 : (isMobile ? 1.2 : 1.0), // Taller cards for vertical screens
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF), // Pure white background for images
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SimpleImageWidget(
                    sku: product.sku ?? product.model ?? '',
                    useThumbnail: true,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    imageUrl: product.thumbnailUrl ?? product.imageUrl,
                  ),
                ),
              ),
            ),
            // Product Info - Extended area for vertical screens
            Padding(
              padding: EdgeInsets.all(isVertical ? 12 : (isMobile ? 10 : 8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.sku ?? product.model,
                          style: TextStyle(
                            fontSize: isVertical ? 18 : (isMobile ? 16 : 14),
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Spare parts icon for spare parts products
                      if (product.category.toLowerCase().contains('spare') ||
                          product.name.toLowerCase().contains('spare') ||
                          product.productType?.toLowerCase().contains('spare') == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.build,
                            color: theme.primaryColor,
                            size: 16,
                          ),
                        ),
                      if (product.isTopSeller)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                    ],
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
                  const SizedBox(height: 6),
                  // Stock Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stockColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: stockColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          stockIcon,
                          size: 12,
                          color: stockColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stockText,
                          style: TextStyle(
                            fontSize: 11,
                            color: stockColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Warehouse Availability Badges
                  if (product.warehouseStock != null && product.warehouseStock!.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: product.warehouseStock!.entries.map((entry) {
                        final warehouse = entry.key;
                        final stock = entry.value;
                        final availableStock = stock.available - stock.reserved;

                        Color badgeColor;
                        if (availableStock > 50) {
                          badgeColor = Colors.green;
                        } else if (availableStock > 10) {
                          badgeColor = Colors.orange;
                        } else if (availableStock > 0) {
                          badgeColor = Colors.red;
                        } else {
                          badgeColor = Colors.grey;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: badgeColor.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '$warehouse: $availableStock',
                            style: TextStyle(
                              fontSize: 9,
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  // Price and Quantity Selector
                  if (isMobile || isVertical)
                    // Mobile/Vertical layout - stacked for better visibility
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatPrice(product.price),
                          style: TextStyle(
                            fontSize: isVertical ? 22 : 20,
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
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                baseFontSize: 16,
                                minFontSize: 14,
                                maxFontSize: 20,
                              ),
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveHelper.getSpacing(context, small: 4),
                        ),
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
