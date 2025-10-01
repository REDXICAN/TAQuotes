// lib/features/products/presentation/screens/products_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/widgets/simple_image_widget.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/services/excel_upload_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/rbac_service.dart';
import '../../../../core/utils/warehouse_utils.dart';
import '../../../../core/providers/providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../widgets/excel_preview_dialog.dart';
import '../../widgets/import_progress_dialog.dart';

// Firebase products provider
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

// Search and selection providers (searchQueryProvider is imported from providers.dart)
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
      // Double-check permissions
      final canImport = await RBACService.hasPermission('import_products');
      if (!canImport) {
        AppLogger.warning('Unauthorized Excel import attempt', data: {
          'user': FirebaseAuth.instance.currentUser?.email,
          'permission': 'import_products',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access Denied: Admin or SuperAdmin privileges required for Excel import'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      AppLogger.info('Excel import initiated', data: {
        'user': FirebaseAuth.instance.currentUser?.email,
      });

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
                onConfirm: (products, clearExisting, duplicateHandling) async {
                  // Create progress stream controller
                  final progressController = StreamController<ImportProgress>();

                  // Show enhanced progress dialog
                  final progressDialogFuture = showDialog<ImportProgress?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => ImportProgressDialog(
                      totalProducts: products.length,
                      progressStream: progressController.stream,
                      onCancel: () {
                        // Cancel the import if needed
                        progressController.close();
                      },
                    ),
                  );

                  // Start the enhanced import process
                  final saveResult = await ExcelUploadService.saveProductsWithProgress(
                    products,
                    clearExisting: clearExisting,
                    duplicateHandling: duplicateHandling,
                    progressController: progressController,
                  );

                  // Close progress controller
                  progressController.close();

                  // Wait for progress dialog to complete
                  final finalProgress = await progressDialogFuture;

                  if (mounted && context.mounted) {
                    // Refresh products list
                    ref.invalidate(productsProvider);

                    // Show enhanced result dialog
                    showDialog(
                      context: context,
                      builder: (context) => _buildEnhancedResultDialog(
                        context,
                        saveResult,
                        duplicateHandling,
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
        // Try to close any open dialogs safely
        try {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } catch (popError) {
          // Log navigation error but don't fail the error handling
          AppLogger.warning(
            'Could not close dialog during error handling',
            error: popError,
            category: LogCategory.ui,
          );
        }
        
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

    // Get products from Firebase
    final productsAsync = ref.watch(productsProvider(null));

    // Check if current user is superadmin
    final isSuperAdmin = ExcelUploadService.isSuperAdmin;

    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Products',
        elevation: 0,
        actions: [
          // Excel Import Button - Only for Admin and SuperAdmin
          FutureBuilder<bool>(
            future: RBACService.hasPermission('import_products'),
            builder: (context, snapshot) {
              final canImport = snapshot.data ?? false;
              if (!canImport) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.upload_file, color: Colors.white),
                      if (_isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Import Excel Products',
                  onPressed: _isUploading ? null : _handleExcelUpload,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: theme.appBarTheme.backgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

                  // Warehouse Filter Dropdown with Legend
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        // Warehouse Info Icon with Legend
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: WarehouseUtils.createInfoTooltip(context),
                        ),
                      ],
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
      constraints: const BoxConstraints(
        minWidth: 100,
        maxWidth: 120,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Minus button
            Flexible(
              child: InkWell(
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
                  width: 32,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.remove,
                    size: 16,
                    color: quantity > 0 ? theme.primaryColor : theme.disabledColor,
                  ),
                ),
              ),
            ),
            // Quantity input
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextField(
                  controller: textController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    counterText: '',
                  ),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isVerticalDisplay(context) ? 14 : 12,
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
            Flexible(
              child: InkWell(
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
                  width: 32,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
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

        // Adjust aspect ratio based on screen size - optimized for proper card content containment
        // Lower values = taller cards with more room for content
        double childAspectRatio;
        if (ResponsiveHelper.isVerticalDisplay(context)) {
          childAspectRatio = 0.70;  // Taller cards for vertical displays to fit all content
        } else if (ResponsiveHelper.isMobile(context)) {
          childAspectRatio = 0.75;  // Significantly taller cards on mobile to prevent overflow
        } else if (ResponsiveHelper.isTablet(context)) {
          childAspectRatio = 0.78;  // Taller cards on tablets for better content containment
        } else {
          childAspectRatio = 0.80;  // Taller cards on desktop to accommodate all elements
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

  // Enhanced result dialog for import operations
  Widget _buildEnhancedResultDialog(
    BuildContext context,
    Map<String, dynamic> result,
    String duplicateHandling,
  ) {
    final theme = Theme.of(context);
    final success = result['success'] == true;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            success ? 'Import Completed' : 'Import Failed',
            style: TextStyle(
              color: success ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main message
            Text(
              result['message'] ?? 'Unknown result',
              style: theme.textTheme.bodyMedium,
            ),

            if (success) ...[
              const SizedBox(height: 16),

              // Statistics section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Statistics',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Total Products:', result['totalProducts']),
                    _buildStatRow('Successfully Imported:', result['successCount']),
                    if (result['updatedCount'] > 0)
                      _buildStatRow('Updated Products:', result['updatedCount']),
                    if (result['skippedCount'] > 0)
                      _buildStatRow('Skipped Duplicates:', result['skippedCount']),
                    if (result['errorCount'] > 0)
                      _buildStatRow('Errors:', result['errorCount'], isError: true),
                  ],
                ),
              ),

              // Duplicate handling info
              if (duplicateHandling != 'update') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Duplicate Handling: ${_getDuplicateHandlingDescription(duplicateHandling)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // Error details
            if (result['errors'] != null && (result['errors'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Error Details:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.red.withOpacity(0.05),
                ),
                child: ListView.builder(
                  itemCount: (result['errors'] as List).length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        result['errors'][index],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[700],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Rollback info
            if (result['rollbackPerformed'] == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rollback was performed due to import failure. Previous data has been restored.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!success && result['rollbackPerformed'] != true)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Could add rollback functionality here if needed
            },
            child: const Text('Retry'),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, dynamic value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getDuplicateHandlingDescription(String handling) {
    switch (handling) {
      case 'update':
        return 'Updated existing products';
      case 'skip':
        return 'Skipped duplicate products';
      case 'error':
        return 'Errored on duplicates';
      default:
        return handling;
    }
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
      constraints: const BoxConstraints(
        minWidth: 100,
        maxWidth: 120,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Minus button
            Flexible(
              child: InkWell(
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
                  width: 32,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.remove,
                    size: 16,
                    color: quantity > 0 ? theme.primaryColor : theme.disabledColor,
                  ),
                ),
              ),
            ),
            // Quantity input
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextField(
                  controller: textController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    counterText: '',
                  ),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isVerticalDisplay(context) ? 14 : 12,
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
            Flexible(
              child: InkWell(
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
                  width: 32,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dbService = ref.read(databaseServiceProvider);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isVertical = ResponsiveHelper.isVerticalDisplay(context);

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/products/${product.id}');
        },
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate available height for dynamic sizing
            final cardHeight = constraints.maxHeight;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image - responsive height based on card size
                SizedBox(
                  height: cardHeight * 0.40, // 40% of card height for image
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFFFF), // Pure white background for images
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
                // Product Info - Use Expanded to fill remaining 60% of space
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(
                      ResponsiveHelper.getValue(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.sku ?? product.model ?? '',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              baseFontSize: 14,
                              minFontSize: 13,
                              maxFontSize: 16,
                            ),
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
                            size: ResponsiveHelper.getValue(context, mobile: 14, tablet: 15, desktop: 16),
                          ),
                        ),
                      if (product.isTopSeller)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: ResponsiveHelper.getValue(context, mobile: 14, tablet: 15, desktop: 16),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getValue(context, mobile: 2, tablet: 3, desktop: 4)),
                  Text(
                    product.displayName,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        baseFontSize: 12,
                        minFontSize: 11,
                        maxFontSize: 13,
                      ),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.getValue(context, mobile: 4, tablet: 5, desktop: 6)),
                  // Stock Status Badge - more compact
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.getValue(context, mobile: 4, tablet: 5, desktop: 6),
                      vertical: ResponsiveHelper.getValue(context, mobile: 2, tablet: 2, desktop: 3),
                    ),
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
                          size: ResponsiveHelper.getValue(context, mobile: 10, tablet: 11, desktop: 12),
                          color: stockColor,
                        ),
                        SizedBox(width: ResponsiveHelper.getValue(context, mobile: 2, tablet: 3, desktop: 4)),
                        Flexible(
                          child: Text(
                            stockText,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                baseFontSize: 10,
                                minFontSize: 9,
                                maxFontSize: 11,
                              ),
                              color: stockColor,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getValue(context, mobile: 4, tablet: 5, desktop: 6)),

                  // Warehouse Availability Badges - compact and responsive
                  if (product.warehouseStock != null && product.warehouseStock!.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: ResponsiveHelper.getValue(context, mobile: 2, tablet: 3, desktop: 4),
                        runSpacing: ResponsiveHelper.getValue(context, mobile: 2, tablet: 2, desktop: 3),
                        children: () {
                          // Sort warehouses: Priority order (999, Cancún, Puebla, Consignación, Spare Parts, Other)
                          final sortedEntries = product.warehouseStock!.entries.toList()
                            ..sort((a, b) {
                              // Get priority for each warehouse using WarehouseUtils
                              final priorityA = WarehouseUtils.getAllWarehouseCodesSorted().indexOf(a.key);
                              final priorityB = WarehouseUtils.getAllWarehouseCodesSorted().indexOf(b.key);

                              // If found in sorted list, use that priority
                              if (priorityA != -1 && priorityB != -1) {
                                if (priorityA != priorityB) return priorityA.compareTo(priorityB);
                              } else if (priorityA != -1) {
                                return -1; // A has priority
                              } else if (priorityB != -1) {
                                return 1; // B has priority
                              }

                              // Then sort by available stock (highest first)
                              final aStock = a.value.available - a.value.reserved;
                              final bStock = b.value.available - b.value.reserved;
                              return bStock.compareTo(aStock);
                            });

                          // Limit the number of warehouse badges - more restrictive on mobile
                          final maxBadges = ResponsiveHelper.getValue(
                            context,
                            mobile: 3,
                            tablet: 5,
                            desktop: 6,
                          );
                          final limitedEntries = sortedEntries.take(maxBadges).toList();

                          return limitedEntries.map((entry) {
                            final warehouse = entry.key;
                            final stock = entry.value;
                            final availableStock = stock.available - stock.reserved;
                            // Check if warehouse is high priority (Mexican warehouses)
                            final isHighPriority = warehouse == '999' ||
                                                   WarehouseUtils.isCancunWarehouse(warehouse) ||
                                                   WarehouseUtils.isPueblaWarehouse(warehouse) ||
                                                   WarehouseUtils.isConsignacionWarehouse(warehouse) ||
                                                   WarehouseUtils.isSparePartsWarehouse(warehouse) ||
                                                   warehouse == 'SI' || warehouse == 'MEE';

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
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveHelper.getValue(context, mobile: 3, tablet: 4, desktop: 4),
                                vertical: ResponsiveHelper.getValue(context, mobile: 1, tablet: 1, desktop: 2),
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(isHighPriority ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: badgeColor.withOpacity(isHighPriority ? 0.5 : 0.3),
                                  width: isHighPriority ? 1.0 : 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isHighPriority)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 2),
                                      child: Icon(
                                        WarehouseUtils.getWarehouseIcon(warehouse),
                                        size: ResponsiveHelper.getValue(context, mobile: 8, tablet: 9, desktop: 10),
                                        color: badgeColor,
                                      ),
                                    ),
                                  Flexible(
                                    child: Text(
                                      '${warehouse}: $availableStock',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                                          context,
                                          baseFontSize: isHighPriority ? 9 : 8,
                                          minFontSize: 8,
                                          maxFontSize: 10,
                                        ),
                                        color: badgeColor,
                                        fontWeight: isHighPriority ? FontWeight.w700 : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        }(),
                      ),
                    ),
                  // Spacer to push price/quantity to bottom
                  const Spacer(),
                  // Price and Quantity Selector
                  if (isMobile || isVertical)
                    // Mobile/Vertical layout - stacked for better visibility
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatPrice(product.price),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              baseFontSize: 18,
                              minFontSize: 16,
                              maxFontSize: 20,
                            ),
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: ResponsiveHelper.getValue(context, mobile: 6, tablet: 7, desktop: 8)),
                        SizedBox(
                          width: double.infinity,
                          height: ResponsiveHelper.getValue(context, mobile: 36, tablet: 38, desktop: 40),
                          child: _buildQuantitySelector(product, ref, context, theme, dbService),
                        ),
                      ],
                    )
                  else
                    // Desktop/Tablet - side by side with proper constraints
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            formatPrice(product.price),
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                baseFontSize: 14,
                                minFontSize: 13,
                                maxFontSize: 16,
                              ),
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.getValue(context, mobile: 6, tablet: 7, desktop: 8)),
                        Flexible(
                          flex: 1,
                          child: SizedBox(
                            height: ResponsiveHelper.getValue(context, mobile: 32, tablet: 34, desktop: 36),
                            child: _buildQuantitySelector(product, ref, context, theme, dbService),
                          ),
                        ),
                      ],
                    ),
                ],
                ),
              ),
            ),
          ],
        );
          },
        ),
      ),
    );
  }
}
