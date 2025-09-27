// lib/features/admin/presentation/screens/database_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../../../../core/models/models.dart';
import '../../../../core/services/realtime_database_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _productControllers.values.forEach((c) => c.dispose());
    _userControllers.values.forEach((c) => c.dispose());
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
        displayName: '${product.displayName} (Copy)',
        name: '${product.name} (Copy)',
        description: product.description,
        price: product.price,
        category: product.category,
        stock: product.stock,
        createdAt: DateTime.now(),
        imageUrl: product.imageUrl,
        thumbnailUrl: product.thumbnailUrl,
        imageUrl2: product.imageUrl2,
        dimensions: product.dimensions,
        weight: product.weight,
        voltage: product.voltage,
        amperage: product.amperage,
        warehouse: product.warehouse,
      );

      await FirebaseDatabase.instance.ref('products/${newProduct.id}').set(newProduct.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product duplicated successfully')),
        );
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

  Future<void> _saveProductChanges(Product product) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to save these changes?'),
            const SizedBox(height: 16),
            Text('SKU: ${_productControllers['${product.id}_sku']?.text}', style: const TextStyle(fontSize: 12)),
            Text('Model: ${_productControllers['${product.id}_model']?.text}', style: const TextStyle(fontSize: 12)),
            Text('Name: ${_productControllers['${product.id}_name']?.text}', style: const TextStyle(fontSize: 12)),
            Text('Price: \$${_productControllers['${product.id}_price']?.text}', style: const TextStyle(fontSize: 12)),
            Text('Stock: ${_productControllers['${product.id}_stock']?.text}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final updatedProduct = Product(
        id: product.id,
        sku: _productControllers['${product.id}_sku']?.text ?? product.sku,
        model: _productControllers['${product.id}_model']?.text ?? product.model,
        displayName: _productControllers['${product.id}_name']?.text ?? product.displayName,
        name: _productControllers['${product.id}_name']?.text ?? product.name,
        description: _productControllers['${product.id}_description']?.text ?? product.description,
        price: double.tryParse(_productControllers['${product.id}_price']?.text ?? '') ?? product.price,
        category: _productControllers['${product.id}_category']?.text ?? product.category,
        stock: int.tryParse(_productControllers['${product.id}_stock']?.text ?? '') ?? product.stock,
        createdAt: product.createdAt,
        imageUrl: product.imageUrl,
        thumbnailUrl: product.thumbnailUrl,
        imageUrl2: product.imageUrl2,
        dimensions: product.dimensions,
        weight: product.weight,
        voltage: product.voltage,
        amperage: product.amperage,
        warehouse: product.warehouse,
      );

      await FirebaseDatabase.instance.ref('products/${product.id}').update(updatedProduct.toMap());

      setState(() {
        _editingProducts.remove(product.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to update product', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEditingProduct(Product product) {
    setState(() {
      _editingProducts.add(product.id!);
      _productControllers['${product.id}_sku'] = TextEditingController(text: product.sku);
      _productControllers['${product.id}_model'] = TextEditingController(text: product.model);
      _productControllers['${product.id}_name'] = TextEditingController(text: product.name);
      _productControllers['${product.id}_description'] = TextEditingController(text: product.description);
      _productControllers['${product.id}_price'] = TextEditingController(text: product.price.toString());
      _productControllers['${product.id}_category'] = TextEditingController(text: product.category);
      _productControllers['${product.id}_stock'] = TextEditingController(text: product.stock.toString());
    });
  }

  void _cancelEditingProduct(String productId) {
    setState(() {
      _editingProducts.remove(productId);
      // Clean up controllers
      ['sku', 'model', 'name', 'description', 'price', 'category', 'stock'].forEach((field) {
        _productControllers['${productId}_$field']?.dispose();
        _productControllers.remove('${productId}_$field');
      });
    });
  }

  // User CRUD Operations
  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
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
        await FirebaseDatabase.instance.ref('users/$userId').remove();
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

  Future<void> _saveUserChanges(String userId, Map<String, dynamic> userData) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm User Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to save these changes?'),
            const SizedBox(height: 16),
            Text('Name: ${_userControllers['${userId}_name']?.text}', style: const TextStyle(fontSize: 12)),
            Text('Email: ${_userControllers['${userId}_email']?.text}', style: const TextStyle(fontSize: 12)),
            Text('Role: ${_userControllers['${userId}_role']?.text}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final updates = {
        'displayName': _userControllers['${userId}_name']?.text ?? userData['displayName'],
        'email': _userControllers['${userId}_email']?.text ?? userData['email'],
        'role': _userControllers['${userId}_role']?.text ?? userData['role'],
        'isApproved': userData['isApproved'] ?? false,
      };

      await FirebaseDatabase.instance.ref('users/$userId').update(updates);

      setState(() {
        _editingUsers.remove(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to update user', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEditingUser(String userId, Map<String, dynamic> userData) {
    setState(() {
      _editingUsers.add(userId);
      _userControllers['${userId}_name'] = TextEditingController(text: userData['displayName'] ?? '');
      _userControllers['${userId}_email'] = TextEditingController(text: userData['email'] ?? '');
      _userControllers['${userId}_role'] = TextEditingController(text: userData['role'] ?? 'user');
    });
  }

  void _cancelEditingUser(String userId) {
    setState(() {
      _editingUsers.remove(userId);
      // Clean up controllers
      ['name', 'email', 'role'].forEach((field) {
        _userControllers['${userId}_$field']?.dispose();
        _userControllers.remove('${userId}_$field');
      });
    });
  }

  Future<void> _toggleUserApproval(String userId, bool currentStatus) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseDatabase.instance.ref('users/$userId/isApproved').set(!currentStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${!currentStatus ? 'approved' : 'unapproved'} successfully')),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to toggle user approval', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user approval: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProductsTable() {
    return StreamBuilder<List<Product>>(
      stream: FirebaseDatabase.instance.ref('products').onValue.map((event) {
        if (event.snapshot.value == null) return [];
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return data.entries.map((e) {
          final productData = Map<String, dynamic>.from(e.value as Map);
          productData['id'] = e.key;
          return Product.fromJson(productData);
        }).toList()
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var products = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          products = products.where((p) {
            final query = _searchQuery.toLowerCase();
            return (p.sku?.toLowerCase().contains(query) ?? false) ||
                   (p.model?.toLowerCase().contains(query) ?? false) ||
                   (p.name?.toLowerCase().contains(query) ?? false) ||
                   (p.description?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        // Apply category filter
        if (_selectedCategory != 'All') {
          products = products.where((p) => p.category == _selectedCategory).toList();
        }

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
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    items: ['All', 'Refrigeration', 'Freezers', 'Prep Tables', 'Other']
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProductDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                  ),
                ],
              ),
            ),

            // Data table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Model')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Stock')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: products.map((product) {
                      final isEditing = _editingProducts.contains(product.id);

                      return DataRow(
                        cells: [
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _productControllers['${product.id}_sku'],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text(product.sku ?? '-'),
                          ),
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _productControllers['${product.id}_model'],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text(product.model ?? '-'),
                          ),
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _productControllers['${product.id}_name'],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text(product.name ?? '-'),
                          ),
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _productControllers['${product.id}_category'],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text(product.category ?? '-'),
                          ),
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _productControllers['${product.id}_price'],
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text('\$${product.price.toStringAsFixed(2)}'),
                          ),
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _productControllers['${product.id}_stock'],
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text(product.stock.toString()),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isEditing) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _startEditingProduct(product),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () => _duplicateProduct(product),
                                    tooltip: 'Duplicate',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () => _deleteProduct(product.id!),
                                    tooltip: 'Delete',
                                    color: Colors.red,
                                  ),
                                ] else ...[
                                  IconButton(
                                    icon: const Icon(Icons.save, size: 20),
                                    onPressed: () => _saveProductChanges(product),
                                    tooltip: 'Save',
                                    color: Colors.green,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, size: 20),
                                    onPressed: () => _cancelEditingProduct(product.id!),
                                    tooltip: 'Cancel',
                                    color: Colors.orange,
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

            // Summary
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Showing ${products.length} products',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersTable() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirebaseDatabase.instance.ref('users').onValue.map((event) {
        if (event.snapshot.value == null) return {};
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!;
        var userEntries = users.entries.toList();

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          userEntries = userEntries.where((entry) {
            final userData = Map<String, dynamic>.from(entry.value);
            final query = _searchQuery.toLowerCase();
            return (userData['displayName']?.toString().toLowerCase().contains(query) ?? false) ||
                   (userData['email']?.toString().toLowerCase().contains(query) ?? false);
          }).toList();
        }

        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUserDialog(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add User'),
                  ),
                ],
              ),
            ),

            // Data table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: userEntries.map((entry) {
                      final userId = entry.key;
                      final userData = Map<String, dynamic>.from(entry.value);
                      final isEditing = _editingUsers.contains(userId);
                      final isApproved = userData['isApproved'] ?? false;

                      return DataRow(
                        cells: [
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _userControllers['${userId}_name'],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text(userData['displayName'] ?? '-'),
                          ),
                          DataCell(
                            isEditing
                                ? TextField(
                                    controller: _userControllers['${userId}_email'],
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Text(userData['email'] ?? '-'),
                          ),
                          DataCell(
                            isEditing
                                ? DropdownButton<String>(
                                    value: _userControllers['${userId}_role']?.text ?? 'user',
                                    items: ['user', 'admin', 'superadmin']
                                        .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                                        .toList(),
                                    onChanged: (value) {
                                      _userControllers['${userId}_role']?.text = value!;
                                      setState(() {});
                                    },
                                  )
                                : Chip(
                                    label: Text(userData['role'] ?? 'user'),
                                    backgroundColor: userData['role'] == 'superadmin'
                                        ? Colors.purple
                                        : userData['role'] == 'admin'
                                            ? Colors.blue
                                            : Colors.grey,
                                  ),
                          ),
                          DataCell(
                            Switch(
                              value: isApproved,
                              onChanged: (value) => _toggleUserApproval(userId, isApproved),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isEditing) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _startEditingUser(userId, userData),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () => _deleteUser(userId),
                                    tooltip: 'Delete',
                                    color: Colors.red,
                                  ),
                                ] else ...[
                                  IconButton(
                                    icon: const Icon(Icons.save, size: 20),
                                    onPressed: () => _saveUserChanges(userId, userData),
                                    tooltip: 'Save',
                                    color: Colors.green,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, size: 20),
                                    onPressed: () => _cancelEditingUser(userId),
                                    tooltip: 'Cancel',
                                    color: Colors.orange,
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

            // Summary
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Showing ${userEntries.length} users',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddProductDialog() {
    final controllers = {
      'sku': TextEditingController(),
      'model': TextEditingController(),
      'name': TextEditingController(),
      'description': TextEditingController(),
      'price': TextEditingController(),
      'category': TextEditingController(),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controllers['sku'],
                decoration: const InputDecoration(labelText: 'SKU'),
              ),
              TextField(
                controller: controllers['model'],
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              TextField(
                controller: controllers['name'],
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: controllers['description'],
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextField(
                controller: controllers['price'],
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              ),
              TextField(
                controller: controllers['category'],
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newProduct = Product(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                sku: controllers['sku']!.text,
                model: controllers['model']!.text,
                displayName: controllers['name']!.text,
                name: controllers['name']!.text,
                description: controllers['description']!.text,
                price: double.tryParse(controllers['price']!.text) ?? 0,
                category: controllers['category']!.text,
                stock: 0,
                createdAt: DateTime.now(),
              );

              try {
                await FirebaseDatabase.instance.ref('products/${newProduct.id}').set(newProduct.toMap());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add product: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      controllers.values.forEach((c) => c.dispose());
    });
  }

  void _showAddUserDialog() {
    final controllers = {
      'name': TextEditingController(),
      'email': TextEditingController(),
      'password': TextEditingController(),
      'role': TextEditingController(text: 'user'),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controllers['name'],
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: controllers['email'],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: controllers['password'],
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              DropdownButtonFormField<String>(
                value: controllers['role']!.text,
                decoration: const InputDecoration(labelText: 'Role'),
                items: ['user', 'admin', 'superadmin']
                    .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                    .toList(),
                onChanged: (value) => controllers['role']!.text = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Create user in Firebase Auth
                final credential = await auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: controllers['email']!.text,
                  password: controllers['password']!.text,
                );

                // Update display name
                await credential.user?.updateDisplayName(controllers['name']!.text);

                // Save user data to database
                await FirebaseDatabase.instance.ref('users/${credential.user!.uid}').set({
                  'displayName': controllers['name']!.text,
                  'email': controllers['email']!.text,
                  'role': controllers['role']!.text,
                  'isApproved': true,
                  'createdAt': ServerValue.timestamp,
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add user: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      controllers.values.forEach((c) => c.dispose());
    });
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