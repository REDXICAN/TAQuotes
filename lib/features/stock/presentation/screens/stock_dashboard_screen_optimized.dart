import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/app_logger.dart';

// Optimized provider - loads only stock summary data, not full products
final stockSummaryProvider = StreamProvider.autoDispose<StockSummary>((ref) {
  return FirebaseDatabase.instance.ref('products').onValue.map((event) {
    if (event.snapshot.value == null) {
      return StockSummary.empty();
    }

    try {
      final data = event.snapshot.value as Map<dynamic, dynamic>;

      // Calculate summaries in a single pass
      int totalProducts = 0;
      int lowStock = 0;
      int outOfStock = 0;
      final Map<String, int> categoryStock = {};
      final Map<String, int> warehouseStock = {};
      final List<ProductStockInfo> criticalItems = [];

      data.forEach((key, value) {
        if (value is! Map) return;

        final productMap = Map<String, dynamic>.from(value);
        totalProducts++;

        // Calculate total stock for this product
        int totalStock = 0;
        final warehouseData = productMap['warehouseStock'];

        if (warehouseData is Map) {
          warehouseData.forEach((warehouse, stockData) {
            if (stockData is Map) {
              final available = (stockData['available'] ?? 0) as int;
              final reserved = (stockData['reserved'] ?? 0) as int;
              final netStock = available - reserved;
              totalStock += netStock;

              // Aggregate by warehouse
              warehouseStock[warehouse.toString()] = (warehouseStock[warehouse.toString()] ?? 0) + netStock;
            }
          });
        } else {
          totalStock = productMap['stock'] ?? 0;
          warehouseStock['TX'] = (warehouseStock['TX'] ?? 0) + totalStock;
        }

        // Track stock levels
        if (totalStock <= 0) {
          outOfStock++;
        } else if (totalStock <= 5) {
          lowStock++;
          // Keep critical items for display
          if (criticalItems.length < 20) { // Only track top 20
            criticalItems.add(ProductStockInfo(
              id: key.toString(),
              name: productMap['name'] ?? 'Unknown',
              sku: productMap['sku'] ?? '',
              category: productMap['category'] ?? 'Uncategorized',
              totalStock: totalStock,
            ));
          }
        }

        // Aggregate by category
        final category = productMap['category'] ?? 'Uncategorized';
        categoryStock[category] = (categoryStock[category] ?? 0) + totalStock;
      });

      // Sort critical items by stock level
      criticalItems.sort((a, b) => a.totalStock.compareTo(b.totalStock));

      return StockSummary(
        totalProducts: totalProducts,
        lowStockCount: lowStock,
        outOfStockCount: outOfStock,
        categoryStock: categoryStock,
        warehouseStock: warehouseStock,
        criticalItems: criticalItems,
      );
    } catch (e) {
      AppLogger.error('Error calculating stock summary', error: e);
      return StockSummary.empty();
    }
  }).handleError((error) {
    AppLogger.error('Error loading stock summary', error: error);
    return StockSummary.empty();
  });
});

// Paginated product provider - only loads what's needed
final paginatedStockProductsProvider = StreamProvider.autoDispose.family<List<Product>, StockQueryParams>((ref, params) {
  var query = FirebaseDatabase.instance.ref('products').orderByChild('name');

  // Apply filters
  if (params.category != 'All') {
    query = FirebaseDatabase.instance.ref('products').orderByChild('category').equalTo(params.category);
  }

  return query.limitToFirst(params.limit).onValue.map((event) {
    if (event.snapshot.value == null) return <Product>[];

    try {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final products = <Product>[];

      data.forEach((key, value) {
        if (value is Map) {
          final productMap = Map<String, dynamic>.from(value);
          productMap['id'] = key;

          // Calculate total stock for filtering
          int totalStock = 0;
          final warehouseData = productMap['warehouseStock'];

          if (warehouseData is Map) {
            warehouseData.forEach((_, stockData) {
              if (stockData is Map) {
                final available = (stockData['available'] ?? 0) as int;
                final reserved = (stockData['reserved'] ?? 0) as int;
                totalStock += (available - reserved);
              }
            });
          } else {
            totalStock = (productMap['stock'] ?? 0) as int;
          }

          // Apply stock level filter
          bool includeProduct = false;
          switch (params.stockLevel) {
            case StockLevel.all:
              includeProduct = true;
              break;
            case StockLevel.low:
              includeProduct = totalStock > 0 && totalStock <= 5;
              break;
            case StockLevel.outOfStock:
              includeProduct = totalStock <= 0;
              break;
            case StockLevel.inStock:
              includeProduct = totalStock > 5;
              break;
          }

          if (includeProduct) {
            // Apply search filter
            if (params.searchQuery.isEmpty ||
                productMap['name']?.toString().toLowerCase().contains(params.searchQuery.toLowerCase()) == true ||
                productMap['sku']?.toString().toLowerCase().contains(params.searchQuery.toLowerCase()) == true) {
              products.add(Product.fromMap(productMap));
            }
          }
        }
      });

      return products;
    } catch (e) {
      AppLogger.error('Error loading paginated products', error: e);
      return <Product>[];
    }
  });
});

