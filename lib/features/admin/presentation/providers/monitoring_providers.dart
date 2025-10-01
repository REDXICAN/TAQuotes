// lib/features/admin/presentation/providers/monitoring_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/safe_type_converter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Monitoring Providers for Admin Dashboard
///
/// All providers include:
/// - RBAC protection (admin/superadmin only)
/// - Auto-refresh with Stream.periodic
/// - Error handling with fallback values
/// - Type-safe conversions using SafeTypeConverter

// ============================================================================
// CROSS-USER DATA STREAMS (Auto-refresh every 30s)
// ============================================================================

/// Provider for all quotes from all users (admin only)
/// Auto-refreshes every 30 seconds
/// Returns: List of quote maps with all quote data
final allQuotesForAdminProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

  return hasAdminAccess.when(
    data: (hasAccess) {
      if (!hasAccess) {
        AppLogger.warning('Unauthorized access attempt to allQuotesForAdminProvider');
        return Stream.value([]);
      }

      final dbService = ref.watch(databaseServiceProvider);

      // Use direct stream for real-time updates if available
      try {
        return dbService.getAllQuotesForAdmin();
      } catch (e) {
        AppLogger.error('Error streaming all quotes', error: e, category: LogCategory.general);
        return Stream.value([]);
      }
    },
    loading: () {
      AppLogger.debug('Loading admin access for allQuotesForAdminProvider');
      return Stream.value([]);
    },
    error: (error, stack) {
      AppLogger.error('RBAC check failed for allQuotesForAdminProvider',
        error: error,
        stackTrace: stack,
        category: LogCategory.security
      );
      return Stream.value([]);
    },
  );
});

/// Provider for all clients from all users (admin only)
/// Auto-refreshes every 30 seconds
/// Returns: List of client maps with all client data
final allClientsForAdminProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

  return hasAdminAccess.when(
    data: (hasAccess) {
      if (!hasAccess) {
        AppLogger.warning('Unauthorized access attempt to allClientsForAdminProvider');
        return Stream.value([]);
      }

      final dbService = ref.watch(databaseServiceProvider);

      try {
        return dbService.getAllClientsForAdmin();
      } catch (e) {
        AppLogger.error('Error streaming all clients', error: e, category: LogCategory.general);
        return Stream.value([]);
      }
    },
    loading: () {
      AppLogger.debug('Loading admin access for allClientsForAdminProvider');
      return Stream.value([]);
    },
    error: (error, stack) {
      AppLogger.error('RBAC check failed for allClientsForAdminProvider',
        error: error,
        stackTrace: stack,
        category: LogCategory.security
      );
      return Stream.value([]);
    },
  );
});

// ============================================================================
// PRODUCT ANALYTICS (Auto-refresh every 60s - less critical)
// ============================================================================

/// Provider for most quoted products
/// Auto-refreshes every 60 seconds
/// @param limit Number of top products to return (default 10)
/// Returns: List of maps with product data and quote count
final mostQuotedProductsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>(
  (ref, limit) {
    final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAdminAccess.when(
      data: (hasAccess) {
        if (!hasAccess) {
          AppLogger.warning('Unauthorized access attempt to mostQuotedProductsProvider');
          return Stream.value([]);
        }

        final dbService = ref.watch(databaseServiceProvider);

        // Convert Future to Stream with periodic refresh
        return Stream.periodic(const Duration(seconds: 60), (_) => null)
            .asyncMap((_) async {
              try {
                final products = await dbService.getMostQuotedProducts(limit: limit);
                AppLogger.debug('Fetched ${{products.length}} most quoted products');
                return products;
              } catch (e) {
                AppLogger.error('Error fetching most quoted products', error: e, category: LogCategory.general);
                return <Map<String, dynamic>>[];
              }
            })
            .handleError((error) {
              AppLogger.error('Stream error in mostQuotedProductsProvider', error: error);
              return <Map<String, dynamic>>[];
            });
      },
      loading: () {
        AppLogger.debug('Loading admin access for mostQuotedProductsProvider');
        return Stream.value([]);
      },
      error: (error, stack) {
        AppLogger.error('RBAC check failed for mostQuotedProductsProvider',
          error: error,
          stackTrace: stack,
          category: LogCategory.security
        );
        return Stream.value([]);
      },
    );
  },
);

