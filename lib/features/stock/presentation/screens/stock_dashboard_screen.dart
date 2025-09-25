import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/models.dart';
import '../../../../core/providers/enhanced_providers.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/services/app_logger.dart';

// Helper function to check if user is admin or superadmin
bool _isAdminOrSuperAdmin(String? email) {
  if (email == null) return false;
  final userEmail = email.toLowerCase();
  return userEmail == EnvConfig.adminEmail?.toLowerCase() ||
         userEmail == 'admin@turboairinc.com' ||
         userEmail == 'superadmin@turboairinc.com' ||
         userEmail == 'andres@turboairmexico.com';
}

class StockDashboardScreen extends ConsumerStatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  ConsumerState<StockDashboardScreen> createState() => _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, Map<String, dynamic>> _warehouseStock = {};
  Map<String, int> _productStock = {};
  bool _isLoading = true;
  String _selectedWarehouse = 'All';
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _warehouses = [
    'All', 'CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU'
  ];

  final List<String> _categories = [
    'All', 'Refrigeration', 'Freezers', 'Display Cases', 'Prep Tables', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  Future<void> _loadStockData() async {
    setState(() => _isLoading = true);

    // Check if user is admin or superadmin
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdminOrSuperAdmin = _isAdminOrSuperAdmin(currentUser?.email);

    try {
      // Load warehouse stock data
      final warehouseSnapshot = await _database.child('warehouse_stock').get();
      if (warehouseSnapshot.exists && warehouseSnapshot.value != null) {
        final data = Map<String, dynamic>.from(warehouseSnapshot.value as Map);
        _warehouseStock = {};

        data.forEach((warehouse, products) {
          if (products is Map) {
            _warehouseStock[warehouse] = Map<String, dynamic>.from(products);
          }
        });
      } else {
        // Use mock warehouse stock if no real data (only for admins in debug mode)
        if (kDebugMode && isAdminOrSuperAdmin) {
          AppLogger.debug('Using mock warehouse stock data for admin in debug mode', category: LogCategory.database);
          _warehouseStock = _getMockWarehouseStock();
        }
      }

      // Load product stock levels
      final stockSnapshot = await _database.child('products').get();
      if (stockSnapshot.exists && stockSnapshot.value != null) {
        final products = Map<String, dynamic>.from(stockSnapshot.value as Map);
        _productStock = {};

        products.forEach((key, value) {
          if (value is Map && value['stock'] != null) {
            _productStock[key] = value['stock'] as int;
          }
        });
      } else {
        // Use mock product stock if no real data (only for admins in debug mode)
        if (kDebugMode && isAdminOrSuperAdmin) {
          AppLogger.debug('Using mock product stock data for admin in debug mode', category: LogCategory.database);
          _productStock = _getMockProductStock();
        }
      }
    } catch (e) {
      AppLogger.error('Error loading stock data', error: e, category: LogCategory.database);
      // Use mock data on error only for admins in debug mode
      if (kDebugMode && isAdminOrSuperAdmin) {
        AppLogger.debug('Using mock stock data due to error (admin in debug mode)', category: LogCategory.database);
        _warehouseStock = _getMockWarehouseStock();
        _productStock = _getMockProductStock();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Product> _getFilteredProducts() {
    final productsAsync = ref.watch(enhancedProductsProvider(null));

    return productsAsync.when(
      data: (products) {
        var filtered = products;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((p) {
            final query = _searchQuery.toLowerCase();
            return (p.sku?.toLowerCase().contains(query) ?? false) ||
                   (p.model?.toLowerCase().contains(query) ?? false) ||
                   (p.name?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        // Apply category filter
        if (_selectedCategory != 'All') {
          filtered = filtered.where((p) {
            return p.category == _selectedCategory;
          }).toList();
        }

        return filtered;
      },
      loading: () => [],
      error: (_, __) => [],
    );
  }

  int _getTotalStock(String sku) {
    if (_selectedWarehouse == 'All') {
      int total = 0;
      _warehouseStock.forEach((warehouse, products) {
        if (products[sku] != null) {
          total += (products[sku]['quantity'] as int? ?? 0);
        }
      });
      return total;
    } else {
      final warehouseData = _warehouseStock[_selectedWarehouse];
      if (warehouseData != null && warehouseData[sku] != null) {
        return warehouseData[sku]['quantity'] as int? ?? 0;
      }
      return 0;
    }
  }

  Color _getStockColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 5) return Colors.orange;
    if (stock < 10) return Colors.amber;
    return Colors.green;
  }

  String _getStockStatus(int stock) {
    if (stock == 0) return 'Out of Stock';
    if (stock < 5) return 'Low Stock';
    if (stock < 10) return 'Limited Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    final products = _getFilteredProducts();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Inventory Management',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF000000),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadStockData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Stock Data',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Filters Row
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDarkMode
                            ? Colors.white.withValues(alpha:0.1)
                            : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search by SKU, Model, or Name...',
                            hintStyle: TextStyle(
                              color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.grey.shade600,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.grey.shade600,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xFF000000),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Warehouse Filter
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                          ? Colors.white.withValues(alpha:0.1)
                          : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedWarehouse,
                          dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xFF000000),
                          ),
                          items: _warehouses.map((warehouse) {
                            return DropdownMenuItem(
                              value: warehouse,
                              child: Text(warehouse),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedWarehouse = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Category Filter
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                          ? Colors.white.withValues(alpha:0.1)
                          : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xFF000000),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSummaryCard(
                        'Total Products',
                        products.length.toString(),
                        Icons.inventory_2,
                        Colors.blue,
                        isDarkMode,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'In Stock',
                        products.where((p) => _getTotalStock(p.sku ?? '') > 10).length.toString(),
                        Icons.check_circle,
                        Colors.green,
                        isDarkMode,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Low Stock',
                        products.where((p) {
                          final stock = _getTotalStock(p.sku ?? '');
                          return stock > 0 && stock < 5;
                        }).length.toString(),
                        Icons.warning,
                        Colors.orange,
                        isDarkMode,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Out of Stock',
                        products.where((p) => _getTotalStock(p.sku ?? '') == 0).length.toString(),
                        Icons.error,
                        Colors.red,
                        isDarkMode,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stock Table
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                ? Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDarkMode
                              ? Colors.white.withValues(alpha:0.05)
                              : Colors.grey.shade50,
                          ),
                          columns: const [
                            DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Stock Level', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: products.take(100).map((product) {
                            final stock = _getTotalStock(product.sku ?? '');
                            final status = _getStockStatus(stock);
                            final color = _getStockColor(stock);

                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  product.sku ?? 'N/A',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : const Color(0xFF000000),
                                  ),
                                )),
                                DataCell(Text(
                                  product.name ?? product.model ?? 'Unknown',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : const Color(0xFF000000),
                                  ),
                                )),
                                DataCell(Text(
                                  product.category ?? 'Uncategorized',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                                  ),
                                )),
                                DataCell(Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      stock.toString(),
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha:0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility, size: 18),
                                      onPressed: () => _showStockDetails(product, stock),
                                      tooltip: 'View Details',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _editStock(product),
                                      tooltip: 'Edit Stock',
                                    ),
                                  ],
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF000000),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStockDetails(Product product, int totalStock) {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          title: Text(
            'Stock Details: ${product.sku}',
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF000000),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name ?? product.model ?? 'Unknown Product',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Warehouse Breakdown:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ..._warehouses.skip(1).map((warehouse) {
                  final warehouseData = _warehouseStock[warehouse];
                  final stock = warehouseData?[product.sku]?['quantity'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          warehouse,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          stock.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStockColor(stock),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Stock:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF000000),
                      ),
                    ),
                    Text(
                      totalStock.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _getStockColor(totalStock),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _editStock(Product product) {
    final controller = TextEditingController();
    String selectedWarehouse = _warehouses[1]; // Default to first actual warehouse

    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          title: Text(
            'Edit Stock: ${product.sku}',
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF000000),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedWarehouse,
                decoration: InputDecoration(
                  labelText: 'Warehouse',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF000000),
                ),
                items: _warehouses.skip(1).map((warehouse) {
                  return DropdownMenuItem(
                    value: warehouse,
                    child: Text(warehouse),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedWarehouse = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New Stock Quantity',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF000000),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantity = int.tryParse(controller.text);
                if (quantity != null && quantity >= 0) {
                  await _updateStock(product.sku ?? '', selectedWarehouse, quantity);
                  if (context.mounted) Navigator.of(context).pop();
                  await _loadStockData();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateStock(String sku, String warehouse, int quantity) async {
    try {
      await _database.child('warehouse_stock/$warehouse/$sku').set({
        'quantity': quantity,
        'lastUpdated': ServerValue.timestamp,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock updated for $sku in $warehouse'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mock warehouse stock data generator - ONLY FOR ADMINS/SUPERADMINS IN DEBUG MODE
  // This function should never be called in production or for non-admin users
  // All calls are protected by kDebugMode && isAdminOrSuperAdmin checks
  Map<String, Map<String, dynamic>> _getMockWarehouseStock() {
    assert(kDebugMode, 'Mock warehouse stock should not be used in production');

    // Additional safety: Log when mock data is being used
    AppLogger.debug(
      'WARNING: Using mock warehouse stock data - This should only happen for admins in debug mode',
      category: LogCategory.security,
    );

    return {
      'CA': {
        'TSR-49SD': {'quantity': 15, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TBF-2SD': {'quantity': 8, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'PRO-26R': {'quantity': 12, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'M3R48': {'quantity': 6, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TGF-23F': {'quantity': 0, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
      },
      'CA1': {
        'TSR-49SD': {'quantity': 22, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TBF-2SD': {'quantity': 14, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'PRO-26R': {'quantity': 9, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'M3R48': {'quantity': 18, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TGF-23F': {'quantity': 4, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
      },
      'CA2': {
        'TSR-49SD': {'quantity': 11, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TBF-2SD': {'quantity': 7, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'PRO-26R': {'quantity': 25, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'M3R48': {'quantity': 13, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TGF-23F': {'quantity': 3, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
      },
      'MEE': {
        'TSR-49SD': {'quantity': 8, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TBF-2SD': {'quantity': 12, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'PRO-26R': {'quantity': 16, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'M3R48': {'quantity': 5, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TGF-23F': {'quantity': 9, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
      },
      'XCA': {
        'TSR-49SD': {'quantity': 19, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TBF-2SD': {'quantity': 6, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'PRO-26R': {'quantity': 14, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'M3R48': {'quantity': 21, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
        'TGF-23F': {'quantity': 2, 'lastUpdated': DateTime.now().millisecondsSinceEpoch},
      },
    };
  }

  // Mock product stock data generator - ONLY FOR ADMINS/SUPERADMINS IN DEBUG MODE
  // This function should never be called in production or for non-admin users
  // All calls are protected by kDebugMode && isAdminOrSuperAdmin checks
  Map<String, int> _getMockProductStock() {
    assert(kDebugMode, 'Mock product stock should not be used in production');

    // Additional safety: Log when mock data is being used
    AppLogger.debug(
      'WARNING: Using mock product stock data - This should only happen for admins in debug mode',
      category: LogCategory.security,
    );

    return {
      'TSR-49SD': 75,
      'TBF-2SD': 47,
      'PRO-26R': 76,
      'M3R48': 63,
      'TGF-23F': 18,
      'TGM-50F': 45,
      'TSR-23SD': 32,
      'M3F72': 28,
      'PRO-50R': 51,
      'TBB-24': 39,
    };
  }
}