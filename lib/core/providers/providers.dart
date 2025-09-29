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

  // Stream spare parts from Firebase products that have available warehouse stock
  await for (final event in database.ref('products').onValue) {
    final List<SparePart> spareParts = [];

    if (event.snapshot.exists && event.snapshot.value != null) {
      try {
        final productsMap = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in productsMap.entries) {
          try {
            final productData = Map<String, dynamic>.from(entry.value as Map);

            // Check if product has warehouse stock data (making it a spare part)
            final warehouseStock = productData['warehouse_stock'] as Map<String, dynamic>?;

            if (warehouseStock != null && warehouseStock.isNotEmpty) {
              // Calculate total stock across all warehouses
              int totalStock = 0;
              String? primaryWarehouse;

              for (final warehouseEntry in warehouseStock.entries) {
                final stockData = warehouseEntry.value as Map<String, dynamic>?;
                if (stockData != null) {
                  final available = stockData['available'] as int? ?? 0;
                  totalStock += available;

                  // Set primary warehouse to the one with most stock
                  if (primaryWarehouse == null || available > 0) {
                    primaryWarehouse = warehouseEntry.key;
                  }
                }
              }

              // Only include if has stock available
              if (totalStock > 0) {
                spareParts.add(SparePart(
                  sku: productData['sku'] ?? entry.key,
                  name: productData['name'] ?? 'Unknown Part',
                  stock: totalStock,
                  warehouse: primaryWarehouse,
                  price: PriceFormatter.safeToDouble(productData['price']),
                ));
              }
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
final selectedClientProvider = StateProvider<Map<String, dynamic>?>((ref) => null);