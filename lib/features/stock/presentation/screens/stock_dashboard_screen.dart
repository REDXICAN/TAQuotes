import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/providers/test_mode_provider.dart';
import '../../../../core/services/spare_parts_demo_service.dart';
import '../../../../core/services/app_logger.dart';

// Provider for stock data - uses test data if test mode is enabled - Changed to FutureProvider to prevent freezing
final stockDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final isTestMode = ref.watch(testModeProvider);

  if (isTestMode) {
    // Use demo data in test mode
    return _generateDemoStockData();
  }

  // Use real Firebase data in production - one-time fetch
  try {
    final event = await FirebaseDatabase.instance.ref('products').get();
    final data = event.value as Map<dynamic, dynamic>? ?? {};
    final stockData = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Map) {
        final product = Map<String, dynamic>.from(value);

        // Check if product has warehouse stock data (new structure)
        if (product['warehouseStock'] != null && product['warehouseStock'] is Map) {
          final warehouseStock = Map<String, dynamic>.from(product['warehouseStock'] as Map);

          // Calculate total stock across all warehouses
          int totalAvailable = 0;
          String primaryWarehouse = '999';

          warehouseStock.forEach((warehouseKey, warehouseValue) {
            if (warehouseValue is Map) {
              final stockInfo = Map<String, dynamic>.from(warehouseValue);
              final available = stockInfo['available'] ?? 0;
              final reserved = stockInfo['reserved'] ?? 0;
              totalAvailable += (available - reserved) as int;

              // Set primary warehouse to first non-zero stock location
              if (totalAvailable > 0 && primaryWarehouse == '999') {
                primaryWarehouse = warehouseKey;
              }
            }
          });

          stockData[key] = {
            'available': totalAvailable,
            'warehouse': primaryWarehouse,
            'warehouseStock': warehouseStock, // Include full warehouse data
          };
        } else {
          // Fallback to legacy stock field
          final stock = product['stock'] ?? product['totalStock'] ?? product['availableStock'] ?? 0;
          stockData[key] = {
            'available': stock,
            'warehouse': product['warehouse'] ?? '999',
          };
        }
      }
    });

    return stockData;
  } catch (error) {
    AppLogger.error('Error loading stock data', error: error);
    return _generateDemoStockData();
  }
});

// Generate demo stock data for test mode
Map<String, dynamic> _generateDemoStockData() {
  // demoService kept for potential future demo data expansion
  // ignore: unused_local_variable
  final demoService = SparePartsDemoService();
  final stockData = <String, dynamic>{};

  // Generate 50 demo stock entries
  for (int i = 0; i < 50; i++) {
    final sku = 'DEMO-SKU-${i.toString().padLeft(3, '0')}';
    stockData[sku] = {
      'available': (i * 10) % 100 + 5,  // Varying stock levels
      'warehouse': ['999', 'CA', 'PU', 'SI', 'XCA'][i % 5],  // Rotate through warehouses
    };
  }

  return stockData;
}

// Provider for products - uses test data if test mode is enabled - Changed to FutureProvider to prevent freezing
final productsForStockProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final isTestMode = ref.watch(testModeProvider);

  if (isTestMode) {
    // Use demo products in test mode
    return _generateDemoProducts();
  }

  // Use real Firebase data in production - one-time fetch
  try {
    final event = await FirebaseDatabase.instance.ref('products').get();
    final data = event.value as Map<dynamic, dynamic>? ?? {};
    final products = <Product>[];

    data.forEach((key, value) {
      if (value is Map) {
        final productMap = Map<String, dynamic>.from(value);
        productMap['id'] = key;
        products.add(Product.fromMap(productMap));
      }
    });

    // Sort by stock volume descending
    products.sort((a, b) => b.stock.compareTo(a.stock));
    return products;
  } catch (error) {
    AppLogger.error('Error loading products for stock', error: error);
    return _generateDemoProducts();
  }
});

