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

  // Stream spare parts from Firebase products
  await for (final event in database.ref('products').onValue) {
    final List<SparePart> spareParts = [];

    if (event.snapshot.exists && event.snapshot.value != null) {
      try {
        final productsMap = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in productsMap.entries) {
          try {
            final productData = Map<String, dynamic>.from(entry.value as Map);

            // Extract product information
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

            // Include any product that has warehouse stock available
            // This represents spare parts/components that are available in warehouses
            if (hasStock && warehouseStock != null) {
              spareParts.add(SparePart(
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
      } catch (e) {
        AppLogger.error('Error processing spare parts data', error: e);
      }
    }

    // Sort by SKU for consistent ordering
    spareParts.sort((a, b) => a.sku.compareTo(b.sku));

    yield spareParts;
  }
});

// Search query provider for products screen
final searchQueryProvider = StateProvider<String>((ref) => '');

// Connection status provider
final isOnlineProvider = StateProvider<bool>((ref) => true);

// Currently selected client provider (used across app)
final globalSelectedClientProvider = StateProvider<Map<String, dynamic>?>((ref) => null);