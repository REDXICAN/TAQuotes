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

  try {
    // Get spare parts from the dedicated /spareparts path
    final sparePartsSnapshot = await database.ref('spareparts').get();

    if (sparePartsSnapshot.exists && sparePartsSnapshot.value != null) {
      final sparePartsMap = Map<String, dynamic>.from(sparePartsSnapshot.value as Map);
      final List<SparePart> spareParts = [];

      for (final entry in sparePartsMap.entries) {
        try {
          final sparePartData = Map<String, dynamic>.from(entry.value as Map);

          spareParts.add(SparePart(
            sku: sparePartData['sku'] ?? entry.key,
            name: sparePartData['name'] ?? 'Unknown Part',
            stock: sparePartData['stock'] ?? 0,
            warehouse: sparePartData['warehouse'],
            price: PriceFormatter.safeToDouble(sparePartData['price']),
          ));
        } catch (e) {
          AppLogger.debug('Error processing spare part ${entry.key}', error: e);
        }
      }

      // Sort by SKU for consistent ordering
      spareParts.sort((a, b) => a.sku.compareTo(b.sku));

      AppLogger.info('Spare parts provider found ${spareParts.length} spare parts', category: LogCategory.system);

      // Yield initial results
      yield spareParts;
    } else {
      // No spare parts data found
      AppLogger.info('No spare parts data found in Firebase', category: LogCategory.system);
      yield <SparePart>[];
    }

  } catch (e) {
    AppLogger.error('Error loading spare parts data', error: e, category: LogCategory.system);
    yield <SparePart>[];
  }

  // Continue streaming updates from the /spareparts path
  await for (final event in database.ref('spareparts').onValue) {
    final List<SparePart> updatedSpareParts = [];

    try {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final sparePartsMap = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in sparePartsMap.entries) {
          try {
            final sparePartData = Map<String, dynamic>.from(entry.value as Map);

            updatedSpareParts.add(SparePart(
              sku: sparePartData['sku'] ?? entry.key,
              name: sparePartData['name'] ?? 'Unknown Part',
              stock: sparePartData['stock'] ?? 0,
              warehouse: sparePartData['warehouse'],
              price: PriceFormatter.safeToDouble(sparePartData['price']),
            ));
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
      yield <SparePart>[];
    }
  }
});

// Search query provider for products screen
final searchQueryProvider = StateProvider<String>((ref) => '');

// Connection status provider
final isOnlineProvider = StateProvider<bool>((ref) => true);

// Currently selected client provider (used across app)
final globalSelectedClientProvider = StateProvider<Map<String, dynamic>?>((ref) => null);