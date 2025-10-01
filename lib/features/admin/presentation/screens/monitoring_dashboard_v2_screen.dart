// lib/features/admin/presentation/screens/monitoring_dashboard_v2_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/widgets/kpi_card.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/theme/app_theme.dart';

// ============================================================================
// TIME PERIOD ENUM
// ============================================================================

enum TimePeriod {
  oneMonth('1M', 30),
  sixMonths('6M', 180),
  oneYear('1Y', 365),
  all('All', 9999);

  final String label;
  final int days;
  const TimePeriod(this.label, this.days);
}

// ============================================================================
// FAST LOADING PROVIDERS (Optimized for Speed)
// ============================================================================

/// Fast KPI provider - Only fetches essential metrics
final fastKPIsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, TimePeriod>((ref, period) async {
  try {
    final db = FirebaseDatabase.instance;
    final now = DateTime.now();
    final periodStart = period == TimePeriod.all
        ? DateTime(2020, 1, 1)
        : now.subtract(Duration(days: period.days));
    final lastPeriodStart = periodStart.subtract(Duration(days: period.days));

    // Fetch only quotes (most critical data)
    final quotesSnapshot = await db.ref('quotes').get();

    double currentRevenue = 0;
    double lastPeriodRevenue = 0;
    int currentQuotes = 0;
    int lastPeriodQuotes = 0;
    int currentAccepted = 0;
    int lastPeriodAccepted = 0;

    if (quotesSnapshot.value != null) {
      final quotesData = quotesSnapshot.value as Map<dynamic, dynamic>;
      quotesData.forEach((userId, userQuotesData) {
        if (userQuotesData is Map) {
          userQuotesData.forEach((quoteId, quoteData) {
            if (quoteData is Map) {
              try {
                final createdAt = _parseTimestamp(quoteData['created_at']);
                final status = (quoteData['status'] ?? '').toString().toLowerCase();
                final total = (quoteData['total_amount'] ?? 0).toDouble();

                // Current period
                if (createdAt != null && createdAt.isAfter(periodStart)) {
                  currentQuotes++;
                  if (status == 'accepted' || status == 'closed' || status == 'sold') {
                    currentRevenue += total;
                    currentAccepted++;
                  }
                }

                // Last period (for comparison)
                if (createdAt != null &&
                    createdAt.isAfter(lastPeriodStart) &&
                    createdAt.isBefore(periodStart)) {
                  lastPeriodQuotes++;
                  if (status == 'accepted' || status == 'closed' || status == 'sold') {
                    lastPeriodRevenue += total;
                    lastPeriodAccepted++;
                  }
                }
              } catch (e) {
                // Skip invalid quotes
              }
            }
          });
        }
      });
    }

    final currentConversion = currentQuotes > 0 ? (currentAccepted / currentQuotes) * 100 : 0.0;
    final lastConversion = lastPeriodQuotes > 0 ? (lastPeriodAccepted / lastPeriodQuotes) * 100 : 0.0;

    return {
      'currentRevenue': currentRevenue,
      'lastRevenue': lastPeriodRevenue,
      'revenueTrend': lastPeriodRevenue > 0
          ? ((currentRevenue - lastPeriodRevenue) / lastPeriodRevenue) * 100
          : 0.0,
      'currentQuotes': currentQuotes,
      'lastQuotes': lastPeriodQuotes,
      'quotesTrend': lastPeriodQuotes > 0
          ? ((currentQuotes - lastPeriodQuotes) / lastPeriodQuotes) * 100
          : 0.0,
      'currentConversion': currentConversion,
      'lastConversion': lastConversion,
      'conversionTrend': lastConversion > 0
          ? ((currentConversion - lastConversion) / lastConversion) * 100
          : 0.0,
    };
  } catch (e) {
    AppLogger.error('Error fetching fast KPIs', error: e);
    return {};
  }
});

/// Active users this week
final activeUsersThisWeekProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final db = FirebaseDatabase.instance;
    final usersSnapshot = await db.ref('users').get();

    if (usersSnapshot.value == null) return 0;

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    int activeCount = 0;

    final data = usersSnapshot.value as Map<dynamic, dynamic>;
    data.forEach((key, value) {
      if (value is Map) {
        final lastLogin = _parseTimestamp(value['lastLoginAt']);
        if (lastLogin != null && lastLogin.isAfter(weekAgo)) {
          activeCount++;
        }
      }
    });

    return activeCount;
  } catch (e) {
    AppLogger.error('Error fetching active users', error: e);
    return 0;
  }
});