/// Provider for best selling products (by revenue)
/// Auto-refreshes every 60 seconds
/// @param limit Number of top products to return (default 10)
/// Returns: List of maps with product data and total revenue
final bestSellingProductsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>(
  (ref, limit) {
    final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAdminAccess.when(
      data: (hasAccess) {
        if (!hasAccess) {
          AppLogger.warning('Unauthorized access attempt to bestSellingProductsProvider');
          return Stream.value([]);
        }

        final dbService = ref.watch(databaseServiceProvider);

        return Stream.periodic(const Duration(seconds: 60), (_) => null)
            .asyncMap((_) async {
              try {
                final products = await dbService.getBestSellingProducts(limit: limit);
                AppLogger.debug('Fetched ${{products.length}} best selling products');
                return products;
              } catch (e) {
                AppLogger.error('Error fetching best selling products', error: e, category: LogCategory.general);
                return <Map<String, dynamic>>[];
              }
            })
            .handleError((error) {
              AppLogger.error('Stream error in bestSellingProductsProvider', error: error);
              return <Map<String, dynamic>>[];
            });
      },
      loading: () {
        AppLogger.debug('Loading admin access for bestSellingProductsProvider');
        return Stream.value([]);
      },
      error: (error, stack) {
        AppLogger.error('RBAC check failed for bestSellingProductsProvider',
          error: error,
          stackTrace: stack,
          category: LogCategory.security
        );
        return Stream.value([]);
      },
    );
  },
);

// ============================================================================
// CLIENT ANALYTICS (Auto-refresh every 60s)
// ============================================================================

/// Provider for top clients by revenue
/// Auto-refreshes every 60 seconds
/// @param limit Number of top clients to return (default 10)
/// Returns: List of maps with client data and total revenue
final topClientsByRevenueProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>(
  (ref, limit) {
    final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAdminAccess.when(
      data: (hasAccess) {
        if (!hasAccess) {
          AppLogger.warning('Unauthorized access attempt to topClientsByRevenueProvider');
          return Stream.value([]);
        }

        final dbService = ref.watch(databaseServiceProvider);

        return Stream.periodic(const Duration(seconds: 60), (_) => null)
            .asyncMap((_) async {
              try {
                final clients = await dbService.getTopClientsByRevenue(limit: limit);
                AppLogger.debug('Fetched ${{clients.length}} top clients by revenue');
                return clients;
              } catch (e) {
                AppLogger.error('Error fetching top clients', error: e, category: LogCategory.general);
                return <Map<String, dynamic>>[];
              }
            })
            .handleError((error) {
              AppLogger.error('Stream error in topClientsByRevenueProvider', error: error);
              return <Map<String, dynamic>>[];
            });
      },
      loading: () {
        AppLogger.debug('Loading admin access for topClientsByRevenueProvider');
        return Stream.value([]);
      },
      error: (error, stack) {
        AppLogger.error('RBAC check failed for topClientsByRevenueProvider',
          error: error,
          stackTrace: stack,
          category: LogCategory.security
        );
        return Stream.value([]);
      },
    );
  },
);

// ============================================================================
// CATEGORY ANALYTICS (Auto-refresh every 60s)
// ============================================================================

/// Provider for revenue breakdown by product category
/// Auto-refreshes every 60 seconds
/// Returns: Map of category names to total revenue
final revenueByCategoryProvider = StreamProvider.autoDispose<Map<String, double>>((ref) {
  final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

  return hasAdminAccess.when(
    data: (hasAccess) {
      if (!hasAccess) {
        AppLogger.warning('Unauthorized access attempt to revenueByCategoryProvider');
        return Stream.value({});
      }

      final dbService = ref.watch(databaseServiceProvider);

      return Stream.periodic(const Duration(seconds: 60), (_) => null)
          .asyncMap((_) async {
            try {
              final categoryData = await dbService.getRevenueByCategory();
              AppLogger.debug('Fetched revenue data for ${{categoryData.length}} categories');
              return categoryData;
            } catch (e) {
              AppLogger.error('Error fetching category revenue', error: e, category: LogCategory.general);
              return <String, double>{};
            }
          })
          .handleError((error) {
            AppLogger.error('Stream error in revenueByCategoryProvider', error: error);
            return <String, double>{};
          });
    },
    loading: () {
      AppLogger.debug('Loading admin access for revenueByCategoryProvider');
      return Stream.value({});
    },
    error: (error, stack) {
      AppLogger.error('RBAC check failed for revenueByCategoryProvider',
        error: error,
        stackTrace: stack,
        category: LogCategory.security
      );
      return Stream.value({});
    },
  );
});

