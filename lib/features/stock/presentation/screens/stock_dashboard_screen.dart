// lib/features/stock/presentation/screens/stock_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/realtime_database_service.dart';
import '../../../../core/services/inventory_service.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../products/presentation/screens/products_screen.dart';

// Provider for stock statistics
final stockStatsProvider = FutureProvider<StockStatistics>((ref) async {
  final productsAsync = await ref.watch(productsProvider(null).future);
  return StockStatistics.fromProducts(productsAsync);
});

// Stock statistics model
class StockStatistics {
  final int totalProducts;
  final Map<String, WarehouseStats> warehouseStats;
  final int totalAvailable;
  final int totalReserved;
  final List<Product> lowStockProducts;
  final Map<String, int> categoryStock;
  
  StockStatistics({
    required this.totalProducts,
    required this.warehouseStats,
    required this.totalAvailable,
    required this.totalReserved,
    required this.lowStockProducts,
    required this.categoryStock,
  });
  
  factory StockStatistics.fromProducts(List<Product> products) {
    final warehouseStats = <String, WarehouseStats>{};
    int totalAvailable = 0;
    int totalReserved = 0;
    final lowStockProducts = <Product>[];
    final categoryStock = <String, int>{};
    
    // Initialize ALL warehouse locations from WarehouseInfo
    for (final code in WarehouseInfo.warehouses.keys) {
      warehouseStats[code] = WarehouseStats(
        code: code,
        totalAvailable: 0,
        totalReserved: 0,
        productCount: 0,
        lowStockCount: 0,
      );
    }
    
    // Process each product and distribute to warehouses based on warehouse field
    for (final product in products) {
      final stockQty = product.stock ?? 0;
      final warehouseCode = product.warehouse;
      
      if (stockQty > 0 && warehouseCode != null && warehouseStats.containsKey(warehouseCode)) {
        totalAvailable += stockQty;
        
        // Add stock to the specific warehouse
        warehouseStats[warehouseCode]!.totalAvailable += stockQty;
        warehouseStats[warehouseCode]!.productCount++;
        
        // Check if product is low stock (10 or less)
        if (stockQty <= 10) {
          lowStockProducts.add(product);
          warehouseStats[warehouseCode]!.lowStockCount++;
        }
        
        // Mark as reserved if in warehouse 999
        if (warehouseCode == '999') {
          warehouseStats[warehouseCode]!.totalReserved += stockQty;
          totalReserved += stockQty;
        }
      } else if (stockQty > 0) {
        // If no warehouse specified but has stock, put in main CA warehouse
        totalAvailable += stockQty;
        warehouseStats['CA']!.totalAvailable += stockQty;
        warehouseStats['CA']!.productCount++;
        
        if (stockQty <= 10) {
          lowStockProducts.add(product);
          warehouseStats['CA']!.lowStockCount++;
        }
      }
      
      // Update category stock
      categoryStock[product.category] = (categoryStock[product.category] ?? 0) + stockQty;
    }
    
    return StockStatistics(
      totalProducts: products.length,
      warehouseStats: warehouseStats,
      totalAvailable: totalAvailable,
      totalReserved: totalReserved,
      lowStockProducts: lowStockProducts..take(10).toList(), // Limit to 10 items
      categoryStock: categoryStock,
    );
  }
}

// Warehouse statistics
class WarehouseStats {
  final String code;
  int totalAvailable;
  int totalReserved;
  int productCount;
  int lowStockCount;
  
  WarehouseStats({
    required this.code,
    required this.totalAvailable,
    required this.totalReserved,
    required this.productCount,
    required this.lowStockCount,
  });
  
  int get actualAvailable => totalAvailable - totalReserved;
  double get utilizationRate => totalAvailable > 0 ? (totalReserved / totalAvailable * 100) : 0;
}

