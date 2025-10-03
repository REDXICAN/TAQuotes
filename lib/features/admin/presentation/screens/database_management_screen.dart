// lib/features/admin/presentation/screens/database_management_screen_fixed.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/app_logger.dart';
import 'dart:async';

// Provider for paginated products
final paginatedProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  return FirebaseDatabase.instance
      .ref('products')
      .limitToFirst(50) // Load only 50 products initially
      .onValue
      .map((event) {
        if (event.snapshot.value == null) return [];
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return data.entries.map((e) {
          final productData = Map<String, dynamic>.from(e.value as Map);
          productData['id'] = e.key;
          return Product.fromJson(productData);
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      });
});

// Provider for users with better error handling
final usersStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseDatabase.instance
      .ref('users')
      .onValue
      .map((event) {
        if (event.snapshot.value == null) return <Map<String, dynamic>>[];
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return data.entries.map((e) {
          final userData = Map<String, dynamic>.from(e.value as Map);
          userData['uid'] = e.key;
          return userData;
        }).toList();
      })
      .handleError((error) {
        AppLogger.error('Error loading users', error: error);
        return <Map<String, dynamic>>[];
      });
});

class DatabaseManagementScreen extends ConsumerStatefulWidget {
  const DatabaseManagementScreen({super.key});

  @override
  ConsumerState<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends ConsumerState<DatabaseManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = false;

  // Pagination
  int _currentPage = 0;
  static const int _itemsPerPage = 25;
  List<Product> _allProducts = [];
  List<Product> _displayedProducts = [];
  StreamSubscription? _productSubscription;

