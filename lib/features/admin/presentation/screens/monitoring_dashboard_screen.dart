// lib/features/admin/presentation/screens/monitoring_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/widgets/kpi_card.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/theme/app_theme.dart';

// ============================================================================
// DATA PROVIDERS
// ============================================================================

/// Aggregated monitoring metrics from all data sources
class MonitoringMetrics {
  // Overall metrics
  final double totalRevenue;
  final int totalQuotes;
  final int activeUsers;
  final double globalConversionRate;

  // Trends (vs last month)
  final double revenueTrend;
  final double quotesTrend;
  final double usersTrend;
  final double conversionTrend;

  // Critical alerts
  final int outOfStockCount;
  final int lowStockCount;
  final int pendingApprovalsCount;

  // Top performers (top 3)
  final List<UserPerformance> topPerformers;

  // Recent activity (last 10 quotes)
  final List<Quote> recentQuotes;

  // Sales performance
  final Map<String, double> revenueByMonth; // Last 6 months
  final Map<String, int> quotesByStatus;
  final double averageDealSize;
  final double averageResponseTime; // hours

  // Inventory metrics
  final int totalStock;
  final int totalSKUs;
  final Map<String, int> stockByWarehouse;
  final List<Product> lowStockProducts;

  // Product analytics
  final List<ProductMetric> mostQuotedProducts;
  final List<ProductMetric> bestSellingProducts;
  final Map<String, double> revenueByCategory;
  final int neverQuotedCount;

  // Client analytics
  final List<ClientMetric> topClientsByRevenue;
  final List<ClientMetric> topClientsByProjects;
  final int newClientsThisMonth;
  final double clientLifetimeValue;

  MonitoringMetrics({
    required this.totalRevenue,
    required this.totalQuotes,
    required this.activeUsers,
    required this.globalConversionRate,
    required this.revenueTrend,
    required this.quotesTrend,
    required this.usersTrend,
    required this.conversionTrend,
    required this.outOfStockCount,
    required this.lowStockCount,
    required this.pendingApprovalsCount,
    required this.topPerformers,
    required this.recentQuotes,
    required this.revenueByMonth,
    required this.quotesByStatus,
    required this.averageDealSize,
    required this.averageResponseTime,
    required this.totalStock,
    required this.totalSKUs,
    required this.stockByWarehouse,
    required this.lowStockProducts,
    required this.mostQuotedProducts,
    required this.bestSellingProducts,
    required this.revenueByCategory,
    required this.neverQuotedCount,
    required this.topClientsByRevenue,
    required this.topClientsByProjects,
    required this.newClientsThisMonth,
    required this.clientLifetimeValue,
  });
}

class UserPerformance {
  final String userId;
  final String displayName;
  final String email;
  final double revenue;
  final int quotesCount;
  final double conversionRate;

  UserPerformance({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.revenue,
    required this.quotesCount,
    required this.conversionRate,
  });
}

class ProductMetric {
  final String sku;
  final String name;
  final int count;
  final double revenue;

  ProductMetric({
    required this.sku,
    required this.name,
    required this.count,
    required this.revenue,
  });
}

class ClientMetric {
  final String clientId;
  final String companyName;
  final double revenue;
  final int projectCount;

  ClientMetric({
    required this.clientId,
    required this.companyName,
    required this.revenue,
    required this.projectCount,
  });
}

