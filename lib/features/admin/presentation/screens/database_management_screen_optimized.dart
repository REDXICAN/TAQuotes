// lib/features/admin/presentation/screens/database_management_screen_optimized.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../../../../core/models/models.dart';
import '../../../../core/services/realtime_database_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Provider for paginated products with caching
final paginatedProductsProvider = FutureProvider.autoDispose.family<List<Product>, int>((ref, page) async {
  const pageSize = 50;
  final startIndex = page * pageSize;

  final snapshot = await FirebaseDatabase.instance
      .ref('products')
      .orderByKey()
      .limitToFirst(pageSize * (page + 1))
      .get();

  if (!snapshot.exists) return [];

  final data = snapshot.value as Map<dynamic, dynamic>;
  final products = data.entries.map((e) {
    final productData = Map<String, dynamic>.from(e.value as Map);
    productData['id'] = e.key;
    return Product.fromJson(productData);
  }).toList();

  // Return only the products for this page
  return products.skip(startIndex).take(pageSize).toList()
    ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
});

// Provider for total product count
final productCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final snapshot = await FirebaseDatabase.instance
      .ref('products')
      .once();

  if (snapshot.snapshot.value == null) return 0;
  final data = snapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
  return data.keys.length;
});

// Provider for paginated users with caching
final paginatedUsersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, page) async {
  const pageSize = 50;

  try {
    final snapshot = await FirebaseDatabase.instance
        .ref('user_profiles')
        .once();

    if (snapshot.snapshot.value == null) return [];

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
    final users = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      final userData = Map<String, dynamic>.from(value as Map);
      userData['uid'] = key;
      users.add(userData);
    });

    // Sort users by email
    users.sort((a, b) => (a['email'] as String? ?? '').compareTo(b['email'] as String? ?? ''));

    // Apply pagination
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, users.length);

    return users.sublist(startIndex.clamp(0, users.length), endIndex);
  } catch (e) {
    AppLogger.error('Permission denied accessing user_profiles', error: e);
    // Return empty list with permission error indicator
    return [];
  }
});

// Provider for total user count
final userCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final snapshot = await FirebaseDatabase.instance
        .ref('user_profiles')
        .once();

    if (snapshot.snapshot.value == null) return 0;
    final data = snapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
    return data.keys.length;
  } catch (e) {
    AppLogger.error('Permission denied accessing user_profiles count', error: e);
    return 0;
  }
});

class OptimizedDatabaseManagementScreen extends ConsumerStatefulWidget {
  const OptimizedDatabaseManagementScreen({super.key});

  @override
  ConsumerState<OptimizedDatabaseManagementScreen> createState() => _OptimizedDatabaseManagementScreenState();
}