  // Debounce timer for search
  Timer? _debounceTimer;

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
    _searchController.addListener(_onSearchChanged);
    _loadProductsWithPagination();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
          _filterAndPaginateProducts();
        });
      }
    });
  }

  void _loadProductsWithPagination() async {
    setState(() => _isLoading = true);

    try {
      // Load products in batches
      _productSubscription = FirebaseDatabase.instance
          .ref('products')
          .onValue
          .listen((event) {
            if (event.snapshot.value == null) {
              setState(() {
                _allProducts = [];
                _displayedProducts = [];
                _isLoading = false;
              });
              return;
            }

            final data = event.snapshot.value as Map<dynamic, dynamic>;
            final products = data.entries.map((e) {
              final productData = Map<String, dynamic>.from(e.value as Map);
              productData['id'] = e.key;
              return Product.fromJson(productData);
            }).toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            if (mounted) {
              setState(() {
                _allProducts = products;
                _filterAndPaginateProducts();
                _isLoading = false;
              });
            }
          }, onError: (error) {
            AppLogger.error('Error loading products', error: error);
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading products: $error')),
              );
            }
          });
    } catch (e) {
      AppLogger.error('Failed to load products', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterAndPaginateProducts() {
    var filteredProducts = _allProducts;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredProducts = filteredProducts.where((p) {
        return (p.sku?.toLowerCase().contains(query) ?? false) ||
               p.model.toLowerCase().contains(query) ||
               p.name.toLowerCase().contains(query) ||
               p.description.toLowerCase().contains(query);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      filteredProducts = filteredProducts.where((p) => p.category == _selectedCategory).toList();
    }

    // Apply pagination
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredProducts.length);

    setState(() {
      _displayedProducts = filteredProducts.sublist(
        startIndex.clamp(0, filteredProducts.length),
        endIndex
      );
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _productSubscription?.cancel();
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    for (var c in _productControllers.values) {
      c.dispose();
    }
    for (var c in _userControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Product CRUD Operations remain the same...
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
        // Reload products
        _loadProductsWithPagination();
      } catch (e) {
        AppLogger.error('Failed to delete product', error: e);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete product: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProductChanges(Product product) async {
    setState(() => _isLoading = true);
    try {
      final updatedProduct = Product(
        id: product.id,
        sku: _productControllers['${product.id}_sku']?.text ?? product.sku,
        model: _productControllers['${product.id}_model']?.text ?? product.model,
        displayName: _productControllers['${product.id}_displayName']?.text ?? product.displayName,
        name: _productControllers['${product.id}_name']?.text ?? product.name,
        description: _productControllers['${product.id}_description']?.text ?? product.description,
        price: double.tryParse(_productControllers['${product.id}_price']?.text ?? '') ?? product.price,
        category: product.category,
        stock: product.stock,
        createdAt: product.createdAt,
        imageUrl: product.imageUrl,
        thumbnailUrl: product.thumbnailUrl,
        imageUrl2: product.imageUrl2,
      );

      await FirebaseDatabase.instance.ref('products/${product.id}').update(updatedProduct.toMap());

      setState(() {
        _editingProducts.remove(product.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully')),
      );
    } catch (e) {
      AppLogger.error('Failed to update product', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update product: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProductsTable() {
    if (_isLoading && _allProducts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allProducts.isEmpty) {
      return const Center(
        child: Text('No products found'),
      );
    }

    final totalFilteredProducts = _searchQuery.isNotEmpty || _selectedCategory != 'All'
        ? _allProducts.where((p) {
            bool matchesSearch = true;
            bool matchesCategory = true;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              matchesSearch = (p.sku?.toLowerCase().contains(query) ?? false) ||
                           p.model.toLowerCase().contains(query) ||
                           p.name.toLowerCase().contains(query) ||
                           p.description.toLowerCase().contains(query);
            }

            if (_selectedCategory != 'All') {
              matchesCategory = p.category == _selectedCategory;
            }

            return matchesSearch && matchesCategory;
          }).length
        : _allProducts.length;

    final totalPages = (totalFilteredProducts / _itemsPerPage).ceil();

    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _currentPage = 0;
                                _filterAndPaginateProducts();
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedCategory,
                items: ['All', 'Refrigeration', 'Cooking', 'Display', 'Preparation']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                    _currentPage = 0;
                    _filterAndPaginateProducts();
                  });
                },
              ),
              const SizedBox(width: 16),
              Text('Showing ${_displayedProducts.length} of $totalFilteredProducts products'),
            ],
          ),
        ),

        // Pagination controls
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page),
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage = 0;
                            _filterAndPaginateProducts();
                          });
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() {
                            _currentPage--;
                            _filterAndPaginateProducts();
                          });
                        }
                      : null,
                ),
                ...List.generate(
                  (totalPages).clamp(0, 5),
                  (index) {
                    final pageIndex = (_currentPage - 2 + index).clamp(0, totalPages - 1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentPage == pageIndex ? Theme.of(context).primaryColor : null,
                        ),
                        onPressed: () {
                          setState(() {
                            _currentPage = pageIndex;
                            _filterAndPaginateProducts();
                          });
                        },
                        child: Text('${pageIndex + 1}'),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < totalPages - 1
                      ? () {
                          setState(() {
                            _currentPage++;
                            _filterAndPaginateProducts();
                          });
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: _currentPage < totalPages - 1
                      ? () {
                          setState(() {
                            _currentPage = totalPages - 1;
                            _filterAndPaginateProducts();
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),

        // Products table
        Expanded(
          child: _displayedProducts.isEmpty
              ? const Center(child: Text('No products match your search'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Actions')),
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('Model')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Category')),
                      ],
                      rows: _displayedProducts.map((product) {
                        final isEditing = _editingProducts.contains(product.id);

                        // Initialize controllers if editing
                        if (isEditing) {
                          _productControllers['${product.id}_sku'] ??= TextEditingController(text: product.sku);
                          _productControllers['${product.id}_model'] ??= TextEditingController(text: product.model);
                          _productControllers['${product.id}_name'] ??= TextEditingController(text: product.name);
                          _productControllers['${product.id}_displayName'] ??= TextEditingController(text: product.displayName);
                          _productControllers['${product.id}_description'] ??= TextEditingController(text: product.description);
                          _productControllers['${product.id}_price'] ??= TextEditingController(text: product.price.toString());
                        }

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isEditing) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _editingProducts.add(product.id ?? '');
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      onPressed: () => _deleteProduct(product.id ?? ''),
                                    ),
                                  ] else ...[
                                    IconButton(
                                      icon: const Icon(Icons.save, size: 18, color: Colors.green),
                                      onPressed: () => _saveProductChanges(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel, size: 18, color: Colors.orange),
                                      onPressed: () {
                                        setState(() {
                                          _editingProducts.remove(product.id);
                                          // Clear controllers
                                          _productControllers['${product.id}_sku']?.dispose();
                                          _productControllers['${product.id}_model']?.dispose();
                                          _productControllers['${product.id}_name']?.dispose();
                                          _productControllers['${product.id}_displayName']?.dispose();
                                          _productControllers['${product.id}_description']?.dispose();
                                          _productControllers['${product.id}_price']?.dispose();
                                          _productControllers.removeWhere((key, value) => key.startsWith('${product.id}_'));
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              isEditing
                                  ? SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: _productControllers['${product.id}_sku'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : Text(product.sku ?? ''),
                            ),
                            DataCell(
                              isEditing
                                  ? SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: _productControllers['${product.id}_model'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : Text(product.model),
                            ),
                            DataCell(
                              isEditing
                                  ? SizedBox(
                                      width: 200,
                                      child: TextField(
                                        controller: _productControllers['${product.id}_name'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : Text(product.name),
                            ),
                            DataCell(
                              isEditing
                                  ? SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: _productControllers['${product.id}_price'],
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : Text('\$${product.price.toStringAsFixed(2)}'),
                            ),
                            DataCell(Text(product.category)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUsersTable() {
    final usersAsync = ref.watch(usersStreamProvider);

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Actions')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Display Name')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Last Login')),
              ],
              rows: users.map((user) {
                final uid = user['uid'];
                final isEditing = _editingUsers.contains(uid);

                if (isEditing) {
                  _userControllers['${uid}_email'] ??= TextEditingController(text: user['email']);
                  _userControllers['${uid}_displayName'] ??= TextEditingController(text: user['displayName']);
                  _userControllers['${uid}_role'] ??= TextEditingController(text: user['role']);
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isEditing) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () {
                                setState(() {
                                  _editingUsers.add(uid);
                                });
                              },
                            ),
                          ] else ...[
                            IconButton(
                              icon: const Icon(Icons.save, size: 18, color: Colors.green),
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                try {
                                  await FirebaseDatabase.instance.ref('users/$uid').update({
                                    'email': _userControllers['${uid}_email']?.text,
                                    'displayName': _userControllers['${uid}_displayName']?.text,
                                    'role': _userControllers['${uid}_role']?.text,
                                  });
                                  setState(() {
                                    _editingUsers.remove(uid);
                                  });
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('User updated successfully')),
                                  );
                                } catch (e) {
                                  AppLogger.error('Failed to update user', error: e);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update user: $e')),
                                  );
                                } finally {
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, size: 18, color: Colors.orange),
                              onPressed: () {
                                setState(() {
                                  _editingUsers.remove(uid);
                                  _userControllers['${uid}_email']?.dispose();
                                  _userControllers['${uid}_displayName']?.dispose();
                                  _userControllers['${uid}_role']?.dispose();
                                  _userControllers.removeWhere((key, value) => key.startsWith('${uid}_'));
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    DataCell(
                      isEditing
                          ? SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _userControllers['${uid}_email'],
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                          : Text(user['email'] ?? ''),
                    ),
                    DataCell(
                      isEditing
                          ? SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _userControllers['${uid}_displayName'],
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                          : Text(user['displayName'] ?? ''),
                    ),
                    DataCell(
                      isEditing
                          ? SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _userControllers['${uid}_role'],
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                          : Text(user['role'] ?? 'user'),
                    ),
                    DataCell(
                      Chip(
                        label: Text(user['isApproved'] == true ? 'Active' : 'Pending'),
                        backgroundColor: user['isApproved'] == true ? Colors.green : Colors.orange,
                      ),
                    ),
                    DataCell(
                      Text(user['lastLogin'] != null
                          ? DateTime.fromMillisecondsSinceEpoch(user['lastLogin']).toString()
                          : 'Never'),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading users: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(usersStreamProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Products', icon: Icon(Icons.inventory)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildProductsTable(),
              _buildUsersTable(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}