/// Main monitoring metrics provider - fetches all data from Firebase
final monitoringMetricsProvider = StreamProvider.autoDispose<MonitoringMetrics>((ref) async* {
  // Refresh every 30 seconds
  while (true) {
    try {
      // Fetch all data in parallel
      final db = FirebaseDatabase.instance;

    // Get data snapshots
    final productsSnapshot = await db.ref('products').get();
    final quotesSnapshot = await db.ref('quotes').get();
    final usersSnapshot = await db.ref('users').get();

    // Parse products
    final products = <Product>[];
    if (productsSnapshot.value != null) {
      final data = productsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final productMap = Map<String, dynamic>.from(value);
          productMap['id'] = key;
          try {
            products.add(Product.fromMap(productMap));
          } catch (e) {
            AppLogger.error('Error parsing product $key', error: e);
          }
        }
      });
    }

    // Parse quotes from all users
    final allQuotes = <Quote>[];
    final quotesByUser = <String, List<Quote>>{};
    final productQuoteCounts = <String, int>{};
    final productRevenue = <String, double>{};

    if (quotesSnapshot.value != null) {
      final quotesData = quotesSnapshot.value as Map<dynamic, dynamic>;
      quotesData.forEach((userId, userQuotesData) {
        if (userQuotesData is Map) {
          final userQuotes = <Quote>[];
          userQuotesData.forEach((quoteId, quoteData) {
            if (quoteData is Map) {
              try {
                final quoteMap = Map<String, dynamic>.from(quoteData);
                quoteMap['id'] = quoteId;
                quoteMap['userId'] = userId;
                final quote = Quote.fromMap(quoteMap);
                allQuotes.add(quote);
                userQuotes.add(quote);

                // Track product quotes
                for (final item in quote.items) {
                  final sku = item.product?.sku ?? item.product?.model ?? '';
                  if (sku.isNotEmpty) {
                    productQuoteCounts[sku] = (productQuoteCounts[sku] ?? 0) + item.quantity;

                    if (quote.status.toLowerCase() == 'accepted' ||
                        quote.status.toLowerCase() == 'closed' ||
                        quote.status.toLowerCase() == 'sold') {
                      productRevenue[sku] = (productRevenue[sku] ?? 0) + item.total;
                    }
                  }
                }
              } catch (e) {
                AppLogger.error('Error parsing quote $quoteId', error: e);
              }
            }
          });
          quotesByUser[userId.toString()] = userQuotes;
        }
      });
    }

    // Parse users
    final users = <String, Map<String, dynamic>>{};
    if (usersSnapshot.value != null) {
      final data = usersSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          users[key.toString()] = Map<String, dynamic>.from(value);
        }
      });
    }

    // Calculate metrics
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final sixMonthsAgo = DateTime(now.year, now.month - 6);

    // Overall metrics
    double totalRevenue = 0;
    int totalQuotes = allQuotes.length;
    int acceptedQuotes = 0;

    double lastMonthRevenue = 0;
    int lastMonthQuotes = 0;
    int lastMonthAccepted = 0;

    final revenueByMonth = <String, double>{};
    final quotesByStatus = <String, int>{};
    final List<Quote> recentQuotes = [];

    // Initialize last 6 months
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final monthKey = DateFormat('MMM').format(month);
      revenueByMonth[monthKey] = 0;
    }

    for (final quote in allQuotes) {
      // Status counts
      final status = quote.status.toLowerCase();
      quotesByStatus[status] = (quotesByStatus[status] ?? 0) + 1;

      // Revenue calculation - Only count 'closed' status as sales
      if (status == 'closed') {
        totalRevenue += quote.total;
        acceptedQuotes++;

        // Monthly revenue
        if (quote.createdAt.isAfter(sixMonthsAgo)) {
          final monthKey = DateFormat('MMM').format(quote.createdAt);
          revenueByMonth[monthKey] = (revenueByMonth[monthKey] ?? 0) + quote.total;
        }

        // Last month comparison
        if (quote.createdAt.month == lastMonth.month &&
            quote.createdAt.year == lastMonth.year) {
          lastMonthRevenue += quote.total;
          lastMonthAccepted++;
        }
      }

      // Last month quotes count
      if (quote.createdAt.month == lastMonth.month &&
          quote.createdAt.year == lastMonth.year) {
        lastMonthQuotes++;
      }

      // Recent quotes (last 10)
      if (recentQuotes.length < 10) {
        recentQuotes.add(quote);
      }
    }

    // Sort recent quotes by date
    recentQuotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Active users (logged in within last 30 days)
    int activeUsers = 0;
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    users.forEach((userId, userData) {
      final lastLogin = _parseDateTime(userData['lastLoginAt']);
      if (lastLogin != null && lastLogin.isAfter(thirtyDaysAgo)) {
        activeUsers++;
      }
    });

    // Calculate trends
    final currentMonthRevenue = totalRevenue - lastMonthRevenue;
    final currentMonthQuotes = totalQuotes - lastMonthQuotes;

    final revenueTrend = lastMonthRevenue > 0
        ? ((currentMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100
        : 0.0;
    final quotesTrend = lastMonthQuotes > 0
        ? ((currentMonthQuotes - lastMonthQuotes) / lastMonthQuotes) * 100
        : 0.0;
    final usersTrend = 0.0; // Would need historical data

    final globalConversionRate = totalQuotes > 0
        ? (acceptedQuotes / totalQuotes) * 100
        : 0.0;
    final lastMonthConversion = lastMonthQuotes > 0
        ? (lastMonthAccepted / lastMonthQuotes) * 100
        : 0.0;
    final conversionTrend = lastMonthConversion > 0
        ? ((globalConversionRate - lastMonthConversion) / lastMonthConversion) * 100
        : 0.0;

    // Inventory metrics
    int totalStock = 0;
    int totalSKUs = products.length;
    int outOfStockCount = 0;
    int lowStockCount = 0;
    final stockByWarehouse = <String, int>{};
    final lowStockProducts = <Product>[];

    for (final product in products) {
      final stock = product.stock;
      totalStock += stock;

      if (stock == 0) {
        outOfStockCount++;
      } else if (stock < 10) {
        lowStockCount++;
        if (lowStockProducts.length < 20) {
          lowStockProducts.add(product);
        }
      }

      final warehouse = product.warehouse ?? 'Unknown';
      stockByWarehouse[warehouse] = (stockByWarehouse[warehouse] ?? 0) + stock;
    }

    // Top performers (by revenue)
    final userPerformance = <UserPerformance>[];
    quotesByUser.forEach((userId, userQuotes) {
      double userRevenue = 0;
      int userAccepted = 0;

      for (final quote in userQuotes) {
        final status = quote.status.toLowerCase();
        // Only count 'closed' status as sales
        if (status == 'closed') {
          userRevenue += quote.total;
          userAccepted++;
        }
      }

      final userConversion = userQuotes.isNotEmpty
          ? (userAccepted / userQuotes.length) * 100
          : 0.0;

      final userData = users[userId];
      userPerformance.add(UserPerformance(
        userId: userId,
        displayName: userData?['displayName'] ?? 'Unknown',
        email: userData?['email'] ?? 'unknown@email.com',
        revenue: userRevenue,
        quotesCount: userQuotes.length,
        conversionRate: userConversion,
      ));
    });

    userPerformance.sort((a, b) => b.revenue.compareTo(a.revenue));
    final topPerformers = userPerformance.take(3).toList();

    // Product analytics
    final mostQuoted = <ProductMetric>[];
    final bestSelling = <ProductMetric>[];

    productQuoteCounts.forEach((sku, count) {
      final product = products.firstWhere(
        (p) => p.sku == sku || p.model == sku,
        orElse: () => Product(
          id: sku,
          model: sku,
          displayName: 'Unknown Product',
          name: 'Unknown Product',
          description: 'Product not found',
          sku: sku,
          price: 0,
          stock: 0,
          category: 'Unknown',
          createdAt: DateTime.now(),
        ),
      );

      mostQuoted.add(ProductMetric(
        sku: sku,
        name: product.name,
        count: count,
        revenue: productRevenue[sku] ?? 0,
      ));
    });

    mostQuoted.sort((a, b) => b.count.compareTo(a.count));
    bestSelling.addAll(mostQuoted);
    bestSelling.sort((a, b) => b.revenue.compareTo(a.revenue));

    final neverQuotedCount = products.length - productQuoteCounts.length;

    // Revenue by category
    final revenueByCategory = <String, double>{};
    for (final quote in allQuotes) {
      if (quote.status.toLowerCase() == 'accepted' ||
          quote.status.toLowerCase() == 'closed' ||
          quote.status.toLowerCase() == 'sold') {
        for (final item in quote.items) {
          final category = item.product?.category ?? 'Other';
          revenueByCategory[category] = (revenueByCategory[category] ?? 0) + item.total;
        }
      }
    }

    // Client analytics - Calculate from real data
    final clientMetricsMap = <String, ClientMetric>{};
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    int newClientsThisMonth = 0;

    for (final quote in allQuotes) {
      if (quote.client != null) {
        final clientId = quote.client!.id ?? quote.client!.email;

        // Track new clients this month
        if (quote.createdAt.isAfter(firstDayOfMonth)) {
          // Check if this is client's first quote
          final clientQuotes = allQuotes.where((q) =>
            q.client?.id == clientId || q.client?.email == quote.client!.email
          ).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          if (clientQuotes.first.id == quote.id) {
            newClientsThisMonth++;
          }
        }

        if (!clientMetricsMap.containsKey(clientId)) {
          clientMetricsMap[clientId] = ClientMetric(
            clientId: clientId,
            companyName: quote.client!.company,
            revenue: 0,
            projectCount: 0,
          );
        }

        // Add revenue for accepted/closed quotes
        if (quote.status == 'accepted' || quote.status == 'closed' || quote.status == 'sold') {
          clientMetricsMap[clientId] = ClientMetric(
            clientId: clientId,
            companyName: clientMetricsMap[clientId]!.companyName,
            revenue: clientMetricsMap[clientId]!.revenue + quote.total,
            projectCount: clientMetricsMap[clientId]!.projectCount + 1,
          );
        }
      }
    }

    // Sort clients by revenue and projects
    final topClientsByRevenue = clientMetricsMap.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final topClientsByProjects = clientMetricsMap.values.toList()
      ..sort((a, b) => b.projectCount.compareTo(a.projectCount));

    final clientLifetimeValue = clientMetricsMap.isNotEmpty
      ? totalRevenue / clientMetricsMap.length
      : 0.0;

    // Average metrics
    final averageDealSize = acceptedQuotes > 0 ? totalRevenue / acceptedQuotes : 0.0;

    // Calculate average response time from quote timestamps
    double averageResponseTime = 24.0; // Default fallback
    if (allQuotes.length > 1) {
      final responseTimes = <double>[];
      for (int i = 1; i < allQuotes.length; i++) {
        final timeDiff = allQuotes[i].createdAt.difference(allQuotes[i - 1].createdAt);
        if (timeDiff.inHours > 0 && timeDiff.inHours < 168) { // Within 1 week
          responseTimes.add(timeDiff.inHours.toDouble());
        }
      }
      if (responseTimes.isNotEmpty) {
        averageResponseTime = responseTimes.reduce((a, b) => a + b) / responseTimes.length;
      }
    }

    // Get real pending approvals count
    int pendingApprovalsCount = 0;
    try {
      final db = FirebaseDatabase.instance;
      final approvalsSnapshot = await db.ref('user_approval_requests').get();
      if (approvalsSnapshot.exists && approvalsSnapshot.value != null) {
        final approvals = approvalsSnapshot.value as Map<dynamic, dynamic>;
        pendingApprovalsCount = approvals.values.where((approval) {
          if (approval is Map) {
            return approval['status'] == 'pending';
          }
          return false;
        }).length;
      }
    } catch (e) {
      AppLogger.error('Error fetching pending approvals', error: e, category: LogCategory.business);
    }

    yield MonitoringMetrics(
      totalRevenue: totalRevenue,
      totalQuotes: totalQuotes,
      activeUsers: activeUsers,
      globalConversionRate: globalConversionRate,
      revenueTrend: revenueTrend,
      quotesTrend: quotesTrend,
      usersTrend: usersTrend,
      conversionTrend: conversionTrend,
      outOfStockCount: outOfStockCount,
      lowStockCount: lowStockCount,
      pendingApprovalsCount: pendingApprovalsCount,
      topPerformers: topPerformers,
      recentQuotes: recentQuotes.take(10).toList(),
      revenueByMonth: revenueByMonth,
      quotesByStatus: quotesByStatus,
      averageDealSize: averageDealSize,
      averageResponseTime: averageResponseTime,
      totalStock: totalStock,
      totalSKUs: totalSKUs,
      stockByWarehouse: stockByWarehouse,
      lowStockProducts: lowStockProducts,
      mostQuotedProducts: mostQuoted.take(10).toList(),
      bestSellingProducts: bestSelling.take(10).toList(),
      revenueByCategory: revenueByCategory,
      neverQuotedCount: neverQuotedCount,
      topClientsByRevenue: topClientsByRevenue,
      topClientsByProjects: topClientsByProjects,
      newClientsThisMonth: newClientsThisMonth,
      clientLifetimeValue: clientLifetimeValue,
    );

      // Auto-refresh every 30 seconds
      await Future.delayed(const Duration(seconds: 30));
    } catch (e) {
      AppLogger.error('Error fetching monitoring metrics', error: e);
      // Yield error state or empty metrics
      yield MonitoringMetrics(
        totalRevenue: 0,
        totalQuotes: 0,
        activeUsers: 0,
        globalConversionRate: 0,
        revenueTrend: 0,
        quotesTrend: 0,
        usersTrend: 0,
        conversionTrend: 0,
        outOfStockCount: 0,
        lowStockCount: 0,
        pendingApprovalsCount: 0,
        topPerformers: [],
        recentQuotes: [],
        revenueByMonth: {},
        quotesByStatus: {},
        averageDealSize: 0,
        averageResponseTime: 0,
        totalStock: 0,
        totalSKUs: 0,
        stockByWarehouse: {},
        lowStockProducts: [],
        mostQuotedProducts: [],
        bestSellingProducts: [],
        revenueByCategory: {},
        neverQuotedCount: 0,
        topClientsByRevenue: [],
        topClientsByProjects: [],
        newClientsThisMonth: 0,
        clientLifetimeValue: 0,
      );
      await Future.delayed(const Duration(seconds: 30));
    }
  }
});