/// Top 10 products by revenue
final top10ProductsByRevenueProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final db = FirebaseDatabase.instance;
    final quotesSnapshot = await db.ref('quotes').get();
    final productsSnapshot = await db.ref('products').get();

    final productRevenue = <String, double>{};
    final productNames = <String, String>{};

    // Get product names
    if (productsSnapshot.value != null) {
      final data = productsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final sku = value['sku'] ?? key;
          productNames[sku.toString()] = value['name'] ?? sku.toString();
        }
      });
    }

    // Calculate revenue per product
    if (quotesSnapshot.value != null) {
      final quotesData = quotesSnapshot.value as Map<dynamic, dynamic>;
      quotesData.forEach((userId, userQuotesData) {
        if (userQuotesData is Map) {
          userQuotesData.forEach((quoteId, quoteData) {
            if (quoteData is Map) {
              final status = (quoteData['status'] ?? '').toString().toLowerCase();
              if (status == 'accepted' || status == 'closed' || status == 'sold') {
                final items = quoteData['quote_items'] ?? quoteData['items'];
                if (items is List) {
                  for (var item in items) {
                    if (item is Map) {
                      final sku = item['sku'] ?? item['product']?['sku'] ?? '';
                      final total = (item['total'] ?? 0).toDouble();
                      if (sku.toString().isNotEmpty) {
                        productRevenue[sku.toString()] =
                            (productRevenue[sku.toString()] ?? 0) + total;
                      }
                    }
                  }
                }
              }
            }
          });
        }
      });
    }

    // Sort and return top 10
    final sorted = productRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).map((e) => {
      'sku': e.key,
      'name': productNames[e.key] ?? e.key,
      'revenue': e.value,
    }).toList();
  } catch (e) {
    AppLogger.error('Error fetching top products', error: e);
    return [];
  }
});

/// Top 10 sales reps by revenue
final top10SalesRepsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final db = FirebaseDatabase.instance;
    final quotesSnapshot = await db.ref('quotes').get();
    final usersSnapshot = await db.ref('users').get();

    final userRevenue = <String, double>{};
    final userNames = <String, String>{};
    final userQuoteCount = <String, int>{};

    // Get user names
    if (usersSnapshot.value != null) {
      final data = usersSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          userNames[key.toString()] = value['displayName'] ?? value['email'] ?? key.toString();
        }
      });
    }

    // Calculate revenue per user
    if (quotesSnapshot.value != null) {
      final quotesData = quotesSnapshot.value as Map<dynamic, dynamic>;
      quotesData.forEach((userId, userQuotesData) {
        if (userQuotesData is Map) {
          userQuotesData.forEach((quoteId, quoteData) {
            if (quoteData is Map) {
              final status = (quoteData['status'] ?? '').toString().toLowerCase();
              if (status == 'accepted' || status == 'closed' || status == 'sold') {
                final total = (quoteData['total_amount'] ?? 0).toDouble();
                userRevenue[userId.toString()] = (userRevenue[userId.toString()] ?? 0) + total;
                userQuoteCount[userId.toString()] = (userQuoteCount[userId.toString()] ?? 0) + 1;
              }
            }
          });
        }
      });
    }

    // Sort and return top 10
    final sorted = userRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).map((e) => {
      'userId': e.key,
      'name': userNames[e.key] ?? e.key,
      'revenue': e.value,
      'quotes': userQuoteCount[e.key] ?? 0,
    }).toList();
  } catch (e) {
    AppLogger.error('Error fetching top sales reps', error: e);
    return [];
  }
});