// Generate demo products for test mode
List<Product> _generateDemoProducts() {
  final products = <Product>[];
  final categories = ['Refrigeration', 'Freezers', 'Prep Tables', 'Display Cases', 'Parts'];

  for (int i = 0; i < 50; i++) {
    products.add(Product(
      id: 'demo-$i',
      sku: 'DEMO-SKU-${i.toString().padLeft(3, '0')}',
      model: 'DEMO-MODEL-${i + 1}',
      displayName: 'Demo Product ${i + 1}',
      name: 'Demo Product ${i + 1}',
      description: 'This is a demo product for testing purposes',
      price: 1000 + (i * 50).toDouble(),
      category: categories[i % categories.length],
      stock: (i * 10) % 100 + 5,
      warehouse: ['999', 'CA', 'PU', 'SI', 'XCA'][i % 5],
      createdAt: DateTime.now().subtract(Duration(days: i)),
    ));
  }

  // Sort by stock volume descending
  products.sort((a, b) => b.stock.compareTo(a.stock));
  return products;
}

class StockDashboardScreen extends ConsumerStatefulWidget {
  /// Whether to show the app bar (false when embedded in CatalogScreen)
  final bool showAppBar;

  const StockDashboardScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  ConsumerState<StockDashboardScreen> createState() => _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  String selectedWarehouse = 'All';
  String selectedCategory = 'All';
  String searchQuery = '';