// Data classes
class StockSummary {
  final int totalProducts;
  final int lowStockCount;
  final int outOfStockCount;
  final Map<String, int> categoryStock;
  final Map<String, int> warehouseStock;
  final List<ProductStockInfo> criticalItems;

  StockSummary({
    required this.totalProducts,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.categoryStock,
    required this.warehouseStock,
    required this.criticalItems,
  });

  factory StockSummary.empty() => StockSummary(
    totalProducts: 0,
    lowStockCount: 0,
    outOfStockCount: 0,
    categoryStock: {},
    warehouseStock: {},
    criticalItems: [],
  );
}

class ProductStockInfo {
  final String id;
  final String name;
  final String sku;
  final String category;
  final int totalStock;

  ProductStockInfo({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.totalStock,
  });
}

enum StockLevel { all, low, outOfStock, inStock }

class StockQueryParams {
  final String category;
  final StockLevel stockLevel;
  final String searchQuery;
  final int limit;

  StockQueryParams({
    this.category = 'All',
    this.stockLevel = StockLevel.all,
    this.searchQuery = '',
    this.limit = 50,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockQueryParams &&
          category == other.category &&
          stockLevel == other.stockLevel &&
          searchQuery == other.searchQuery &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(category, stockLevel, searchQuery, limit);
}

class StockDashboardScreenOptimized extends ConsumerStatefulWidget {
  final bool showAppBar;

  const StockDashboardScreenOptimized({
    super.key,
    this.showAppBar = true,
  });

  @override
  ConsumerState<StockDashboardScreenOptimized> createState() => _StockDashboardScreenOptimizedState();
}

class _StockDashboardScreenOptimizedState extends ConsumerState<StockDashboardScreenOptimized> {
  String searchQuery = '';
  String selectedCategory = 'All';
  StockLevel selectedStockLevel = StockLevel.all;
  final searchController = TextEditingController();

  final categories = ['All', 'Refrigeration', 'Freezers', 'Cooking', 'Preparation', 'Display'];
  final warehouses = ['TX', 'KR', 'VN', 'CN', 'CUN', 'CDMX'];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(stockSummaryProvider);
    final queryParams = StockQueryParams(
      category: selectedCategory,
      stockLevel: selectedStockLevel,
      searchQuery: searchQuery,
      limit: 50,
    );
    final productsAsync = ref.watch(paginatedStockProductsProvider(queryParams));

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Stock Dashboard'),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
      body: summaryAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading stock data...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading stock data'),
              Text(error.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(stockSummaryProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(stockSummaryProvider);
            ref.invalidate(paginatedStockProductsProvider(queryParams));
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Products',
                        value: summary.totalProducts.toString(),
                        icon: Icons.inventory_2,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Low Stock',
                        value: summary.lowStockCount.toString(),
                        icon: Icons.warning,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Out of Stock',
                        value: summary.outOfStockCount.toString(),
                        icon: Icons.error,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Warehouse Summary
                if (summary.warehouseStock.isNotEmpty) ...[
                  const Text(
                    'Stock by Warehouse',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: warehouses.map((warehouse) {
                          final stock = summary.warehouseStock[warehouse] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(warehouse, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  stock.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: stock > 100 ? Colors.green : stock > 20 ? Colors.orange : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Critical Items
                if (summary.criticalItems.isNotEmpty) ...[
                  const Text(
                    'Critical Stock Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: summary.criticalItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = summary.criticalItems[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.totalStock == 0 ? Colors.red : Colors.orange,
                            child: Text(
                              item.totalStock.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text('${item.sku} • ${item.category}'),
                          trailing: Icon(
                            item.totalStock == 0 ? Icons.error : Icons.warning,
                            color: item.totalStock == 0 ? Colors.red : Colors.orange,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Filters and Search
                const Text(
                  'Product Inventory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or SKU...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() => searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                const SizedBox(height: 12),

                // Filters Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (value) => setState(() => selectedCategory = value ?? 'All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<StockLevel>(
                        value: selectedStockLevel,
                        decoration: const InputDecoration(
                          labelText: 'Stock Level',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: StockLevel.all, child: Text('All')),
                          DropdownMenuItem(value: StockLevel.inStock, child: Text('In Stock')),
                          DropdownMenuItem(value: StockLevel.low, child: Text('Low Stock')),
                          DropdownMenuItem(value: StockLevel.outOfStock, child: Text('Out of Stock')),
                        ],
                        onChanged: (value) => setState(() => selectedStockLevel = value ?? StockLevel.all),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Products List
                productsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Error loading products: $error'),
                    ),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No products match your filters'),
                        ),
                      );
                    }

                    return Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = products[index];

                          // Calculate total stock
                          int totalStock = 0;
                          if (product.warehouseStock != null) {
                            product.warehouseStock!.forEach((_, data) {
                              totalStock += (data.available - data.reserved);
                            });
                          } else {
                            totalStock = product.stock;
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: totalStock <= 0
                                  ? Colors.red
                                  : totalStock <= 5
                                      ? Colors.orange
                                      : Colors.green,
                              child: Text(
                                totalStock.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            title: Text(product.name),
                            subtitle: Text('${product.sku} • ${product.category}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // Navigate to product details if needed
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