/// Quote aging summary
final quoteAgingSummaryProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  try {
    final db = FirebaseDatabase.instance;
    final quotesSnapshot = await db.ref('quotes').get();

    int fresh = 0; // < 7 days
    int aging = 0; // 7-30 days
    int stale = 0; // > 30 days

    final now = DateTime.now();

    if (quotesSnapshot.value != null) {
      final quotesData = quotesSnapshot.value as Map<dynamic, dynamic>;
      quotesData.forEach((userId, userQuotesData) {
        if (userQuotesData is Map) {
          userQuotesData.forEach((quoteId, quoteData) {
            if (quoteData is Map) {
              final status = (quoteData['status'] ?? '').toString().toLowerCase();
              // Only count pending/draft quotes
              if (status == 'pending' || status == 'draft' || status == 'sent') {
                final createdAt = _parseTimestamp(quoteData['created_at']);
                if (createdAt != null) {
                  final age = now.difference(createdAt).inDays;
                  if (age < 7) {
                    fresh++;
                  } else if (age < 30) {
                    aging++;
                  } else {
                    stale++;
                  }
                }
              }
            }
          });
        }
      });
    }

    return {
      'fresh': fresh,
      'aging': aging,
      'stale': stale,
    };
  } catch (e) {
    AppLogger.error('Error fetching quote aging', error: e);
    return {'fresh': 0, 'aging': 0, 'stale': 0};
  }
});

/// Revenue by category
final revenueByCategoryProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  try {
    final db = FirebaseDatabase.instance;
    final quotesSnapshot = await db.ref('quotes').get();
    final productsSnapshot = await db.ref('products').get();

    final productCategories = <String, String>{};
    final categoryRevenue = <String, double>{};

    // Get product categories
    if (productsSnapshot.value != null) {
      final data = productsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final sku = value['sku'] ?? key;
          final category = value['category'] ?? 'Uncategorized';
          productCategories[sku.toString()] = category.toString();
        }
      });
    }

    // Calculate revenue per category
    if (quotesSnapshot.value != null) {
      final quotesData = quotesSnapshot.value as Map<dynamic, dynamic>;
      quotesData.forEach((userId, userQuotesData) {
        if (userQuotesData is Map) {
          userQuotesData.forEach((quoteId, quoteData) {
            if (quoteData is Map) {
              final status = (quoteData['status'] ?? '').toString().toLowerCase();
              if (status == 'accepted' || status == 'closed' || status == 'sold') {
                final items = quoteData['quote_items'] ?? quoteData['items'];
                if (items is List) {
                  for (var item in items) {
                    if (item is Map) {
                      final sku = item['sku'] ?? item['product']?['sku'] ?? '';
                      final total = (item['total'] ?? 0).toDouble();
                      final category = productCategories[sku.toString()] ?? 'Uncategorized';
                      categoryRevenue[category] = (categoryRevenue[category] ?? 0) + total;
                    }
                  }
                }
              }
            }
          });
        }
      });
    }

    return categoryRevenue;
  } catch (e) {
    AppLogger.error('Error fetching revenue by category', error: e);
    return {};
  }
});

/// Low-performing products (never quoted or low revenue)
final lowPerformingProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final db = FirebaseDatabase.instance;
    final quotesSnapshot = await db.ref('quotes').get();
    final productsSnapshot = await db.ref('products').get();

    final quotedSkus = <String>{};
    final productRevenue = <String, double>{};

    // Get quoted products
    if (quotesSnapshot.value != null) {
      final quotesData = quotesSnapshot.value as Map<dynamic, dynamic>;
      quotesData.forEach((userId, userQuotesData) {
        if (userQuotesData is Map) {
          userQuotesData.forEach((quoteId, quoteData) {
            if (quoteData is Map) {
              final items = quoteData['quote_items'] ?? quoteData['items'];
              if (items is List) {
                for (var item in items) {
                  if (item is Map) {
                    final sku = item['sku'] ?? item['product']?['sku'] ?? '';
                    if (sku.toString().isNotEmpty) {
                      quotedSkus.add(sku.toString());

                      final status = (quoteData['status'] ?? '').toString().toLowerCase();
                      if (status == 'accepted' || status == 'closed' || status == 'sold') {
                        final total = (item['total'] ?? 0).toDouble();
                        productRevenue[sku.toString()] =
                            (productRevenue[sku.toString()] ?? 0) + total;
                      }
                    }
                  }
                }
              }
            }
          });
        }
      });
    }

    final lowPerforming = <Map<String, dynamic>>[];

    // Find never-quoted products
    if (productsSnapshot.value != null) {
      final data = productsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final sku = value['sku'] ?? key;
          final name = value['name'] ?? sku;

          if (!quotedSkus.contains(sku.toString())) {
            lowPerforming.add({
              'sku': sku,
              'name': name,
              'reason': 'Never quoted',
              'revenue': 0.0,
            });
          } else if ((productRevenue[sku.toString()] ?? 0) < 1000) {
            lowPerforming.add({
              'sku': sku,
              'name': name,
              'reason': 'Low revenue',
              'revenue': productRevenue[sku.toString()] ?? 0,
            });
          }
        }
      });
    }

    return lowPerforming.take(20).toList();
  } catch (e) {
    AppLogger.error('Error fetching low-performing products', error: e);
    return [];
  }
});

