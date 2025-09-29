import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';

// Provider for stock data from Firebase
final stockDataProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return FirebaseDatabase.instance.ref('products').onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    final stockData = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Map) {
        final product = Map<String, dynamic>.from(value);
        final stock = product['stock'] ?? product['totalStock'] ?? product['availableStock'] ?? 0;
        if (stock > 0) {
          stockData[key] = {
            'available': stock,
            'warehouse': product['warehouse'] ?? '999',
          };
        }
      }
    });

    return stockData;
  });
});

// Provider for products from Firebase (sorted by stock volume)
final productsForStockProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  return FirebaseDatabase.instance.ref('products').onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    final products = <Product>[];

    data.forEach((key, value) {
      if (value is Map) {
        final productMap = Map<String, dynamic>.from(value);
        productMap['id'] = key;
        products.add(Product.fromMap(productMap));
      }
    });

    // Sort by stock volume descending
    products.sort((a, b) => (b.stock ?? 0).compareTo(a.stock ?? 0));
    return products;
  });
});

class StockDashboardScreen extends ConsumerStatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  ConsumerState<StockDashboardScreen> createState() => _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  String selectedWarehouse = 'All';
  String selectedCategory = 'All';
  String searchQuery = '';

  final warehouses = ['All', '999', 'CA', 'CA1', 'CA2', 'CA3', 'CA4', 'COCZ', 'COPZ', 'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU', 'XZRE', 'ZRE'];
  final categories = ['All', 'Refrigeration', 'Freezers', 'Prep Tables', 'Display Cases', 'Ice Machines'];

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockDataProvider);
    final productsAsync = ref.watch(productsForStockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
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

            // Calculate warehouse distribution
            final stockByWarehouse = _calculateStockByWarehouse(stockData);

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

                  // Warehouse Distribution Chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stock by Warehouse',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 300,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: stockByWarehouse.values.isEmpty
                                    ? 100
                                    : stockByWarehouse.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipRoundedRadius: 8,
                                    tooltipPadding: const EdgeInsets.all(8),
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final warehouse = stockByWarehouse.keys.elementAt(groupIndex);
                                      final stock = rod.toY.toInt();
                                      return BarTooltipItem(
                                        '$warehouse\n$stock units',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < stockByWarehouse.keys.length) {
                                          final warehouse = stockByWarehouse.keys.elementAt(index);
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              warehouse,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: stockByWarehouse.entries.map((entry) {
                                  final index = stockByWarehouse.keys.toList().indexOf(entry.key);
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.toDouble(),
                                        color: _getWarehouseColor(entry.key),
                                        width: 40,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          topRight: Radius.circular(4),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Category Distribution Chart
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
                            SizedBox(
                              height: 300,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: stockByCategory.entries.map((entry) {
                                    final percentage = (entry.value / totalStock * 100);
                                    return PieChartSectionData(
                                      value: entry.value.toDouble(),
                                      title: '${percentage.toStringAsFixed(1)}%',
                                      color: _getCategoryColor(entry.key),
                                      radius: 100,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          // Legend
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: stockByCategory.entries.map((entry) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(entry.key),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.key}: ${entry.value}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
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
                                  value: selectedCategory,
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
                                final stock = product.stock ?? 0;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(product.sku ?? '')),
                                    DataCell(Text(product.name, overflow: TextOverflow.ellipsis)),
                                    DataCell(Text(product.category ?? 'Uncategorized')),
                                    DataCell(
                                      Text(
                                        stock.toString(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getStockStatusColor(stock),
                                        ),
                                      ),
                                    ),
                                    DataCell(_buildStockStatusChip(stock)),
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

  Map<String, int> _calculateStockByWarehouse(Map<String, dynamic> stockData) {
    final stockByWarehouse = <String, int>{};

    stockData.forEach((key, value) {
      if (value is Map) {
        final warehouse = value['warehouse'] ?? '999';
        final stock = value['available'] as int? ?? 0;
        stockByWarehouse[warehouse] = (stockByWarehouse[warehouse] ?? 0) + stock;
      }
    });

    return stockByWarehouse;
  }

  Map<String, int> _calculateStockByCategory(Map<String, dynamic> stockData, List<Product> products) {
    final stockByCategory = <String, int>{};

    for (final product in products) {
      final category = product.category ?? 'Uncategorized';
      final stock = product.stock ?? 0;
      if (stock > 0) {
        stockByCategory[category] = (stockByCategory[category] ?? 0) + stock;
      }
    }

    return stockByCategory;
  }

  List<MapEntry<String, dynamic>> _getLowStockItems(Map<String, dynamic> stockData, List<Product> products) {
    final lowStock = <MapEntry<String, dynamic>>[];

    for (final product in products) {
      final stock = product.stock ?? 0;
      if (stock > 0 && stock < 5) {
        lowStock.add(MapEntry(product.sku ?? '', {'available': stock}));
      }
    }

    return lowStock;
  }

  List<MapEntry<String, dynamic>> _getOutOfStockItems(Map<String, dynamic> stockData, List<Product> products) {
    final outOfStock = <MapEntry<String, dynamic>>[];

    for (final product in products) {
      if ((product.stock ?? 0) == 0) {
        outOfStock.add(MapEntry(product.sku ?? '', {'available': 0}));
      }
    }

    return outOfStock;
  }

  Color _getWarehouseColor(String warehouse) {
    switch (warehouse) {
      case '999':
        return Colors.blue;
      case 'CA':
        return Colors.purple;
      case 'CA1':
        return Colors.red;
      case 'CA2':
        return Colors.orange;
      case 'CA3':
        return Colors.green;
      case 'CA4':
        return Colors.teal;
      case 'COCZ':
        return Colors.indigo;
      case 'COPZ':
        return Colors.pink;
      case 'INT':
        return Colors.amber;
      case 'MEE':
        return Colors.cyan;
      case 'PU':
        return Colors.lime;
      case 'SI':
        return Colors.brown;
      case 'XCA':
        return Colors.deepOrange;
      case 'XPU':
        return Colors.deepPurple;
      case 'XZRE':
        return Colors.lightBlue;
      case 'ZRE':
        return Colors.lightGreen;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Refrigeration':
        return Colors.blue;
      case 'Freezers':
        return Colors.cyan;
      case 'Prep Tables':
        return Colors.green;
      case 'Display Cases':
        return Colors.orange;
      case 'Ice Machines':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}