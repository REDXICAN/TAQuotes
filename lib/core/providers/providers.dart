// lib/core/providers/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/app_logger.dart';
import '../utils/price_formatter.dart';

// Re-export commonly used providers from auth_provider.dart
export '../../features/auth/presentation/providers/auth_provider.dart'
    show
        totalProductsProvider,
        totalClientsProvider,
        totalQuotesProvider,
        cartItemCountProvider,
        currentUserProvider,
        currentUserProfileProvider,
        authStateProvider,
        databaseServiceProvider;

// Spare part model
class SparePart {
  final String sku;
  final String name;
  final int stock;
  final String? warehouse;
  final double price;

  SparePart({
    required this.sku,
    required this.name,
    required this.stock,
    this.warehouse,
    required this.price,
  });

  factory SparePart.fromMap(String key, Map<String, dynamic> map) {
    return SparePart(
      sku: map['sku'] ?? key,
      name: map['name'] ?? '',
      stock: map['stock'] ?? 0,
      warehouse: map['warehouse'],
      price: PriceFormatter.safeToDouble(map['price']),
    );
  }
}

// Spare Parts Provider - Auto-refreshing with Firebase stream
final sparePartsProvider = StreamProvider.autoDispose<List<SparePart>>((ref) async* {
  final database = FirebaseDatabase.instance;

  // Get spare parts from two sources: products table and warehouse_stock table
  final List<SparePart> spareParts = [];

  try {
    // Method 1: Get products marked as spare parts
    final productsSnapshot = await database.ref('products').get();
    if (productsSnapshot.exists && productsSnapshot.value != null) {
      final productsMap = Map<String, dynamic>.from(productsSnapshot.value as Map);

      for (final entry in productsMap.entries) {
        try {
          final productData = Map<String, dynamic>.from(entry.value as Map);

          // Check if product is marked as spare part
          final isSparePart = productData['isSparePart'] == true ||
                              productData['category'] == 'Spare Parts' ||
                              (productData['sku']?.toString().startsWith('SP') == true);

          if (isSparePart) {
            final name = productData['name'] ?? productData['displayName'] ?? 'Unknown Part';
            final sku = productData['sku'] ?? entry.key;

            // Check if product has warehouse stock available
            bool hasStock = false;
            int totalStock = 0;
            String? primaryWarehouse;

            // Check simple stock field first
            final simpleStock = productData['stock'] ?? productData['totalStock'] ?? productData['availableStock'] ?? 0;
            if (simpleStock is int && simpleStock > 0) {
              hasStock = true;
              totalStock = simpleStock;
            } else if (simpleStock is String) {
              final parsed = int.tryParse(simpleStock) ?? 0;
              if (parsed > 0) {
                hasStock = true;
                totalStock = parsed;
              }
            }

            // Check warehouse stock data if available
            final warehouseStock = productData['warehouseStock'] as Map<String, dynamic>?;
            if (warehouseStock != null && warehouseStock.isNotEmpty) {
              int warehouseTotalStock = 0;
              for (final warehouseEntry in warehouseStock.entries) {
                final stockData = warehouseEntry.value as Map<String, dynamic>?;
                if (stockData != null) {
                  final available = stockData['available'] as int? ?? 0;
                  warehouseTotalStock += available;

                  // Set primary warehouse to the one with most stock
                  if (primaryWarehouse == null || available > 0) {
                    primaryWarehouse = warehouseEntry.key;
                  }
                }
              }

              if (warehouseTotalStock > 0) {
                hasStock = true;
                totalStock = warehouseTotalStock; // Use warehouse stock if available
              }
            }

            // Add spare part if it has stock (or always add for testing, even with 0 stock)
            if (hasStock || totalStock == 0) {
              // Use warehouse from warehouseStock if available, otherwise use basic warehouse field or default
              String? warehouse = primaryWarehouse ?? productData['warehouse']?.toString() ?? '999';

              spareParts.add(SparePart(
                sku: sku,
                name: name,
                stock: totalStock,
                warehouse: warehouse,
                price: PriceFormatter.safeToDouble(productData['price']),
              ));
            }
          }
        } catch (e) {
          AppLogger.debug('Error processing spare part ${entry.key}', error: e);
        }
      }
    }

    // Method 2: Get spare parts from warehouse_stock table (products that start with 'SP')
    final stockSnapshot = await database.ref('warehouse_stock').get();
    if (stockSnapshot.exists && stockSnapshot.value != null) {
      final stockMap = Map<String, dynamic>.from(stockSnapshot.value as Map);
      final Map<String, List<Map<String, dynamic>>> sparePartStock = {};

      // Group stock by SKU
      for (final entry in stockMap.entries) {
        try {
          final stockData = Map<String, dynamic>.from(entry.value as Map);
          final sku = stockData['sku']?.toString() ?? '';

          // Check if this is a spare part SKU (starts with 'SP')
          if (sku.startsWith('SP')) {
            if (sparePartStock[sku] == null) {
              sparePartStock[sku] = [];
            }
            sparePartStock[sku]!.add(stockData);
          }
        } catch (e) {
          AppLogger.debug('Error processing stock entry ${entry.key}', error: e);
        }
      }

      // Create spare parts from stock data
      for (final entry in sparePartStock.entries) {
        final sku = entry.key;
        final stockEntries = entry.value;

        // Calculate total stock and find primary warehouse
        int totalStock = 0;
        String? primaryWarehouse;
        int maxStock = 0;

        for (final stockData in stockEntries) {
          final available = stockData['available'] as int? ?? stockData['stock'] as int? ?? 0;
          totalStock += available;

          if (available > maxStock) {
            maxStock = available;
            primaryWarehouse = stockData['warehouse']?.toString() ?? '999';
          }
        }

        // Check if we already have this spare part from products table
        final existingIndex = spareParts.indexWhere((part) => part.sku == sku);
        if (existingIndex == -1 && totalStock > 0) {
          // Create spare part from stock data
          spareParts.add(SparePart(
            sku: sku,
            name: 'Spare Part $sku', // Generic name from stock data
            stock: totalStock,
            warehouse: primaryWarehouse ?? '999',
            price: 0.0, // Default price for stock-only spare parts
          ));
        }
      }
    }

    // Sort by SKU for consistent ordering
    spareParts.sort((a, b) => a.sku.compareTo(b.sku));

    AppLogger.info('Spare parts provider found ${spareParts.length} spare parts', category: LogCategory.system);

  } catch (e) {
    AppLogger.error('Error loading spare parts data', error: e, category: LogCategory.system);
  }

  // Stream the results
  yield spareParts;

  // Continue streaming updates
  await for (final event in database.ref('products').onValue) {
    // Re-run the same logic for real-time updates
    final List<SparePart> updatedSpareParts = [];

    try {
      // Get updated products
      if (event.snapshot.exists && event.snapshot.value != null) {
        final productsMap = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in productsMap.entries) {
          try {
            final productData = Map<String, dynamic>.from(entry.value as Map);

            // Check if product is marked as spare part
            final isSparePart = productData['isSparePart'] == true ||
                                productData['category'] == 'Spare Parts' ||
                                (productData['sku']?.toString().startsWith('SP') == true);

            if (isSparePart) {
              final name = productData['name'] ?? productData['displayName'] ?? 'Unknown Part';
              final sku = productData['sku'] ?? entry.key;

              // Get stock data
              int totalStock = 0;
              String? primaryWarehouse = '999';

              final simpleStock = productData['stock'] ?? productData['totalStock'] ?? productData['availableStock'] ?? 0;
              if (simpleStock is int) {
                totalStock = simpleStock;
              } else if (simpleStock is String) {
                totalStock = int.tryParse(simpleStock) ?? 0;
              }

              final warehouseStock = productData['warehouseStock'] as Map<String, dynamic>?;
              if (warehouseStock != null && warehouseStock.isNotEmpty) {
                int warehouseTotalStock = 0;
                for (final warehouseEntry in warehouseStock.entries) {
                  final stockData = warehouseEntry.value as Map<String, dynamic>?;
                  if (stockData != null) {
                    final available = stockData['available'] as int? ?? 0;
                    warehouseTotalStock += available;
                    if (available > 0) {
                      primaryWarehouse = warehouseEntry.key;
                    }
                  }
                }
                if (warehouseTotalStock > 0) {
                  totalStock = warehouseTotalStock;
                }
              }

              updatedSpareParts.add(SparePart(
                sku: sku,
                name: name,
                stock: totalStock,
                warehouse: primaryWarehouse,
                price: PriceFormatter.safeToDouble(productData['price']),
              ));
            }
          } catch (e) {
            AppLogger.debug('Error processing spare part ${entry.key}', error: e);
          }
        }
      }

      // Sort and yield updated results
      updatedSpareParts.sort((a, b) => a.sku.compareTo(b.sku));
      yield updatedSpareParts;

    } catch (e) {
      AppLogger.error('Error processing spare parts updates', error: e, category: LogCategory.system);
    }
  }
});

// Search query provider for products screen
final searchQueryProvider = StateProvider<String>((ref) => '');

// Connection status provider
final isOnlineProvider = StateProvider<bool>((ref) => true);

// Currently selected client provider (used across app)
final globalSelectedClientProvider = StateProvider<Map<String, dynamic>?>((ref) => null);