  final categories = ['All', 'Refrigeration', 'Freezers', 'Prep Tables', 'Display Cases', 'Ice Machines'];

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockDataProvider);
    final productsAsync = ref.watch(productsForStockProvider);
    final isTestMode = ref.watch(testModeProvider);

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: Row(
          children: [
            const Text('Stock Management Dashboard'),
            if (isTestMode) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TEST MODE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ) : null,
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(stockDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stockData) => productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error loading products: $error')),
          data: (products) {
            // Calculate total stock
            int totalStock = 0;
            stockData.forEach((key, value) {
              if (value is Map) {
                totalStock += (value['available'] as int? ?? 0);
              }
            });

            // Calculate unique SKUs with stock
            final skusWithStock = stockData.keys.where((key) {
              final stock = stockData[key];
              if (stock is Map) {
                return (stock['available'] as int? ?? 0) > 0;
              }
              return false;
            }).length;

            // Calculate category distribution
            final stockByCategory = _calculateStockByCategory(stockData, products);

            // Filter products based on search and filters
            var filteredProducts = products.where((product) {
              // Search filter
              if (searchQuery.isNotEmpty) {
                final query = searchQuery.toLowerCase();
                return (product.sku?.toLowerCase().contains(query) ?? false) ||
                       (product.name.toLowerCase().contains(query));
              }
              return true;
            }).where((product) {
              // Category filter
              if (selectedCategory != 'All') {
                return product.category == selectedCategory;
              }
              return true;
            }).where((product) {
              // Warehouse filter - for now just show all if Main selected
              return true;
            }).toList();

            // Get low stock and out of stock items
            final lowStockItems = _getLowStockItems(stockData, products);
            final outOfStockItems = _getOutOfStockItems(stockData, products);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Stock',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  totalStock.toString(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const Text(
                                  'units',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Unique SKUs',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  skusWithStock.toString(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const Text(
                                  'with stock',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Low Stock',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lowStockItems.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const Text(
                                  'items < 5 units',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Out of Stock',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  outOfStockItems.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const Text(
                                  'items',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Category Distribution Table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stock by Category',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (stockByCategory.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('No category data available'),
                              ),
                            )
                          else
                            Column(
                              children: stockByCategory.entries.map((entry) {
                                final percentage = totalStock > 0 ? (entry.value / totalStock * 100) : 0.0;
                                final categoryColor = _getCategoryColor(entry.key);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: categoryColor.withValues(alpha: 0.3), width: 2),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: categoryColor,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: categoryColor.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: categoryColor.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${entry.value} units',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: categoryColor,
                                            ),
                                          ),
                                          Text(
                                            '${percentage.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: categoryColor.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Filters and Search
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product Inventory',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Search by SKU or Name',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 150,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCategory,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items: categories.map((category) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCategory = value ?? 'All';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Products Table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${filteredProducts.take(50).length} of ${filteredProducts.length} products',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: () => ref.refresh(stockDataProvider),
                                child: const Row(
                                  children: [
                                    Icon(Icons.refresh, size: 16),
                                    SizedBox(width: 4),
                                    Text('Refresh'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('SKU')),
                                DataColumn(label: Text('Product Name')),
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Stock'), numeric: true),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: filteredProducts.take(50).map((product) {
                                final stockValue = product.stock;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(product.sku ?? '')),
                                    DataCell(Text(product.name, overflow: TextOverflow.ellipsis)),
                                    DataCell(Text(product.category)),
                                    DataCell(
                                      Text(
                                        stockValue.toString(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getStockStatusColor(stockValue),
                                        ),
                                      ),
                                    ),
                                    DataCell(_buildStockStatusChip(stockValue)),
                                  ],
                                );
                              }).toList(),
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
        ),
      ),
    );
  }

  Color _getStockStatusColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 5) return Colors.orange;
    if (stock < 20) return Colors.amber;
    return Colors.green;
  }

  Widget _buildStockStatusChip(int stock) {
    String label;
    Color color;

    if (stock == 0) {
      label = 'Out of Stock';
      color = Colors.red;
    } else if (stock < 5) {
      label = 'Low Stock';
      color = Colors.orange;
    } else if (stock < 20) {
      label = 'Limited';
      color = Colors.amber;
    } else {
      label = 'In Stock';
      color = Colors.green;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }


  Map<String, int> _calculateStockByCategory(Map<String, dynamic> stockData, List<Product> products) {
    final stockByCategory = <String, int>{};

    for (final product in products) {
      final category = product.category;
      final stock = product.stock;
      if (stock > 0) {
        stockByCategory[category] = (stockByCategory[category] ?? 0) + stock;
      }
    }

    return stockByCategory;
  }

  List<MapEntry<String, dynamic>> _getLowStockItems(Map<String, dynamic> stockData, List<Product> products) {
    final lowStock = <MapEntry<String, dynamic>>[];

    for (final product in products) {
      final stock = product.stock;
      if (stock > 0 && stock < 5) {
        lowStock.add(MapEntry(product.sku ?? '', {'available': stock}));
      }
    }

    return lowStock;
  }

  List<MapEntry<String, dynamic>> _getOutOfStockItems(Map<String, dynamic> stockData, List<Product> products) {
    final outOfStock = <MapEntry<String, dynamic>>[];

    for (final product in products) {
      final stock = product.stock;
      if (stock == 0) {
        outOfStock.add(MapEntry(product.sku ?? '', {'available': 0}));
      }
    }

    return outOfStock;
  }


  Color _getCategoryColor(String category) {
    // Professional gray color palette for all categories
    // Using Material Design BlueGrey for sophisticated, neutral appearance
    switch (category) {
      // Major Product Categories - Gray Scale
      case 'Open Merchandisers':
        return const Color(0xFF78909C); // Blue Gray 400
      case 'PRO Series':
        return const Color(0xFF607D8B); // Blue Gray 500
      case 'Equipment':
        return const Color(0xFF90A4AE); // Blue Gray 300
      case 'Super Deluxe':
        return const Color(0xFF5D6D7E); // Steel Gray
      case 'Bar Equipment':
        return const Color(0xFF546E7A); // Blue Gray 600
      case 'M3 Series':
        return const Color(0xFF808B96); // Cool Gray
      case 'Commercial Refrigeration':
        return const Color(0xFF455A64); // Blue Gray 700
      case 'Deli Cases':
        return const Color(0xFF6B7680); // Custom Dark Gray
      case 'J Series':
        return const Color(0xFF7C8A95); // Custom Gray
      case 'E-Line':
        return const Color(0xFF8D9499); // Custom Light Gray
      case 'Refrigerated Merchandisers':
        return const Color(0xFF5F6D78); // Custom Medium Gray
      case 'Display Cases':
        return const Color(0xFF37474F); // Blue Gray 800
      case 'Pizza Prep Tables':
        return const Color(0xFF6D7A86); // Custom Gray
      case 'Merchandisers':
        return const Color(0xFF798791); // Custom Gray
      case 'Refrigerators':
        return const Color(0xFF4E5C68); // Custom Dark Gray
      case 'Prep Tables':
        return const Color(0xFF6A7681); // Custom Gray
      case 'Ice Cream':
        return const Color(0xFF858F9A); // Custom Light Gray
      case 'Undercounter':
        return const Color(0xFF526069); // Custom Dark Gray
      case 'Freezers':
        return const Color(0xFF63717C); // Custom Gray

      // Legacy categories (if they exist)
      case 'Refrigeration':
        return const Color(0xFF607D8B); // Blue Gray 500
      case 'Ice Machines':
        return const Color(0xFF546E7A); // Blue Gray 600
      case 'Parts':
      case 'Spare Parts':
        return const Color(0xFF9E9E9E); // Standard Gray 500

      // Default fallback
      default:
        return const Color(0xFF9E9E9E); // Neutral Gray
    }
  }
}