// ============================================================================
// COMPUTED/DERIVED PROVIDERS
// ============================================================================

/// Provider for total system revenue (all accepted/closed/sold quotes)
/// Computed from allQuotesForAdminProvider
/// Returns: Total revenue as double
final totalSystemRevenueProvider = Provider.autoDispose<double>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      try {
        final acceptedStatuses = ['accepted', 'closed', 'sold'];

        final totalRevenue = quotes
            .where((quote) {
              final status = SafeTypeConverter.toStr(quote['status']).toLowerCase();
              return acceptedStatuses.contains(status);
            })
            .fold<double>(0.0, (sum, quote) {
              final amount = SafeTypeConverter.toDouble(quote['total_amount']);
              return sum + amount;
            });

        AppLogger.debug('Calculated total system revenue: \$$totalRevenue');
        return totalRevenue;
      } catch (e) {
        AppLogger.error('Error calculating total revenue', error: e, category: LogCategory.general);
        return 0.0;
      }
    },
    loading: () {
      AppLogger.debug('Loading quotes for revenue calculation');
      return 0.0;
    },
    error: (error, stack) {
      AppLogger.error('Error loading quotes for revenue',
        error: error,
        stackTrace: stack,
        category: LogCategory.general
      );
      return 0.0;
    },
  );
});

/// Provider for total number of active users
/// Computed as users who created quotes in the last 30 days
/// Returns: Count of active users
final activeUsersCountProvider = Provider.autoDispose<int>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      try {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        final activeUserIds = <String>{};

        for (final quote in quotes) {
          final createdAt = SafeTypeConverter.toDateTimeOrNull(quote['created_at']);
          final userId = SafeTypeConverter.toStringOrNull(quote['user_id']);

          if (createdAt != null && userId != null && createdAt.isAfter(thirtyDaysAgo)) {
            activeUserIds.add(userId);
          }
        }

        AppLogger.debug('Found ${activeUserIds.length} active users in last 30 days');
        return activeUserIds.length;
      } catch (e) {
        AppLogger.error('Error counting active users', error: e, category: LogCategory.general);
        return 0;
      }
    },
    loading: () {
      AppLogger.debug('Loading quotes for active users count');
      return 0;
    },
    error: (error, stack) {
      AppLogger.error('Error loading quotes for active users',
        error: error,
        stackTrace: stack,
        category: LogCategory.general
      );
      return 0;
    },
  );
});

/// Provider for global conversion rate
/// Computed as (accepted + closed + sold quotes) / total quotes
/// Returns: Conversion rate as percentage (0.0 to 100.0)
final globalConversionRateProvider = Provider.autoDispose<double>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      try {
        if (quotes.isEmpty) {
          AppLogger.debug('No quotes available for conversion rate');
          return 0.0;
        }

        final acceptedStatuses = ['accepted', 'closed', 'sold'];

        final convertedCount = quotes.where((quote) {
          final status = SafeTypeConverter.toStr(quote['status']).toLowerCase();
          return acceptedStatuses.contains(status);
        }).length;

        final conversionRate = (convertedCount / quotes.length) * 100;

        AppLogger.debug('Calculated conversion rate: ${conversionRate.toStringAsFixed(2)}%');
        return conversionRate;
      } catch (e) {
        AppLogger.error('Error calculating conversion rate', error: e, category: LogCategory.general);
        return 0.0;
      }
    },
    loading: () {
      AppLogger.debug('Loading quotes for conversion rate');
      return 0.0;
    },
    error: (error, stack) {
      AppLogger.error('Error loading quotes for conversion rate',
        error: error,
        stackTrace: stack,
        category: LogCategory.general
      );
      return 0.0;
    },
  );
});

/// Provider for total number of quotes across all users
/// Computed from allQuotesForAdminProvider
/// Returns: Total quote count
final totalQuotesCountProvider = Provider.autoDispose<int>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      AppLogger.debug('Total quotes count: ${quotes.length}');
      return quotes.length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for total number of clients across all users
