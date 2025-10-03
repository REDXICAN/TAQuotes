import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/app_logger.dart';

// Improved provider that properly loads warehouse stock
final warehouseStockProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return FirebaseDatabase.instance.ref('warehouse_stock').onValue.map((event) {
    if (event.snapshot.value == null) {
      // If warehouse_stock doesn't exist, try loading from products
      return <String, dynamic>{};
    }

    try {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final stockData = <String, dynamic>{};

      data.forEach((productId, warehouseData) {
        if (warehouseData is Map) {
          stockData[productId] = Map<String, dynamic>.from(warehouseData);
        }
      });

      return stockData;
    } catch (e) {
      AppLogger.error('Error parsing warehouse stock data', error: e);
      return <String, dynamic>{};
    }
  }).handleError((error) {
    AppLogger.error('Error loading warehouse stock', error: error);
    return <String, dynamic>{};
  });
});

// Provider for products with warehouse stock info
final productsWithStockProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  return FirebaseDatabase.instance.ref('products').onValue.map((event) {
    if (event.snapshot.value == null) return <Product>[];

    try {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final products = <Product>[];

      data.forEach((key, value) {
        if (value is Map) {
          final productMap = Map<String, dynamic>.from(value);
          productMap['id'] = key;

          // Ensure we have warehouse stock data
          if (productMap['warehouseStock'] == null) {
            // Create default warehouse stock if missing
            productMap['warehouseStock'] = {
              'TX': {'available': productMap['stock'] ?? 0, 'reserved': 0},
            };
          }

          products.add(Product.fromMap(productMap));
        }
      });

      // Sort by total stock descending
      products.sort((a, b) {
        int getTotal(Product p) {
          if (p.warehouseStock == null) return p.stock;
          int total = 0;
          p.warehouseStock!.forEach((_, data) {
            total += (data.available - data.reserved);
          });
          return total;
        }
        return getTotal(b).compareTo(getTotal(a));
      });

      return products;
    } catch (e) {
      AppLogger.error('Error loading products with stock', error: e);
      return <Product>[];
    }
  }).handleError((error) {
    AppLogger.error('Error in products stream', error: error);
    return <Product>[];
  });
});

class StockDashboardScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const StockDashboardScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  ConsumerState<StockDashboardScreen> createState() => _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  String searchQuery = '';
  String selectedCategory = 'All';
  String selectedWarehouse = 'All';
  final searchController = TextEditingController();

  final warehouses = ['All', 'TX', 'KR', 'VN', 'CN', 'CUN', 'CDMX'];
  final categories = ['All', 'Refrigeration', 'Freezers', 'Cooking', 'Preparation', 'Display'];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Map<String, int> _calculateStockByCategory(List<Product> products) {
    final Map<String, int> categoryStock = {};

    for (final product in products) {
      final category = product.category.isEmpty ? 'Uncategorized' : product.category;
      int totalStock = 0;

      if (product.warehouseStock != null) {
        product.warehouseStock!.forEach((_, data) {
          totalStock += (data.available - data.reserved);
        });
      } else {
        totalStock = product.stock;
      }

      categoryStock[category] = (categoryStock[category] ?? 0) + totalStock;
    }

    return categoryStock;
  }

  List<Product> _getLowStockItems(List<Product> products) {
    return products.where((product) {
      int totalStock = 0;

      if (product.warehouseStock != null) {
        product.warehouseStock!.forEach((_, data) {
          totalStock += (data.available - data.reserved);
        });
      } else {
        totalStock = product.stock;
      }

      return totalStock > 0 && totalStock <= 5;
    }).toList();
  }

  List<Product> _getOutOfStockItems(List<Product> products) {
    return products.where((product) {
      int totalStock = 0;

      if (product.warehouseStock != null) {
        product.warehouseStock!.forEach((_, data) {
          totalStock += (data.available - data.reserved);
        });
      } else {
        totalStock = product.stock;
      }

      return totalStock <= 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsWithStockProvider);

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('Stock Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
      ) : null,
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading stock data'),
              Text(error.toString(), style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(productsWithStockProvider);
                  ref.invalidate(warehouseStockProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No products found'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(productsWithStockProvider);
                      ref.invalidate(warehouseStockProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          // Calculate metrics
          int totalStock = 0;
          int uniqueSkus = 0;

          for (final product in products) {
            int productStock = 0;

            if (product.warehouseStock != null) {
              product.warehouseStock!.forEach((_, data) {
                productStock += (data.available - data.reserved);
              });
            } else {
              productStock = product.stock;
            }

            if (productStock > 0) {
              uniqueSkus++;
              totalStock += productStock;
            }
          }

          final lowStockItems = _getLowStockItems(products);
          final outOfStockItems = _getOutOfStockItems(products);
          final stockByCategory = _calculateStockByCategory(products);

          // Filter products
          var filteredProducts = products.where((product) {
            // Search filter
            if (searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              return (product.sku?.toLowerCase().contains(query) ?? false) ||
                     product.model.toLowerCase().contains(query) ||
                     product.name.toLowerCase().contains(query);
            }
            return true;
          }).where((product) {
            // Category filter
            if (selectedCategory != 'All') {
              return product.category == selectedCategory;
            }
            return true;
          }).where((product) {
            // Warehouse filter
            if (selectedWarehouse != 'All') {
              if (product.warehouseStock == null) return false;
              final warehouseData = product.warehouseStock![selectedWarehouse];
              if (warehouseData == null) return false;
              final available = warehouseData.available;
              final reserved = warehouseData.reserved;
              return (available - reserved) > 0;
            }
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards Row
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory, color: Colors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Total Stock', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$totalStock',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                                Text('units in stock', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.category, color: Colors.green, size: 20),
                                    SizedBox(width: 8),
                                    Text('Active SKUs', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$uniqueSkus',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                Text('products with stock', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text('Low Stock', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${lowStockItems.length}',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                                Text('items < 5 units', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.error, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Out of Stock', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${outOfStockItems.length}',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                Text('items unavailable', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Filters Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search SKU, model or name...',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() => searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => setState(() => searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: selectedCategory,
                      items: categories.map((cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat))
                      ).toList(),
                      onChanged: (value) => setState(() => selectedCategory = value!),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: selectedWarehouse,
                      items: warehouses.map((wh) =>
                        DropdownMenuItem(value: wh, child: Text(wh))
                      ).toList(),
                      onChanged: (value) => setState(() => selectedWarehouse = value!),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Stock by Category
                if (stockByCategory.isNotEmpty) ...[
                  const Text(
                    'Stock by Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: stockByCategory.length,
                      itemBuilder: (context, index) {
                        final category = stockByCategory.keys.elementAt(index);
                        final stock = stockByCategory[category] ?? 0;
                        return Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$stock units',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Products Table
                const Text(
                  'Product Inventory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (filteredProducts.isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: const Text('No products match your filters'),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('Model')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('TX'), numeric: true),
                          DataColumn(label: Text('KR'), numeric: true),
                          DataColumn(label: Text('VN'), numeric: true),
                          DataColumn(label: Text('CN'), numeric: true),
                          DataColumn(label: Text('CUN'), numeric: true),
                          DataColumn(label: Text('CDMX'), numeric: true),
                          DataColumn(label: Text('Total'), numeric: true),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: filteredProducts.take(100).map((product) {
                          final stocks = <String, int>{};
                          int total = 0;

                          // Calculate stock for each warehouse
                          for (final wh in ['TX', 'KR', 'VN', 'CN', 'CUN', 'CDMX']) {
                            if (product.warehouseStock != null) {
                              final data = product.warehouseStock![wh];
                              if (data != null) {
                                final available = data.available;
                                final reserved = data.reserved;
                                stocks[wh] = available - reserved;
                                total += stocks[wh]!;
                              } else {
                                stocks[wh] = 0;
                              }
                            } else {
                              stocks[wh] = 0;
                            }
                          }

                          // Determine status
                          String status = 'In Stock';
                          Color statusColor = Colors.green;
                          if (total <= 0) {
                            status = 'Out of Stock';
                            statusColor = Colors.red;
                          } else if (total <= 5) {
                            status = 'Low Stock';
                            statusColor = Colors.orange;
                          }

                          return DataRow(
                            cells: [
                              DataCell(Text(product.sku ?? '')),
                              DataCell(Text(product.model)),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 200),
                                  child: Text(
                                    product.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(stocks['TX'].toString())),
                              DataCell(Text(stocks['KR'].toString())),
                              DataCell(Text(stocks['VN'].toString())),
                              DataCell(Text(stocks['CN'].toString())),
                              DataCell(Text(stocks['CUN'].toString())),
                              DataCell(Text(stocks['CDMX'].toString())),
                              DataCell(
                                Text(
                                  total.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(
                                Chip(
                                  label: Text(status, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: statusColor.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(color: statusColor),
                                  visualDensity: VisualDensity.compact,
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
          );
        },
      ),
    );
  }
}