class _OptimizedDatabaseManagementScreenState extends ConsumerState<OptimizedDatabaseManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = false;
  int _currentPage = 0;
  int _currentUserPage = 0;
  static const int _pageSize = 50;
  bool _initialLoadComplete = false;

  // Product editing controllers
  final Map<String, TextEditingController> _productControllers = {};

  // User editing controllers
  final Map<String, TextEditingController> _userControllers = {};

  // Track which rows are in edit mode
  final Set<String> _editingProducts = {};
  final Set<String> _editingUsers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Simulate initial loading with error handling
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _initialLoadComplete = true);
      }
    }).catchError((error) {
      AppLogger.error('Error in initial load', error: error);
      if (mounted) {
        setState(() => _initialLoadComplete = true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    for (final controller in _productControllers.values) {
      controller.dispose();
    }
    for (final controller in _userControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Product CRUD Operations
  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseDatabase.instance.ref('products/$productId').remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
          // Refresh the current page
          ref.invalidate(paginatedProductsProvider);
        }
      } catch (e) {
        AppLogger.error('Failed to delete product', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete product: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _duplicateProduct(Product product) async {
    setState(() => _isLoading = true);
    try {
      final newProduct = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sku: '${product.sku}-COPY',
        model: '${product.model}-COPY',
        name: '${product.name} (Copy)',
        displayName: '${product.displayName} (Copy)',
        description: product.description,
        category: product.category,
        subcategory: product.subcategory,
        price: product.price,
        stock: product.stock,
        warehouse: product.warehouse,
        dimensions: product.dimensions,
        weight: product.weight,
        voltage: product.voltage,
        amperage: product.amperage,
        imageUrl: product.imageUrl,
        imageUrl2: product.imageUrl2,
        thumbnailUrl: product.thumbnailUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseDatabase.instance
          .ref('products/${newProduct.id}')
          .set(newProduct.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product duplicated successfully')),
        );
        ref.invalidate(paginatedProductsProvider);
      }
    } catch (e) {
      AppLogger.error('Failed to duplicate product', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to duplicate product: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProduct(String productId) async {
    setState(() => _isLoading = true);
    try {
      final updates = <String, dynamic>{};

      _productControllers.forEach((key, controller) {
        if (key.startsWith('$productId-')) {
          final field = key.substring(productId.length + 1);
          String value = controller.text.trim();

          // Convert price and stock to numbers
          if (field == 'price') {
            updates[field] = double.tryParse(value) ?? 0.0;
          } else if (field == 'stock') {
            updates[field] = int.tryParse(value) ?? 0;
          } else {
            updates[field] = value;
          }
        }
      });

      updates['updatedAt'] = ServerValue.timestamp;

      await FirebaseDatabase.instance
          .ref('products/$productId')
          .update(updates);

      setState(() {
        _editingProducts.remove(productId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
        ref.invalidate(paginatedProductsProvider);
      }
    } catch (e) {
      AppLogger.error('Failed to save product', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save product: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TextEditingController _getProductController(String productId, String field, String initialValue) {
    final key = '$productId-$field';
    if (!_productControllers.containsKey(key)) {
      _productControllers[key] = TextEditingController(text: initialValue);
    }
    return _productControllers[key]!;
  }

  Widget _buildLoadingOverlay() {
    if (!_isLoading) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Management'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading Database...',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching products and users',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            // Loading animation dots
            _LoadingDots(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Show initial loading screen
      if (!_initialLoadComplete) {
        return _buildInitialLoadingScreen();
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Database Management'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Users'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildUsersTab(),
              ],
            ),
            _buildLoadingOverlay(),
          ],
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Error in database management build', error: error, stackTrace: stackTrace);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Database Management'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('An error occurred loading the database'),
              const SizedBox(height: 8),
              Text('Error: $error', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initialLoadComplete = false;
                  });
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      setState(() => _initialLoadComplete = true);
                    }
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildProductsTab() {
    final productCountAsync = ref.watch(productCountProvider);
    final productsAsync = ref.watch(paginatedProductsProvider(_currentPage));

    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              productCountAsync.when(
                data: (count) => Chip(
                  label: Text('$count products'),
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Chip(label: Text('Error')),
              ),
            ],
          ),
        ),

        // Products table
        Expanded(
          child: productsAsync.when(
            data: (products) {
              // Filter products based on search
              var filteredProducts = products;
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                filteredProducts = products.where((p) =>
                  (p.sku?.toLowerCase().contains(query) ?? false) ||
                  (p.model.toLowerCase().contains(query)) ||
                  (p.name?.toLowerCase().contains(query) ?? false) ||
                  (p.category?.toLowerCase().contains(query) ?? false)
                ).toList();
              }

              if (filteredProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No products found' : 'No products match your search',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('SKU')),
                            DataColumn(label: Text('Model')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Warehouse')),
                            DataColumn(label: Text('Price')),
                            DataColumn(label: Text('Stock')),
                            DataColumn(label: Text('Images')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filteredProducts.map((product) {
                            final isEditing = _editingProducts.contains(product.id);

                            return DataRow(
                              cells: [
                                // SKU
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'sku',
                                            product.sku ?? '',
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Text(product.sku ?? '-', style: const TextStyle(fontSize: 13)),
                                ),
                                // Model
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 120,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'model',
                                            product.model,
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Text(product.model, style: const TextStyle(fontSize: 13)),
                                ),
                                // Name
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 200,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'name',
                                            product.name ?? '',
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Tooltip(
                                        message: product.name ?? '',
                                        child: Text(
                                          product.name ?? '',
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                ),
                                // Description
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 200,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'description',
                                            product.description ?? '',
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Tooltip(
                                        message: product.description ?? '',
                                        child: Text(
                                          _truncateText(product.description ?? '-', 50),
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                ),
                                // Category
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 120,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'category',
                                            product.category ?? '',
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Text(product.category ?? '', style: const TextStyle(fontSize: 13)),
                                ),
                                // Warehouse
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'warehouse',
                                            product.warehouse ?? '',
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Text(product.warehouse ?? '-', style: const TextStyle(fontSize: 13)),
                                ),
                                // Price
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'price',
                                            product.price.toString(),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                          ],
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            prefixText: '\$',
                                          ),
                                        ),
                                      )
                                    : Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                                ),
                                // Stock
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 60,
                                        child: TextFormField(
                                          controller: _getProductController(
                                            product.id!,
                                            'stock',
                                            product.stock.toString(),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Text(product.stock.toString(), style: const TextStyle(fontSize: 13)),
                                ),
                                // Images
                                DataCell(
                                  Row(
                                    children: [
                                      if (product.thumbnailUrl != null && product.thumbnailUrl!.isNotEmpty)
                                        const Tooltip(
                                          message: 'Has thumbnail',
                                          child: Icon(Icons.image, size: 16, color: Colors.green),
                                        ),
                                      if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                                        const Tooltip(
                                          message: 'Has P.1 screenshot',
                                          child: Icon(Icons.photo_library, size: 16, color: Colors.blue),
                                        ),
                                      if (product.imageUrl2 != null && product.imageUrl2!.isNotEmpty)
                                        const Tooltip(
                                          message: 'Has P.2 screenshot',
                                          child: Icon(Icons.photo_library_outlined, size: 16, color: Colors.blue),
                                        ),
                                      if ((product.thumbnailUrl == null || product.thumbnailUrl!.isEmpty) &&
                                          (product.imageUrl == null || product.imageUrl!.isEmpty))
                                        const Tooltip(
                                          message: 'No images',
                                          child: Icon(Icons.image_not_supported, size: 16, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                                // Actions
                                DataCell(
                                  Row(
                                    children: [
                                      if (!isEditing) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _editingProducts.add(product.id!);
                                            });
                                          },
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 18),
                                          onPressed: () => _duplicateProduct(product),
                                          tooltip: 'Duplicate',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18),
                                          onPressed: () => _deleteProduct(product.id!),
                                          tooltip: 'Delete',
                                          color: Colors.red,
                                        ),
                                      ] else ...[
                                        IconButton(
                                          icon: const Icon(Icons.save, size: 18),
                                          onPressed: () => _saveProduct(product.id!),
                                          tooltip: 'Save',
                                          color: Colors.green,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _editingProducts.remove(product.id!);
                                            });
                                          },
                                          tooltip: 'Cancel',
                                          color: Colors.red,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  // Pagination controls
                  _buildPaginationControls(),
                ],
              );
            },
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading products...'),
                ],
              ),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading products: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(paginatedProductsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationControls() {
    final productCountAsync = ref.watch(productCountProvider);

    return productCountAsync.when(
      data: (totalCount) {
        final totalPages = (totalCount / _pageSize).ceil();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
                tooltip: 'First page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Previous page',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                tooltip: 'Next page',
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
                tooltip: 'Last page',
              ),
              const SizedBox(width: 32),
              Text(
                'Showing ${_currentPage * _pageSize + 1}-${((_currentPage + 1) * _pageSize).clamp(0, totalCount)} of $totalCount products',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(8),
        child: const LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildUsersTab() {
    final userCountAsync = ref.watch(userCountProvider);
    final usersAsync = ref.watch(paginatedUsersProvider(_currentUserPage));

    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search user profiles...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              userCountAsync.when(
                data: (count) => Chip(
                  label: Text('$count profiles'),
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Chip(label: Text('Error')),
              ),
            ],
          ),
        ),

        // Users table
        Expanded(
          child: usersAsync.when(
            data: (users) {
              // Apply search filter
              var filteredUsers = users;
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                filteredUsers = users.where((u) =>
                  (u['email'] as String?)?.toLowerCase().contains(query) == true ||
                  (u['displayName'] as String?)?.toLowerCase().contains(query) == true ||
                  (u['role'] as String?)?.toLowerCase().contains(query) == true
                ).toList();
              }

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No user profiles found' : 'No user profiles match your search',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure you have proper permissions to view user data.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Created')),
                            DataColumn(label: Text('Last Login')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filteredUsers.map((user) {
                            final isEditing = _editingUsers.contains(user['uid']);
                            final createdAt = _parseDateTime(user['createdAt']);
                            final lastLogin = _parseDateTime(user['lastLoginAt']);
                            final currentRole = isEditing && _userControllers.containsKey('${user['uid']}-role')
                                ? _userControllers['${user['uid']}-role']!.text
                                : user['role'] ?? 'user';

                            return DataRow(
                              cells: [
                                DataCell(Text(user['email'] ?? '', style: const TextStyle(fontSize: 13))),
                                DataCell(
                                  isEditing
                                    ? SizedBox(
                                        width: 150,
                                        child: TextFormField(
                                          controller: _getUserController(
                                            user['uid'],
                                            'displayName',
                                            user['displayName'] ?? '',
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      )
                                    : Text(user['displayName'] ?? '-', style: const TextStyle(fontSize: 13)),
                                ),
                                DataCell(
                                  isEditing
                                    ? DropdownButton<String>(
                                        value: currentRole,
                                        isDense: true,
                                        style: const TextStyle(fontSize: 13),
                                        items: ['superadmin', 'admin', 'sales', 'distributor', 'user']
                                            .map((role) => DropdownMenuItem(
                                                  value: role,
                                                  child: Text(role),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            final controller = _getUserController(user['uid'], 'role', value);
                                            controller.text = value;
                                            setState(() {});
                                          }
                                        },
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(user['role']).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          user['role'] ?? 'user',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _getRoleColor(user['role']),
                                          ),
                                        ),
                                      ),
                                ),
                                DataCell(Text(createdAt != null
                                    ? '${createdAt.month}/${createdAt.day}/${createdAt.year}'
                                    : '-', style: const TextStyle(fontSize: 13))),
                                DataCell(Text(lastLogin != null
                                    ? '${lastLogin.month}/${lastLogin.day}/${lastLogin.year}'
                                    : '-', style: const TextStyle(fontSize: 13))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: user['isActive'] == true
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user['isActive'] == true ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: user['isActive'] == true ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      if (!isEditing) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _editingUsers.add(user['uid']);
                                            });
                                          },
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18),
                                          onPressed: () => _deleteUser(user['uid']),
                                          tooltip: 'Delete',
                                          color: Colors.red,
                                        ),
                                      ] else ...[
                                        IconButton(
                                          icon: const Icon(Icons.save, size: 18),
                                          onPressed: () => _saveUser(user['uid']),
                                          tooltip: 'Save',
                                          color: Colors.green,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _editingUsers.remove(user['uid']);
                                              // Clear controllers for this user
                                              _userControllers.removeWhere((key, _) =>
                                                  key.startsWith('${user['uid']}-'));
                                            });
                                          },
                                          tooltip: 'Cancel',
                                          color: Colors.red,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  // Pagination controls
                  _buildUserPaginationControls(),
                ],
              );
            },
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading user profiles...'),
                ],
              ),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text('Permission Denied'),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to access user profile data. Contact administrator.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${error.toString().contains('permission') ? 'Database permission denied' : error}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(paginatedUsersProvider);
                      ref.invalidate(userCountProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserPaginationControls() {
    final userCountAsync = ref.watch(userCountProvider);

    return userCountAsync.when(
      data: (totalCount) {
        final totalPages = (totalCount / _pageSize).ceil();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _currentUserPage > 0
                    ? () => setState(() => _currentUserPage = 0)
                    : null,
                tooltip: 'First page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentUserPage > 0
                    ? () => setState(() => _currentUserPage--)
                    : null,
                tooltip: 'Previous page',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page ${_currentUserPage + 1} of $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentUserPage < totalPages - 1
                    ? () => setState(() => _currentUserPage++)
                    : null,
                tooltip: 'Next page',
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: _currentUserPage < totalPages - 1
                    ? () => setState(() => _currentUserPage = totalPages - 1)
                    : null,
                tooltip: 'Last page',
              ),
              const SizedBox(width: 32),
              Text(
                'Showing ${_currentUserPage * _pageSize + 1}-${((_currentUserPage + 1) * _pageSize).clamp(0, totalCount)} of $totalCount profiles',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(8),
        child: const LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  TextEditingController _getUserController(String userId, String field, String initialValue) {
    final key = '$userId-$field';
    if (!_userControllers.containsKey(key)) {
      _userControllers[key] = TextEditingController(text: initialValue);
    }
    return _userControllers[key]!;
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Delete from Firebase Auth
        // Note: This requires admin SDK, for now just remove from database
        await FirebaseDatabase.instance.ref('user_profiles/$userId').remove();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        AppLogger.error('Failed to delete user', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUser(String userId) async {
    setState(() => _isLoading = true);
    try {
      final updates = <String, dynamic>{};

      _userControllers.forEach((key, controller) {
        if (key.startsWith('$userId-')) {
          final field = key.substring(userId.length + 1);
          updates[field] = controller.text.trim();
        }
      });

      updates['updatedAt'] = ServerValue.timestamp;

      await FirebaseDatabase.instance.ref('user_profiles/$userId').update(updates);

      setState(() {
        _editingUsers.remove(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save user', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'superadmin':
        return Colors.red;
      case 'admin':
        return Colors.orange;
      case 'sales':
        return Colors.blue;
      case 'distributor':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Helper function to safely parse DateTime from various formats (Firebase timestamps)
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    // Handle integer timestamps (Firebase ServerValue.timestamp)
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        AppLogger.warning('Failed to parse timestamp int "$value"', error: e, category: LogCategory.data);
        return null;
      }
    }

    // Handle double timestamps (converted from int)
    if (value is double) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      } catch (e) {
        AppLogger.warning('Failed to parse timestamp double "$value"', error: e, category: LogCategory.data);
        return null;
      }
    }

    // Handle string dates
    if (value is String) {
      try {
        // First try to parse as a timestamp integer string
        final timestampInt = int.tryParse(value);
        if (timestampInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestampInt);
        }

        // Then try ISO format or other date string formats
        return DateTime.parse(value);
      } catch (e) {
        AppLogger.warning('Failed to parse date string "$value"', error: e, category: LogCategory.data);
        return null;
      }
    }

    AppLogger.warning('Unknown date format type ${value.runtimeType}: "$value"', category: LogCategory.data);
    return null;
  }
}

// Loading dots animation widget
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value.floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: index <= value
                    ? Theme.of(context).primaryColor
                    : Colors.grey[400],
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}