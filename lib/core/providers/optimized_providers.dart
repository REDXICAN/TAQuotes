// lib/core/providers/optimized_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/models.dart';
import '../services/app_logger.dart';
import '../services/optimized_data_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Optimized provider for paginated products
///
/// Use this instead of loading all 835+ products at once
final paginatedProductsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<Product>, ProductsPageRequest>((ref, request) async {
  final service = OptimizedDataService();

  return await service.loadProducts(
    category: request.category,
    page: request.page,
    pageSize: request.pageSize,
    forceRefresh: request.forceRefresh,
  );
});

/// Optimized provider for streaming products with memory efficiency
///
/// This provider uses batching to prevent UI freezing
final optimizedProductsStreamProvider =
    StreamProvider.autoDispose.family<List<Product>, String?>((ref, category) {
  final service = OptimizedDataService();

  return service.streamProducts(category: category);
});

/// Optimized provider for paginated clients
final paginatedClientsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<Client>, ClientsPageRequest>((ref, request) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return PaginatedResult.empty(error: 'User not authenticated');
  }

  final service = OptimizedDataService();

  return await service.loadClients(
    userId: user.uid,
    page: request.page,
    pageSize: request.pageSize,
    forceRefresh: request.forceRefresh,
  );
});

/// Lightweight provider for checking Firebase connectivity
///
/// Use this to show connection status without loading heavy data
final firebaseConnectionProvider = StreamProvider.autoDispose<bool>((ref) {
  final database = FirebaseDatabase.instance;

  return database.ref('.info/connected').onValue.map((event) {
    final isConnected = event.snapshot.value as bool? ?? false;
    if (!isConnected) {
      AppLogger.warning(
        'Firebase disconnected',
        category: LogCategory.database,
      );
    }
    return isConnected;
  }).handleError((error) {
    AppLogger.error('Error checking Firebase connection', error: error);
    return false;
  });
});

/// Provider for products count without loading all data
///
/// Much faster than loading all products just to count them
final productsCountProvider =
    FutureProvider.autoDispose.family<int, String?>((ref, category) async {
  try {
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('products').get();

    if (!snapshot.exists || snapshot.value == null) {
      return 0;
    }

    if (category == null || category.isEmpty) {
      // Return total count
      final data = snapshot.value as Map;
      return data.length;
    }

    // Count filtered by category
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    int count = 0;

    for (final entry in data.values) {
      try {
        final productMap = Map<String, dynamic>.from(entry);
        final productCategory = (productMap['category'] ?? '').toString().trim().toLowerCase();
        final filterCategory = category.trim().toLowerCase();

        if (productCategory == filterCategory ||
            productCategory.contains(filterCategory) ||
            filterCategory.contains(productCategory)) {
          count++;
        }
      } catch (e) {
        // Skip invalid entries
      }
    }

    return count;
  } catch (e) {
    AppLogger.error('Error counting products', error: e);
    return 0;
  }
});

/// Provider for clients count without loading all data
final clientsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  try {
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('clients/${user.uid}').get();

    if (!snapshot.exists || snapshot.value == null) {
      return 0;
    }

    final data = snapshot.value as Map;
    return data.length;
  } catch (e) {
    AppLogger.error('Error counting clients', error: e);
    return 0;
  }
});

/// Optimized quotes provider with lazy loading
///
/// Only loads quote metadata first, then loads full details on demand
final optimizedQuotesProvider =
    StreamProvider.autoDispose.family<List<QuoteMetadata>, bool>((ref, showArchived) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }

  final database = FirebaseDatabase.instance;

  return database.ref('quotes/${user.uid}').onValue.map((event) {
    final List<QuoteMetadata> quotes = [];

    if (event.snapshot.exists && event.snapshot.value != null) {
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in data.entries) {
          try {
            final quoteData = Map<String, dynamic>.from(entry.value);

            // Skip archived quotes if not showing them
            final isArchived = quoteData['archived'] ?? false;
            if (!showArchived && isArchived) {
              continue;
            }

            // Create lightweight metadata instead of full quote
            quotes.add(QuoteMetadata(
              id: entry.key,
              quoteNumber: quoteData['quote_number'] ?? '',
              clientId: quoteData['client_id'] ?? '',
              total: (quoteData['total_amount'] ?? 0).toDouble(),
              status: quoteData['status'] ?? 'draft',
              archived: isArchived,
              createdAt: quoteData['created_at'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(quoteData['created_at'])
                  : DateTime.now(),
            ));
          } catch (e) {
            AppLogger.debug('Error parsing quote ${entry.key}', error: e);
          }
        }

        // Sort by creation date (newest first)
        quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        AppLogger.error('Error processing quotes', error: e);
      }
    }

    return quotes;
  }).handleError((error) {
    AppLogger.error('Error streaming quotes', error: error);
    return <QuoteMetadata>[];
  });
});

/// Request models for pagination
class ProductsPageRequest {
  final String? category;
  final int page;
  final int pageSize;
  final bool forceRefresh;

  const ProductsPageRequest({
    this.category,
    this.page = 0,
    this.pageSize = 50,
    this.forceRefresh = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductsPageRequest &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          page == other.page &&
          pageSize == other.pageSize &&
          forceRefresh == other.forceRefresh;

  @override
  int get hashCode =>
      category.hashCode ^
      page.hashCode ^
      pageSize.hashCode ^
      forceRefresh.hashCode;
}

class ClientsPageRequest {
  final int page;
  final int pageSize;
  final bool forceRefresh;

  const ClientsPageRequest({
    this.page = 0,
    this.pageSize = 50,
    this.forceRefresh = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientsPageRequest &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          pageSize == other.pageSize &&
          forceRefresh == other.forceRefresh;

  @override
  int get hashCode =>
      page.hashCode ^ pageSize.hashCode ^ forceRefresh.hashCode;
}

/// Lightweight quote metadata for list views
///
/// Full quote details loaded only when needed
class QuoteMetadata {
  final String id;
  final String quoteNumber;
  final String clientId;
  final double total;
  final String status;
  final bool archived;
  final DateTime createdAt;

  const QuoteMetadata({
    required this.id,
    required this.quoteNumber,
    required this.clientId,
    required this.total,
    required this.status,
    required this.archived,
    required this.createdAt,
  });
}