// Helper function to parse DateTime
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class MonitoringDashboardScreen extends ConsumerStatefulWidget {
  const MonitoringDashboardScreen({super.key});

  @override
  ConsumerState<MonitoringDashboardScreen> createState() => _MonitoringDashboardScreenState();
}

class _MonitoringDashboardScreenState extends ConsumerState<MonitoringDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final _dateFormat = DateFormat('MMM d, h:mm a');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RBAC check
    final hasAccessAsync = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAccessAsync.when(
      data: (hasAccess) {
        if (!hasAccess) {
          return Scaffold(
            appBar: AppBar(title: const Text('Monitoring Dashboard')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('You do not have permission to view this dashboard.'),
                ],
              ),
            ),
          );
        }

        return _buildDashboard();
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Monitoring Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Monitoring Dashboard')),
        body: Center(child: Text('Error checking permissions: $error')),
      ),
    );
  }

  Widget _buildDashboard() {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(monitoringMetricsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing data...')),
              );
            },
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: ResponsiveHelper.isMobile(context),
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'Sales', icon: Icon(Icons.trending_up, size: 18)),
            Tab(text: 'Inventory', icon: Icon(Icons.inventory, size: 18)),
            Tab(text: 'Products', icon: Icon(Icons.category, size: 18)),
            Tab(text: 'Clients', icon: Icon(Icons.people, size: 18)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monitoringMetricsProvider);
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildSalesTab(),
            _buildInventoryTab(),
            _buildProductsTab(),
            _buildClientsTab(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: OVERVIEW
  // ============================================================================

  Widget _buildOverviewTab() {
    final metricsAsync = ref.watch(monitoringMetricsProvider);

    return metricsAsync.when(
      data: (metrics) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            KPICardGrid(
              children: [
                KPICard(
                  title: 'Total Revenue',
                  value: _currencyFormat.format(metrics.totalRevenue),
                  icon: Icons.attach_money,
                  color: AppTheme.successColor,
                  subtitle: TrendIndicator(
                    value: metrics.revenueTrend,
                    comparison: 'vs last month',
                  ).toString(),
                ),
                KPICard(
                  title: 'Total Quotes',
                  value: metrics.totalQuotes.toString(),
                  icon: Icons.description,
                  color: AppTheme.accentPrimary,
                  subtitle: TrendIndicator(
                    value: metrics.quotesTrend,
                    comparison: 'vs last month',
                  ).toString(),
                ),
                KPICard(
                  title: 'Active Users',
                  value: metrics.activeUsers.toString(),
                  icon: Icons.people,
                  color: AppTheme.accentSecondary,
                  subtitle: TrendIndicator(
                    value: metrics.usersTrend,
                    comparison: 'vs last month',
                  ).toString(),
                ),
                KPICard(
                  title: 'Conversion Rate',
                  value: '${metrics.globalConversionRate.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: AppTheme.warningColor,
                  subtitle: TrendIndicator(
                    value: metrics.conversionTrend,
                    comparison: 'vs last month',
                  ).toString(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Critical Alerts
            if (metrics.outOfStockCount > 0 || metrics.lowStockCount > 0 || metrics.pendingApprovalsCount > 0)
              _buildCriticalAlerts(metrics),

            const SizedBox(height: 24),

            // Top 3 Performers
            _buildTopPerformers(metrics),

            const SizedBox(height: 24),

            // Recent Activity
            _buildRecentActivity(metrics),
          ],
        ),
      ),
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard metrics...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      error: (error, stack) {
        AppLogger.error('Error loading overview', error: error, stackTrace: stack);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading data: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(monitoringMetricsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCriticalAlerts(MonitoringMetrics metrics) {
    return Card(
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: AppTheme.errorColor),
                const SizedBox(width: 8),
                Text(
                  'Critical Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (metrics.outOfStockCount > 0)
              _buildAlertItem(
                icon: Icons.inventory_2,
                text: '${metrics.outOfStockCount} products out of stock',
                color: AppTheme.errorColor,
              ),
            if (metrics.lowStockCount > 0)
              _buildAlertItem(
                icon: Icons.warning_amber,
                text: '${metrics.lowStockCount} products with low stock',
                color: AppTheme.warningColor,
              ),
            if (metrics.pendingApprovalsCount > 0)
              _buildAlertItem(
                icon: Icons.pending_actions,
                text: '${metrics.pendingApprovalsCount} pending approvals',
                color: AppTheme.warningColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem({required IconData icon, required String text, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildTopPerformers(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.topPerformers.isEmpty)
              const Center(child: Text('No performance data available'))
            else
              ...metrics.topPerformers.asMap().entries.map((entry) {
                final index = entry.key;
                final performer = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index == 0
                        ? Colors.amber
                        : index == 1
                            ? Colors.grey
                            : Colors.brown,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(performer.displayName),
                  subtitle: Text(
                    '${performer.quotesCount} quotes • ${performer.conversionRate.toStringAsFixed(1)}% conversion',
                  ),
                  trailing: Text(
                    _currencyFormat.format(performer.revenue),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.recentQuotes.isEmpty)
              const Center(child: Text('No recent quotes'))
            else
              ...metrics.recentQuotes.map((quote) => ListTile(
                leading: Icon(
                  _getStatusIcon(quote.status),
                  color: _getStatusColor(quote.status),
                ),
                title: Text('Quote ${quote.quoteNumber ?? quote.id}'),
                subtitle: Text(_dateFormat.format(quote.createdAt)),
                trailing: Text(
                  _currencyFormat.format(quote.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 2: SALES PERFORMANCE
  // ============================================================================

  Widget _buildSalesTab() {
    final metricsAsync = ref.watch(monitoringMetricsProvider);

    return metricsAsync.when(
      data: (metrics) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            KPICardGrid(
              crossAxisCount: ResponsiveHelper.isDesktop(context) ? 4 : 2,
              children: [
                KPICard(
                  title: 'Average Deal Size',
                  value: _currencyFormat.format(metrics.averageDealSize),
                  icon: Icons.monetization_on,
                  color: AppTheme.successColor,
                ),
                KPICard(
                  title: 'Response Time',
                  value: '${metrics.averageResponseTime.toStringAsFixed(1)}h',
                  icon: Icons.access_time,
                  color: AppTheme.accentSecondary,
                ),
                KPICard(
                  title: 'Total Revenue',
                  value: _currencyFormat.format(metrics.totalRevenue),
                  icon: Icons.attach_money,
                  color: AppTheme.successColor,
                ),
                KPICard(
                  title: 'Conversion Rate',
                  value: '${metrics.globalConversionRate.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: AppTheme.warningColor,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Revenue Trend Chart
            _buildRevenueChart(metrics),

            const SizedBox(height: 24),

            // Top 10 Users by Revenue
            _buildTopUsersLeaderboard(metrics),

            const SizedBox(height: 24),

            // Quotes by Status
            _buildQuotesByStatusChart(metrics),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildRevenueChart(MonitoringMetrics metrics) {
    final chartHeight = ResponsiveHelper.isMobile(context)
        ? 250.0
        : ResponsiveHelper.isTablet(context)
            ? 300.0
            : 400.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend (Last 6 Months)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _currencyFormat.format(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < metrics.revenueByMonth.length) {
                            return Text(
                              metrics.revenueByMonth.keys.elementAt(index),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: metrics.revenueByMonth.values
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.accentPrimary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUsersLeaderboard(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 10 Sales Representatives',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.topPerformers.isEmpty)
              const Center(child: Text('No data available'))
            else
              ...metrics.topPerformers.take(10).map((user) => ListTile(
                leading: CircleAvatar(
                  child: Text(user.displayName[0].toUpperCase()),
                ),
                title: Text(user.displayName),
                subtitle: Text('${user.quotesCount} quotes'),
                trailing: Text(
                  _currencyFormat.format(user.revenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesByStatusChart(MonitoringMetrics metrics) {
    final chartHeight = ResponsiveHelper.isMobile(context) ? 250.0 : 300.0;

    final sections = metrics.quotesByStatus.entries.map((entry) {
      final color = _getStatusColor(entry.key);
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.value}',
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quotes by Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: metrics.quotesByStatus.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: _getStatusColor(entry.key),
                    ),
                    const SizedBox(width: 4),
                    Text('${entry.key}: ${entry.value}'),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 3: INVENTORY
  // ============================================================================

  Widget _buildInventoryTab() {
    final metricsAsync = ref.watch(monitoringMetricsProvider);

    return metricsAsync.when(
      data: (metrics) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            KPICardGrid(
              children: [
                KPICard(
                  title: 'Total Stock',
                  value: metrics.totalStock.toString(),
                  icon: Icons.inventory,
                  color: AppTheme.accentPrimary,
                ),
                KPICard(
                  title: 'Total SKUs',
                  value: metrics.totalSKUs.toString(),
                  icon: Icons.qr_code,
                  color: AppTheme.accentSecondary,
                ),
                KPICard(
                  title: 'Low Stock',
                  value: metrics.lowStockCount.toString(),
                  icon: Icons.warning,
                  color: AppTheme.warningColor,
                ),
                KPICard(
                  title: 'Out of Stock',
                  value: metrics.outOfStockCount.toString(),
                  icon: Icons.error,
                  color: AppTheme.errorColor,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Critical Stock Alerts
            if (metrics.outOfStockCount > 0)
              Card(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppTheme.errorColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${metrics.outOfStockCount} products are out of stock',
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Stock by Warehouse
            _buildStockByWarehouseChart(metrics),

            const SizedBox(height: 24),

            // Low Stock Products Table
            _buildLowStockTable(metrics),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildStockByWarehouseChart(MonitoringMetrics metrics) {
    final chartHeight = ResponsiveHelper.isMobile(context) ? 250.0 : 300.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock by Warehouse',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < metrics.stockByWarehouse.length) {
                            return Text(
                              metrics.stockByWarehouse.keys.elementAt(index),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: metrics.stockByWarehouse.entries
                      .toList()
                      .asMap()
                      .entries
                      .map((e) => BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.value.toDouble(),
                                color: AppTheme.accentPrimary,
                                width: 20,
                              ),
                            ],
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockTable(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Low Stock Products (< 10 units)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.lowStockProducts.isEmpty)
              const Center(child: Text('No low stock products'))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('SKU')),
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Stock')),
                    DataColumn(label: Text('Warehouse')),
                  ],
                  rows: metrics.lowStockProducts.map((product) {
                    final stock = product.stock;
                    return DataRow(cells: [
                      DataCell(Text(product.sku ?? product.model)),
                      DataCell(Text(product.name)),
                      DataCell(
                        Text(
                          stock.toString(),
                          style: TextStyle(
                            color: stock == 0
                                ? AppTheme.errorColor
                                : AppTheme.warningColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(Text(product.warehouse ?? 'Unknown')),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 4: PRODUCT ANALYTICS
  // ============================================================================

  Widget _buildProductsTab() {
    final metricsAsync = ref.watch(monitoringMetricsProvider);

    return metricsAsync.when(
      data: (metrics) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Card
            KPICardGrid(
              crossAxisCount: ResponsiveHelper.isDesktop(context) ? 4 : 2,
              children: [
                KPICard(
                  title: 'Total Products',
                  value: metrics.totalSKUs.toString(),
                  icon: Icons.category,
                  color: AppTheme.accentPrimary,
                ),
                KPICard(
                  title: 'Never Quoted',
                  value: metrics.neverQuotedCount.toString(),
                  icon: Icons.trending_down,
                  color: AppTheme.errorColor,
                ),
                KPICard(
                  title: 'Best Sellers',
                  value: metrics.bestSellingProducts.length.toString(),
                  icon: Icons.star,
                  color: AppTheme.warningColor,
                ),
                KPICard(
                  title: 'Most Quoted',
                  value: metrics.mostQuotedProducts.length.toString(),
                  icon: Icons.format_quote,
                  color: AppTheme.accentSecondary,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Most Quoted Products
            _buildMostQuotedProducts(metrics),

            const SizedBox(height: 24),

            // Best Selling Products
            _buildBestSellingProducts(metrics),

            const SizedBox(height: 24),

            // Revenue by Category
            _buildRevenueByCategoryChart(metrics),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildMostQuotedProducts(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Quoted Products (Top 10)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.mostQuotedProducts.isEmpty)
              const Center(child: Text('No data available'))
            else
              ...metrics.mostQuotedProducts.map((product) => ListTile(
                leading: CircleAvatar(
                  child: Text(product.count.toString()),
                ),
                title: Text(product.name),
                subtitle: Text('SKU: ${product.sku}'),
                trailing: Text(
                  '${product.count} quotes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildBestSellingProducts(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Best Selling Products (Top 10)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.bestSellingProducts.isEmpty)
              const Center(child: Text('No data available'))
            else
              ...metrics.bestSellingProducts.map((product) => ListTile(
                leading: const Icon(Icons.star, color: AppTheme.warningColor),
                title: Text(product.name),
                subtitle: Text('SKU: ${product.sku}'),
                trailing: Text(
                  _currencyFormat.format(product.revenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueByCategoryChart(MonitoringMetrics metrics) {
    final chartHeight = ResponsiveHelper.isMobile(context) ? 250.0 : 300.0;

    final sections = metrics.revenueByCategory.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: _currencyFormat.format(entry.value),
        color: _getCategoryColor(entry.key),
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue by Category',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: metrics.revenueByCategory.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: _getCategoryColor(entry.key),
                    ),
                    const SizedBox(width: 4),
                    Text('${entry.key}: ${_currencyFormat.format(entry.value)}'),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 5: CLIENT ANALYTICS
  // ============================================================================

  Widget _buildClientsTab() {
    final metricsAsync = ref.watch(monitoringMetricsProvider);

    return metricsAsync.when(
      data: (metrics) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards
            KPICardGrid(
              crossAxisCount: ResponsiveHelper.isDesktop(context) ? 4 : 2,
              children: [
                KPICard(
                  title: 'Total Clients',
                  value: metrics.topClientsByRevenue.length.toString(),
                  icon: Icons.business,
                  color: AppTheme.accentPrimary,
                ),
                KPICard(
                  title: 'New This Month',
                  value: metrics.newClientsThisMonth.toString(),
                  icon: Icons.add_business,
                  color: AppTheme.successColor,
                ),
                KPICard(
                  title: 'Avg Lifetime Value',
                  value: _currencyFormat.format(metrics.clientLifetimeValue),
                  icon: Icons.trending_up,
                  color: AppTheme.warningColor,
                ),
                KPICard(
                  title: 'Active Clients',
                  value: metrics.topClientsByProjects.length.toString(),
                  icon: Icons.people,
                  color: AppTheme.accentSecondary,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Top Clients by Revenue
            _buildTopClientsByRevenue(metrics),

            const SizedBox(height: 24),

            // Top Clients by Projects
            _buildTopClientsByProjects(metrics),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildTopClientsByRevenue(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 10 Clients by Revenue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.topClientsByRevenue.isEmpty)
              const Center(child: Text('No client data available'))
            else
              ...metrics.topClientsByRevenue.take(10).map((client) => ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.business),
                ),
                title: Text(client.companyName),
                subtitle: Text('${client.projectCount} projects'),
                trailing: Text(
                  _currencyFormat.format(client.revenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildTopClientsByProjects(MonitoringMetrics metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 10 Clients by Project Count',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.topClientsByProjects.isEmpty)
              const Center(child: Text('No client data available'))
            else
              ...metrics.topClientsByProjects.take(10).map((client) => ListTile(
                leading: CircleAvatar(
                  child: Text(client.projectCount.toString()),
                ),
                title: Text(client.companyName),
                subtitle: Text(_currencyFormat.format(client.revenue)),
                trailing: Text(
                  '${client.projectCount} projects',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'closed':
      case 'sold':
        return Icons.check_circle;
      case 'pending':
      case 'sent':
        return Icons.pending;
      case 'rejected':
      case 'expired':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'closed':
      case 'sold':
        return AppTheme.successColor;
      case 'pending':
      case 'sent':
        return AppTheme.warningColor;
      case 'rejected':
      case 'expired':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    final colors = [
      AppTheme.accentPrimary,
      AppTheme.accentSecondary,
      AppTheme.successColor,
      AppTheme.warningColor,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    return colors[category.hashCode % colors.length];
  }
}