/// Computed from allClientsForAdminProvider
/// Returns: Total client count
final totalClientsCountProvider = Provider.autoDispose<int>((ref) {
  final clientsAsync = ref.watch(allClientsForAdminProvider);

  return clientsAsync.when(
    data: (clients) {
      AppLogger.debug('Total clients count: ${clients.length}');
      return clients.length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for quotes grouped by status
/// Returns: Map of status to list of quotes
final quotesByStatusProvider = Provider.autoDispose<Map<String, List<Map<String, dynamic>>>>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      try {
        final grouped = <String, List<Map<String, dynamic>>>{
          'pending': [],
          'accepted': [],
          'closed': [],
          'sold': [],
          'rejected': [],
          'draft': [],
        };

        for (final quote in quotes) {
          final status = SafeTypeConverter.toStr(quote['status']).toLowerCase();
          if (grouped.containsKey(status)) {
            grouped[status]!.add(quote);
          } else {
            // Unknown status - add to pending
            grouped['pending']!.add(quote);
          }
        }

        AppLogger.debug('Grouped quotes by status: ${grouped.map((k, v) => MapEntry(k, v.length))}');
        return grouped;
      } catch (e) {
        AppLogger.error('Error grouping quotes by status', error: e, category: LogCategory.general);
        return {
          'pending': [],
          'accepted': [],
          'closed': [],
          'sold': [],
          'rejected': [],
          'draft': [],
        };
      }
    },
    loading: () => {
      'pending': [],
      'accepted': [],
      'closed': [],
      'sold': [],
      'rejected': [],
      'draft': [],
    },
    error: (_, __) => {
      'pending': [],
      'accepted': [],
      'closed': [],
      'sold': [],
      'rejected': [],
      'draft': [],
    },
  );
});

/// Provider for average quote value
/// Returns: Average quote amount across all quotes
final averageQuoteValueProvider = Provider.autoDispose<double>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      try {
        if (quotes.isEmpty) return 0.0;

        final totalValue = quotes.fold<double>(0.0, (sum, quote) {
          return sum + SafeTypeConverter.toDouble(quote['total_amount']);
        });

        final average = totalValue / quotes.length;
        AppLogger.debug('Average quote value: \$${average.toStringAsFixed(2)}');
        return average;
      } catch (e) {
        AppLogger.error('Error calculating average quote value', error: e, category: LogCategory.general);
        return 0.0;
      }
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider for quotes created in the last 7 days
/// Returns: List of recent quotes
final recentQuotesProvider = Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      try {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

        final recentQuotes = quotes.where((quote) {
          final createdAt = SafeTypeConverter.toDateTimeOrNull(quote['created_at']);
          return createdAt != null && createdAt.isAfter(sevenDaysAgo);
        }).toList();

        // Sort by date descending (newest first)
        recentQuotes.sort((a, b) {
          final dateA = SafeTypeConverter.toDateTimeOrNull(a['created_at']) ?? DateTime(2000);
          final dateB = SafeTypeConverter.toDateTimeOrNull(b['created_at']) ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        AppLogger.debug('Found ${recentQuotes.length} quotes in last 7 days');
        return recentQuotes;
      } catch (e) {
        AppLogger.error('Error filtering recent quotes', error: e, category: LogCategory.general);
        return [];
      }
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for monthly revenue trend (last 12 months)
/// Returns: Map of month to revenue
final monthlyRevenueTrendProvider = Provider.autoDispose<Map<String, double>>((ref) {
  final quotesAsync = ref.watch(allQuotesForAdminProvider);

  return quotesAsync.when(
    data: (quotes) {
      try {
        final monthlyRevenue = <String, double>{};
        final acceptedStatuses = ['accepted', 'closed', 'sold'];
        final now = DateTime.now();

        // Initialize last 12 months
        for (int i = 11; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i, 1);
          final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
          monthlyRevenue[key] = 0.0;
        }

        // Aggregate revenue by month
        for (final quote in quotes) {
          final status = SafeTypeConverter.toStr(quote['status']).toLowerCase();
          if (!acceptedStatuses.contains(status)) continue;

          final createdAt = SafeTypeConverter.toDateTimeOrNull(quote['created_at']);
          if (createdAt == null) continue;

          final key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
          if (monthlyRevenue.containsKey(key)) {
            final amount = SafeTypeConverter.toDouble(quote['total_amount']);
            monthlyRevenue[key] = monthlyRevenue[key]! + amount;
          }
        }

        AppLogger.debug('Calculated monthly revenue for ${monthlyRevenue.length} months');
        return monthlyRevenue;
      } catch (e) {
        AppLogger.error('Error calculating monthly revenue trend', error: e, category: LogCategory.general);
        return {};
      }
    },
    loading: () => {},
    error: (_, __) => {},
  );
});
