import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/services/excel_inventory_service.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/warehouse_utils.dart';

// Provider for Excel inventory data
final stockDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return await ExcelInventoryService.loadInventoryData();
});

// Provider for products from Excel inventory (sorted by stock volume)
final productsForStockProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  return await ExcelInventoryService.getProductsSortedByStock();
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

  final warehouses = ['All', '999']; // Updated to match Excel file warehouses
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
              Text('Error loading stock data: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(stockDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stockData) => productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (products) => _buildDashboard(stockData, products),
        ),
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> stockData, List<Product> products) {
    // Calculate key metrics
    final totalProducts = products.length;
    final stockByWarehouse = _calculateStockByWarehouse(stockData);
    final lowStockItems = _getLowStockItems(stockData, products);
    final outOfStockItems = _getOutOfStockItems(stockData, products);
    final stockByCategory = _calculateStockByCategory(stockData, products);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          _buildMetricsRow(totalProducts, stockByWarehouse, lowStockItems, outOfStockItems),
          const SizedBox(height: 24),

          // Filters
          _buildFilters(),
          const SizedBox(height: 24),

          // Stock Overview Chart
          _buildStockOverviewChart(stockByWarehouse),
          const SizedBox(height: 24),

          // Category Distribution
          _buildCategoryDistribution(stockByCategory),
          const SizedBox(height: 24),

          // Critical Stock Alerts
          _buildCriticalAlerts(lowStockItems, outOfStockItems, products),
          const SizedBox(height: 24),

          // Detailed Stock Table
          _buildDetailedStockTable(stockData, products),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(int totalProducts, Map<String, int> stockByWarehouse,
                          List<MapEntry<String, dynamic>> lowStock,
                          List<MapEntry<String, dynamic>> outOfStock) {
    final totalStock = stockByWarehouse.values.fold(0, (sum, count) => sum + count);

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Products',
            totalProducts.toString(),
            Icons.inventory,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Total Stock',
            totalStock.toString(),
            Icons.warehouse,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Low Stock',
            lowStock.length.toString(),
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Out of Stock',
            outOfStock.length.toString(),
            Icons.error,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search SKU or Product',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedWarehouse,
                  items: warehouses.map((w) => DropdownMenuItem(
                    value: w,
                    child: Text(w == 'All' ? w : '${w} - ${WarehouseUtils.getShortName(w)}'),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedWarehouse = value!;
                    });
                  },
                ),
                const SizedBox(width: 8),
                WarehouseUtils.createInfoTooltip(
                  context,
                  customMessage: 'Warehouse Information:\\n\\n999 - MERCANCIA APARTADA\\n(Reserved Merchandise)\\n\\nThis is the main warehouse from Excel\\ncontaining reserved inventory',
                ),
              ],
            ),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: selectedCategory,
              items: categories.map((c) => DropdownMenuItem(
                value: c,
                child: Text(c),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockOverviewChart(Map<String, int> stockByWarehouse) {
    final filteredData = selectedWarehouse == 'All'
        ? stockByWarehouse
        : {selectedWarehouse: stockByWarehouse[selectedWarehouse] ?? 0};

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Stock by Warehouse',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                WarehouseUtils.createInfoTooltip(
                  context,
                  customMessage: 'Warehouse Legend:\\n\\n999 - MERCANCIA APARTADA\\n(Reserved Merchandise)\\n\\nThis shows inventory distribution\\nacross different warehouse locations',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: filteredData.entries.map((entry) {
                    final index = filteredData.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: _getWarehouseColor(entry.key),
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final warehouses = filteredData.keys.toList();
                          if (value.toInt() < warehouses.length) {
                            return Text(
                              warehouses[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistribution(Map<String, int> stockByCategory) {
    final total = stockByCategory.values.fold(0, (sum, count) => sum + count);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Distribution by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...stockByCategory.entries.map((entry) {
              final percentage = total > 0 ? (entry.value / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value} units (${percentage.toStringAsFixed(1)}%)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(_getCategoryColor(entry.key)),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalAlerts(List<MapEntry<String, dynamic>> lowStock,
                              List<MapEntry<String, dynamic>> outOfStock,
                              List<Product> products) {
    return Card(
      elevation: 4,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Critical Stock Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (outOfStock.isNotEmpty) ...[
              const Text(
                'Out of Stock:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              ...outOfStock.take(5).map((item) {
                final product = products.firstWhere(
                  (p) => p.sku == item.key.split('_').first,
                  orElse: () => Product(
                    name: item.key,
                    sku: item.key,
                    model: item.key,
                    price: 0,
                    displayName: item.key,
                    description: '',
                    category: 'Uncategorized',
                    stock: 0,
                    createdAt: DateTime.now(),
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Text('${product.sku} - ${product.name}'),
                    ],
                  ),
                );
              }).toList(),
            ],
            if (lowStock.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Low Stock (< 5 units):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              ...lowStock.take(5).map((item) {
                final product = products.firstWhere(
                  (p) => p.sku == item.key.split('_').first,
                  orElse: () => Product(
                    name: item.key,
                    sku: item.key,
                    model: item.key,
                    price: 0,
                    displayName: item.key,
                    description: '',
                    category: 'Uncategorized',
                    stock: 0,
                    createdAt: DateTime.now(),
                  ),
                );
                final stockInfo = Map<String, dynamic>.from(item.value as Map);
                final available = stockInfo['available'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${product.sku} - ${product.name} ($available units)'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStockTable(Map<String, dynamic> stockData, List<Product> products) {
    // Filter products based on search and category
    var filteredProducts = products.where((product) {
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!(product.sku ?? '').toLowerCase().contains(query) &&
            !product.name.toLowerCase().contains(query)) {
          return false;
        }
      }
      if (selectedCategory != 'All' && product.category != selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Stock Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('SKU')),
                  const DataColumn(label: Text('Product Name')),
                  const DataColumn(label: Text('Category')),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('999 (Reserved)'),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: WarehouseUtils.getDescription('999'),
                          child: Icon(
                            Icons.help_outline,
                            size: 14,
                            color: Theme.of(context).primaryColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    numeric: true,
                  ),
                  const DataColumn(label: Text('Total'), numeric: true),
                  const DataColumn(label: Text('Status')),
                ],
                rows: filteredProducts.take(50).map((product) {
                  final warehouseStock999 = ExcelInventoryService.getProductStock(product.sku ?? '')['999'] ?? 0;
                  final total = product.stock ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(Text(product.sku ?? '')),
                      DataCell(Text(product.name, overflow: TextOverflow.ellipsis)),
                      DataCell(Text(product.category ?? 'Inventory')),
                      DataCell(Text(warehouseStock999.toString())),
                      DataCell(
                        Text(
                          total.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStockStatusColor(total),
                          ),
                        ),
                      ),
                      DataCell(_buildStockStatusChip(total)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatusChip(int total) {
    String label;
    Color color;

    if (total == 0) {
      label = 'Out of Stock';
      color = Colors.red;
    } else if (total < 5) {
      label = 'Low Stock';
      color = Colors.orange;
    } else if (total < 20) {
      label = 'Normal';
      color = Colors.blue;
    } else {
      label = 'In Stock';
      color = Colors.green;
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  Map<String, int> _calculateStockByWarehouse(Map<String, dynamic> stockData) {
    final stockByWarehouse = <String, int>{
      '999': 0,
    };

    // Use Excel inventory service warehouse totals
    final warehouseTotals = ExcelInventoryService.warehouseTotals;
    for (final entry in warehouseTotals.entries) {
      stockByWarehouse[entry.key] = entry.value;
    }

    return stockByWarehouse;
  }

  Map<String, int> _calculateStockByCategory(Map<String, dynamic> stockData, List<Product> products) {
    final stockByCategory = <String, int>{};

    for (final product in products) {
      final category = product.category ?? 'Uncategorized';
      final stock = _getProductTotalStock(stockData, product.sku ?? '');
      stockByCategory[category] = (stockByCategory[category] ?? 0) + stock;
    }

    return stockByCategory;
  }

  Map<String, int> _getProductStock(Map<String, dynamic> stockData, String sku) {
    // Use Excel inventory service to get product stock
    return ExcelInventoryService.getProductStock(sku);
  }

  int _getProductTotalStock(Map<String, dynamic> stockData, String sku) {
    // Use Excel inventory service to get total stock
    return ExcelInventoryService.getTotalStock(sku);
  }

  List<MapEntry<String, dynamic>> _getLowStockItems(Map<String, dynamic> stockData, List<Product> products) {
    final lowStock = <MapEntry<String, dynamic>>[];

    stockData.entries.forEach((entry) {
      if (entry.value is Map) {
        final stockInfo = Map<String, dynamic>.from(entry.value as Map);
        final available = stockInfo['available'] ?? 0;
        if (available > 0 && available < 5) {
          lowStock.add(entry);
        }
      }
    });

    return lowStock;
  }

  List<MapEntry<String, dynamic>> _getOutOfStockItems(Map<String, dynamic> stockData, List<Product> products) {
    final outOfStock = <MapEntry<String, dynamic>>[];

    for (final product in products) {
      final totalStock = _getProductTotalStock(stockData, product.sku ?? '');
      if (totalStock == 0) {
        outOfStock.add(MapEntry(product.sku ?? '', {'available': 0}));
      }
    }

    return outOfStock;
  }

  Color _getWarehouseColor(String warehouse) {
    return WarehouseUtils.getWarehouseColor(warehouse);
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Refrigeration': return Colors.blue;
      case 'Freezers': return Colors.cyan;
      case 'Prep Tables': return Colors.green;
      case 'Display Cases': return Colors.orange;
      case 'Ice Machines': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getStockStatusColor(int total) {
    if (total == 0) return Colors.red;
    if (total < 5) return Colors.orange;
    if (total < 20) return Colors.blue;
    return Colors.green;
  }
}