class StockDashboardScreen extends ConsumerStatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  ConsumerState<StockDashboardScreen> createState() => _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  String? selectedWarehouse;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockStatsAsync = ref.watch(stockStatsProvider);
    final isMobile = ResponsiveHelper.isMobile(context);
    final numberFormat = NumberFormat('#,###');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(stockStatsProvider);
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: stockStatsAsync.when(
        data: (stats) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Global Overview Cards
                _buildOverviewSection(stats, theme, numberFormat),
                const SizedBox(height: 24),
                
                // Warehouse Status Grid
                Text(
                  'Warehouse Status',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildWarehouseGrid(stats, theme, numberFormat, isMobile),
                const SizedBox(height: 24),
                
                // Low Stock Alerts
                if (stats.lowStockProducts.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Low Stock Alerts',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(
                        label: Text('${stats.lowStockProducts.length} items'),
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        labelStyle: const TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLowStockList(stats.lowStockProducts, theme),
                  const SizedBox(height: 24),
                ],
                
                // Category Distribution
                Text(
                  'Stock by Category',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCategoryDistribution(stats.categoryStock, theme, numberFormat),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading stock data: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(stockStatsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOverviewSection(StockStatistics stats, ThemeData theme, NumberFormat format) {
    return GridView.count(
      crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.5 : 1.8,
      children: [
        _buildStatCard(
          title: 'Total Products',
          value: format.format(stats.totalProducts),
          icon: Icons.inventory_2,
          color: Colors.blue,
          theme: theme,
        ),
        _buildStatCard(
          title: 'Available Stock',
          value: format.format(stats.totalAvailable),
          icon: Icons.check_circle,
          color: Colors.green,
          theme: theme,
        ),
        _buildStatCard(
          title: 'Reserved',
          value: format.format(stats.totalReserved),
          icon: Icons.lock,
          color: Colors.orange,
          theme: theme,
        ),
        _buildStatCard(
          title: 'Low Stock Items',
          value: stats.lowStockProducts.length.toString(),
          icon: Icons.warning,
          color: Colors.red,
          theme: theme,
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWarehouseGrid(StockStatistics stats, ThemeData theme, NumberFormat format, bool isMobile) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: isMobile ? 3 : 2,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.warehouseStats.length,
      itemBuilder: (context, index) {
        final entry = stats.warehouseStats.entries.elementAt(index);
        final code = entry.key;
        final warehouseStats = entry.value;
        
        return _buildWarehouseCard(code, warehouseStats, theme, format);
      },
    );
  }
  
  Widget _buildWarehouseCard(String code, WarehouseStats stats, ThemeData theme, NumberFormat format) {
    // Use the warehouse info from the model
    final info = WarehouseInfo.warehouses[code] ?? {
        'name': code,
        'location': 'Mexico',
        'flag': '📦',
    };
    final utilizationColor = stats.utilizationRate > 80 ? Colors.red :
                            stats.utilizationRate > 60 ? Colors.orange :
                            Colors.green;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedWarehouse == code ? theme.primaryColor : theme.dividerColor,
          width: selectedWarehouse == code ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedWarehouse = selectedWarehouse == code ? null : code;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    info['flag']!,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info['name']!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          info['location']!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.disabledColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                      Text(
                        format.format(stats.actualAvailable),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Reserved',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                      Text(
                        format.format(stats.totalReserved),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: stats.utilizationRate / 100,
                backgroundColor: theme.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(utilizationColor),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${stats.utilizationRate.toStringAsFixed(1)}% utilized',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (stats.lowStockCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${stats.lowStockCount} low',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLowStockList(List<Product> products, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: products.map((product) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.sku ?? product.model,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        product.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${product.stock} units',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Min: 50',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildCategoryDistribution(Map<String, int> categoryStock, ThemeData theme, NumberFormat format) {
    final sortedCategories = categoryStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: sortedCategories.map((entry) {
          final maxValue = sortedCategories.first.value;
          final percentage = (entry.value / maxValue);
          
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      format.format(entry.value),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: theme.dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}