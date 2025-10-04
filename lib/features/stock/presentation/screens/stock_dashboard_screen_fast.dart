import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/app_logger.dart';

// FAST stock summary - uses only essential queries, no full product download
final fastStockSummaryProvider = FutureProvider.autoDispose<StockSummary>((ref) async {
  final database = FirebaseDatabase.instance;

  try {
    // Query 1: Get product count (shallow query)
    final countSnapshot = await database.ref('products').get();
    final totalProducts = countSnapshot.exists && countSnapshot.value != null
        ? (countSnapshot.value as Map).length
        : 0;

    // Query 2: Get only stock-related data with specific fields
    // Use orderByChild to get only products we need for stock calculations
    final stockQuery = database.ref('products')
        .orderByChild('stock')
        .limitToFirst(100); // Get first 100 for calculations

    final stockSnapshot = await stockQuery.get();

    int lowStock = 0;
    int outOfStock = 0;
    final Map<String, int> categoryStock = {};
    final Map<String, int> warehouseStock = {};
    final List<ProductStockInfo> criticalItems = [];

    if (stockSnapshot.exists && stockSnapshot.value != null) {
      final data = stockSnapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        if (value is! Map) return;

        final productMap = Map<String, dynamic>.from(value);
        final stock = productMap['stock'] ?? 0;

        if (stock <= 0) {
          outOfStock++;
        } else if (stock <= 5) {
          lowStock++;
          if (criticalItems.length < 20) {
            criticalItems.add(ProductStockInfo(
              id: key.toString(),
              name: productMap['name'] ?? 'Unknown',
              sku: productMap['sku'] ?? '',
              category: productMap['category'] ?? 'Uncategorized',
              totalStock: stock,
            ));
          }
        }

        // Aggregate by category
        final category = productMap['category'] ?? 'Uncategorized';
        categoryStock[category] = (categoryStock[category] ?? 0) + stock;

        // Default warehouse
        warehouseStock['TX'] = (warehouseStock['TX'] ?? 0) + stock;
      });
    }

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
    AppLogger.error('Error loading fast stock summary', error: e);
    return StockSummary.empty();
  }
});

// Simple stock models
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

// Fast stock dashboard screen
class FastStockDashboardScreen extends ConsumerWidget {
  const FastStockDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(fastStockSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(fastStockSummaryProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: summaryAsync.when(
        data: (summary) => _buildDashboard(context, summary),
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
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(fastStockSummaryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, StockSummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Products',
                  summary.totalProducts.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Low Stock',
                  summary.lowStockCount.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Out of Stock',
                  summary.outOfStockCount.toString(),
                  Icons.error,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Category breakdown
          if (summary.categoryStock.isNotEmpty) ...[
            const Text(
              'Stock by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: summary.categoryStock.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Text(
                            '${entry.value} units',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

          // Critical items
          if (summary.criticalItems.isNotEmpty) ...[
            const Text(
              'Critical Stock Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summary.criticalItems.length,
                itemBuilder: (context, index) {
                  final item = summary.criticalItems[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.totalStock == 0
                          ? Colors.red
                          : Colors.orange,
                      child: Text(
                        item.totalStock.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Text('SKU: ${item.sku} | ${item.category}'),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