/// Stock alerts (low and critical)
final stockAlertsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final db = FirebaseDatabase.instance;
    final productsSnapshot = await db.ref('products').get();

    final alerts = <Map<String, dynamic>>[];

    if (productsSnapshot.value != null) {
      final data = productsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final stock = value['stock'] ?? value['totalStock'] ?? value['availableStock'] ?? 0;
          final sku = value['sku'] ?? key;
          final name = value['name'] ?? sku;
          final warehouse = value['warehouse'] ?? 'Unknown';

          if (stock == 0) {
            alerts.add({
              'sku': sku,
              'name': name,
              'stock': stock,
              'warehouse': warehouse,
              'severity': 'critical',
              'message': 'Out of stock',
            });
          } else if (stock < 5) {
            alerts.add({
              'sku': sku,
              'name': name,
              'stock': stock,
              'warehouse': warehouse,
              'severity': 'warning',
              'message': 'Low stock ($stock units)',
            });
          } else if (stock < 10) {
            alerts.add({
              'sku': sku,
              'name': name,
              'stock': stock,
              'warehouse': warehouse,
              'severity': 'info',
              'message': 'Monitor stock ($stock units)',
            });
          }
        }
      });
    }

    // Sort: critical first, then warning, then info
    alerts.sort((a, b) {
      final severityOrder = {'critical': 0, 'warning': 1, 'info': 2};
      return (severityOrder[a['severity']] ?? 3).compareTo(severityOrder[b['severity']] ?? 3);
    });

    return alerts;
  } catch (e) {
    AppLogger.error('Error fetching stock alerts', error: e);
    return [];
  }
});

// Helper function
DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class MonitoringDashboardV2Screen extends ConsumerStatefulWidget {
  const MonitoringDashboardV2Screen({super.key});

  @override
  ConsumerState<MonitoringDashboardV2Screen> createState() => _MonitoringDashboardV2ScreenState();
}

class _MonitoringDashboardV2ScreenState extends ConsumerState<MonitoringDashboardV2Screen> {
  TimePeriod _selectedPeriod = TimePeriod.oneMonth;
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    // Check RBAC permission
    final hasAccessAsync = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAccessAsync.when(
      data: (hasAccess) {
        if (!hasAccess) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: const Center(
              child: Text('You do not have permission to access this page'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Monitoring Dashboard'),
            actions: [
              // Time period selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<TimePeriod>(
                  segments: TimePeriod.values.map((period) {
                    return ButtonSegment<TimePeriod>(
                      value: period,
                      label: Text(period.label),
                    );
                  }).toList(),
                  selected: {_selectedPeriod},
                  onSelectionChanged: (Set<TimePeriod> selected) {
                    setState(() {
                      _selectedPeriod = selected.first;
                    });
                  },
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(fastKPIsProvider);
              ref.invalidate(activeUsersThisWeekProvider);
              ref.invalidate(top10ProductsByRevenueProvider);
              ref.invalidate(top10SalesRepsProvider);
              ref.invalidate(quoteAgingSummaryProvider);
              ref.invalidate(revenueByCategoryProvider);
              ref.invalidate(lowPerformingProductsProvider);
              ref.invalidate(stockAlertsProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============================================================
                  // TOP SECTION: AT-A-GLANCE KPIs
                  // ============================================================
                  _buildTopSection(),

                  const SizedBox(height: 32),

                  // ============================================================
                  // MID SECTION: CONTEXT & PERFORMANCE
                  // ============================================================
                  _buildMidSection(),

                  const SizedBox(height: 32),

                  // ============================================================
                  // LOWER SECTION: DETAILED INSIGHTS
                  // ============================================================
                  _buildLowerSection(),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  // ==========================================================================
  // TOP SECTION
  // ==========================================================================

  Widget _buildTopSection() {
    final kpisAsync = ref.watch(fastKPIsProvider(_selectedPeriod));
    final activeUsersAsync = ref.watch(activeUsersThisWeekProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insights, size: 28),
            const SizedBox(width: 8),
            Text(
              'At-a-Glance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        kpisAsync.when(
          data: (kpis) {
            final currentRevenue = kpis['currentRevenue'] ?? 0.0;
            final lastRevenue = kpis['lastRevenue'] ?? 0.0;
            final revenueTrend = kpis['revenueTrend'] ?? 0.0;

            final currentQuotes = kpis['currentQuotes'] ?? 0;
            final quotesTrend = kpis['quotesTrend'] ?? 0.0;

            final currentConversion = kpis['currentConversion'] ?? 0.0;
            final conversionTrend = kpis['conversionTrend'] ?? 0.0;

            return KPICardGrid(
              children: [
                KPICard(
                  title: 'Total Revenue',
                  value: _currencyFormat.format(currentRevenue),
                  icon: Icons.attach_money,
                  color: AppTheme.successColor,
                  subtitle: 'vs ${_currencyFormat.format(lastRevenue)} last period (${revenueTrend >= 0 ? '+' : ''}${revenueTrend.toStringAsFixed(1)}%)',
                ),
                KPICard(
                  title: 'Quote Volume',
                  value: currentQuotes.toString(),
                  icon: Icons.receipt_long,
                  color: AppTheme.accentPrimary,
                  subtitle: 'quotes ${_selectedPeriod.label} (${quotesTrend >= 0 ? '+' : ''}${quotesTrend.toStringAsFixed(1)}%)',
                ),
                KPICard(
                  title: 'Conversion Rate',
                  value: '${currentConversion.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: AppTheme.warningColor,
                  subtitle: '${_selectedPeriod.label} period (${conversionTrend >= 0 ? '+' : ''}${conversionTrend.toStringAsFixed(1)}%)',
                ),
                activeUsersAsync.when(
                  data: (activeUsers) => KPICard(
                    title: 'Active Users',
                    value: activeUsers.toString(),
                    icon: Icons.people_alt,
                    color: AppTheme.accentSecondary,
                    subtitle: 'this week',
                  ),
                  loading: () => KPICard(
                    title: 'Active Users',
                    value: '...',
                    icon: Icons.people_alt,
                    color: AppTheme.accentSecondary,
                    subtitle: 'loading...',
                  ),
                  error: (_, __) => KPICard(
                    title: 'Active Users',
                    value: 'Error',
                    icon: Icons.people_alt,
                    color: AppTheme.accentSecondary,
                    subtitle: 'failed to load',
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Center(
            child: Text('Error loading KPIs: $error'),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MID SECTION
  // ==========================================================================

  Widget _buildMidSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics, size: 28),
            const SizedBox(width: 8),
            Text(
              'Context & Performance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ResponsiveHelper.isDesktop(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTop10Products()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTop10SalesReps()),
                ],
              )
            : Column(
                children: [
                  _buildTop10Products(),
                  const SizedBox(height: 16),
                  _buildTop10SalesReps(),
                ],
              ),

        const SizedBox(height: 16),

        ResponsiveHelper.isDesktop(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildQuoteAgingSummary()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRevenueByCategoryChart()),
                ],
              )
            : Column(
                children: [
                  _buildQuoteAgingSummary(),
                  const SizedBox(height: 16),
                  _buildRevenueByCategoryChart(),
                ],
              ),
      ],
    );
  }

  Widget _buildTop10Products() {
    final productsAsync = ref.watch(top10ProductsByRevenueProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: AppTheme.accentPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Top 10 Products by Revenue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No product data available'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.accentPrimary.withValues(alpha: 0.2),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        product['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('SKU: ${product['sku']}'),
                      trailing: Text(
                        _currencyFormat.format(product['revenue']),
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop10SalesReps() {
    final repsAsync = ref.watch(top10SalesRepsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard, color: AppTheme.successColor),
                const SizedBox(width: 8),
                const Text(
                  'Top 10 Sales Reps/Distributors',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            repsAsync.when(
              data: (reps) {
                if (reps.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No sales data available'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reps.length,
                  itemBuilder: (context, index) {
                    final rep = reps[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        rep['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('${rep['quotes']} quotes'),
                      trailing: Text(
                        _currencyFormat.format(rep['revenue']),
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteAgingSummary() {
    final agingAsync = ref.watch(quoteAgingSummaryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                const Text(
                  'Quote Aging Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            agingAsync.when(
              data: (aging) {
                final fresh = aging['fresh'] ?? 0;
                final agingQuotes = aging['aging'] ?? 0;
                final stale = aging['stale'] ?? 0;
                final total = fresh + agingQuotes + stale;

                if (total == 0) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No pending quotes'),
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildAgingRow('Fresh (< 7 days)', fresh, AppTheme.successColor, total),
                    const SizedBox(height: 8),
                    _buildAgingRow('Aging (7-30 days)', agingQuotes, AppTheme.warningColor, total),
                    const SizedBox(height: 8),
                    _buildAgingRow('Stale (> 30 days)', stale, AppTheme.errorColor, total),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingRow(String label, int count, Color color, int total) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '$count (${percentage.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildRevenueByCategoryChart() {
    final categoryRevenueAsync = ref.watch(revenueByCategoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: AppTheme.accentSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Revenue by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            categoryRevenueAsync.when(
              data: (categoryRevenue) {
                if (categoryRevenue.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No category data available'),
                    ),
                  );
                }

                final total = categoryRevenue.values.fold<double>(0, (sum, val) => sum + val);
                final colors = [
                  AppTheme.accentPrimary,
                  AppTheme.successColor,
                  AppTheme.warningColor,
                  AppTheme.accentSecondary,
                  AppTheme.errorColor,
                ];

                return SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: categoryRevenue.entries.toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value.key;
                        final revenue = entry.value.value;
                        final percentage = (revenue / total) * 100;

                        return PieChartSectionData(
                          value: revenue,
                          title: '${percentage.toStringAsFixed(0)}%',
                          color: colors[index % colors.length],
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // LOWER SECTION
  // ==========================================================================

  Widget _buildLowerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber, size: 28),
            const SizedBox(width: 8),
            Text(
              'Detailed Insights & Alerts',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ResponsiveHelper.isDesktop(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildLowPerformingProducts()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStockAlerts()),
                ],
              )
            : Column(
                children: [
                  _buildLowPerformingProducts(),
                  const SizedBox(height: 16),
                  _buildStockAlerts(),
                ],
              ),
      ],
    );
  }

  Widget _buildLowPerformingProducts() {
    final lowPerfAsync = ref.watch(lowPerformingProductsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_down, color: AppTheme.errorColor),
                const SizedBox(width: 8),
                const Text(
                  'Low-Performing Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            lowPerfAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('All products performing well!'),
                    ),
                  );
                }

                return SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.error_outline,
                          color: AppTheme.warningColor,
                        ),
                        title: Text(product['name'] ?? ''),
                        subtitle: Text('SKU: ${product['sku']} • ${product['reason']}'),
                        trailing: product['revenue'] > 0
                            ? Text(
                                _currencyFormat.format(product['revenue']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockAlerts() {
    final alertsAsync = ref.watch(stockAlertsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                const Text(
                  'Stock Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No stock alerts'),
                    ),
                  );
                }

                // Separate critical and low stock alerts
                final criticalAlerts = alerts.where((a) => a['severity'] == 'critical').toList();
                final lowStockAlerts = alerts.where((a) => a['severity'] == 'warning' || a['severity'] == 'info').toList();

                return SizedBox(
                  height: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Critical Stock Section
                        if (criticalAlerts.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: AppTheme.errorColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Critical Stock (${criticalAlerts.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildAlertGrid(criticalAlerts, 'critical'),
                          const SizedBox(height: 16),
                        ],

                        // Low Stock Section
                        if (lowStockAlerts.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: AppTheme.warningColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Low Stock (${lowStockAlerts.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildAlertGrid(lowStockAlerts, 'warning'),
                        ],
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertGrid(List<Map<String, dynamic>> alerts, String severity) {
    Color alertColor;
    IconData alertIcon;

    switch (severity) {
      case 'critical':
        alertColor = AppTheme.errorColor;
        alertIcon = Icons.error;
        break;
      case 'warning':
        alertColor = AppTheme.warningColor;
        alertIcon = Icons.warning;
        break;
      default:
        alertColor = Colors.blue;
        alertIcon = Icons.info;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];

        return InkWell(
          onTap: () {
            // Navigate to Stock Dashboard
            context.go('/admin/stock');
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: alertColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
              color: alertColor.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(alertIcon, color: alertColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        alert['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${alert['sku']} • ${alert['warehouse']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${alert['stock']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: alertColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
