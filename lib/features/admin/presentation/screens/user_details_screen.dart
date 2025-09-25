import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/services/app_logger.dart';

// Provider for fetching user's detailed statistics
final userDetailsProvider = StreamProvider.autoDispose.family<UserDetailedStats, String>((ref, userId) {
  final database = FirebaseDatabase.instance;

  return Stream.periodic(const Duration(seconds: 30), (_) => null)
      .asyncMap((_) async {
    try {
      final stats = UserDetailedStats(
        userId: userId,
        quotes: [],
        clients: [],
        topProducts: {},
        monthlyRevenue: {},
        quoteTrends: {},
        categoryBreakdown: {},
      );

      // Fetch user data
      final userSnapshot = await database.ref('users/$userId').get();
      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        stats.email = userData['email'] ?? 'Unknown';
        stats.displayName = userData['displayName'] ?? userData['email'] ?? 'User';
        stats.lastLoginAt = userData['lastLoginAt'] != null
            ? DateTime.parse(userData['lastLoginAt'])
            : null;
      }

      // Fetch quotes
      final quotesSnapshot = await database.ref('quotes/$userId').get();
      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        for (final entry in quotesData.entries) {
          final quoteMap = Map<String, dynamic>.from(entry.value);
          quoteMap['id'] = entry.key;
          stats.quotes.add(Quote.fromMap(quoteMap));
        }
      }

      // Fetch clients
      final clientsSnapshot = await database.ref('clients/$userId').get();
      if (clientsSnapshot.exists) {
        final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);
        for (final entry in clientsData.entries) {
          final clientMap = Map<String, dynamic>.from(entry.value);
          clientMap['id'] = entry.key;
          stats.clients.add(Client.fromMap(clientMap));
        }
      }

      // Calculate statistics
      _calculateStatistics(stats);

      return stats;
    } catch (e) {
      AppLogger.error('Error fetching user details', error: e);
      return UserDetailedStats(
        userId: userId,
        quotes: [],
        clients: [],
        topProducts: {},
        monthlyRevenue: {},
        quoteTrends: {},
        categoryBreakdown: {},
      );
    }
  });
});

void _calculateStatistics(UserDetailedStats stats) {
  final now = DateTime.now();

  // Calculate monthly revenue for the last 6 months
  for (int i = 0; i < 6; i++) {
    final month = DateTime(now.year, now.month - i, 1);
    final monthKey = DateFormat('MMM yyyy').format(month);
    stats.monthlyRevenue[monthKey] = 0;
    stats.quoteTrends[monthKey] = 0;
  }

  // Process quotes
  for (final quote in stats.quotes) {
    final monthKey = DateFormat('MMM yyyy').format(quote.createdAt);

    // Monthly revenue
    if (stats.monthlyRevenue.containsKey(monthKey)) {
      stats.monthlyRevenue[monthKey] = stats.monthlyRevenue[monthKey]! + quote.total;
      stats.quoteTrends[monthKey] = stats.quoteTrends[monthKey]! + 1;
    }

    // Top products and categories
    for (final item in quote.items) {
      final productName = item.productName ?? 'Unknown';
      final category = item.product?.category ?? 'Other';

      stats.topProducts[productName] = (stats.topProducts[productName] ?? 0) + item.quantity;
      stats.categoryBreakdown[category] = (stats.categoryBreakdown[category] ?? 0) + item.total;
    }
  }

  // Sort and limit top products to top 10
  final sortedProducts = stats.topProducts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stats.topProducts = Map.fromEntries(sortedProducts.take(10));
}

class UserDetailedStats {
  final String userId;
  String? email;
  String? displayName;
  DateTime? lastLoginAt;
  final List<Quote> quotes;
  final List<Client> clients;
  Map<String, int> topProducts;
  final Map<String, double> monthlyRevenue;
  final Map<String, int> quoteTrends;
  final Map<String, double> categoryBreakdown;

  UserDetailedStats({
    required this.userId,
    this.email,
    this.displayName,
    this.lastLoginAt,
    required this.quotes,
    required this.clients,
    required this.topProducts,
    required this.monthlyRevenue,
    required this.quoteTrends,
    required this.categoryBreakdown,
  });
}

class UserDetailsScreen extends ConsumerWidget {
  final String userId;
  final String userEmail;
  final String userName;

  const UserDetailsScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(userDetailsProvider(userId));
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userName),
            Text(
              userEmail,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userDetailsProvider(userId));
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key Metrics Cards
                _buildMetricsCards(stats, theme, isMobile),
                const SizedBox(height: 24),

                // Charts Section
                if (isMobile) ...[
                  _buildQuoteTrendsChart(stats, theme),
                  const SizedBox(height: 24),
                  _buildRevenueChart(stats, theme),
                  const SizedBox(height: 24),
                  _buildTopProductsChart(stats, theme),
                  const SizedBox(height: 24),
                  _buildCategoryBreakdownChart(stats, theme),
                ] else ...[
                  // Desktop/Tablet layout - 2 columns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildQuoteTrendsChart(stats, theme),
                            const SizedBox(height: 24),
                            _buildTopProductsChart(stats, theme),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildRevenueChart(stats, theme),
                            const SizedBox(height: 24),
                            _buildCategoryBreakdownChart(stats, theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Recent Quotes Table
                _buildRecentQuotesTable(stats, theme, isMobile),

                const SizedBox(height: 24),

                // Clients List
                _buildClientsList(stats, theme, isMobile),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading user details: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(userDetailsProvider(userId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsCards(UserDetailedStats stats, ThemeData theme, bool isMobile) {
    final metrics = [
      {
        'title': 'Total Quotes',
        'value': stats.quotes.length.toString(),
        'icon': Icons.description,
        'color': Colors.blue,
      },
      {
        'title': 'Total Clients',
        'value': stats.clients.length.toString(),
        'icon': Icons.people,
        'color': Colors.green,
      },
      {
        'title': 'Total Revenue',
        'value': NumberFormat.currency(symbol: '\$').format(
          stats.quotes.fold(0.0, (sum, q) => sum + q.total),
        ),
        'icon': Icons.attach_money,
        'color': Colors.orange,
      },
      {
        'title': 'Avg Quote Value',
        'value': stats.quotes.isEmpty
            ? '\$0'
            : NumberFormat.currency(symbol: '\$').format(
                stats.quotes.fold(0.0, (sum, q) => sum + q.total) / stats.quotes.length,
              ),
        'icon': Icons.trending_up,
        'color': Colors.purple,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.5 : 1.8,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  metric['icon'] as IconData,
                  size: 32,
                  color: metric['color'] as Color,
                ),
                const SizedBox(height: 8),
                Text(
                  metric['value'] as String,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric['title'] as String,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuoteTrendsChart(UserDetailedStats stats, ThemeData theme) {
    final sortedMonths = stats.quoteTrends.keys.toList().reversed.toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quote Trends (Last 6 Months)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < sortedMonths.length) {
                            return RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                sortedMonths[value.toInt()].substring(0, 3),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sortedMonths.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          stats.quoteTrends[entry.value]?.toDouble() ?? 0,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
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

  Widget _buildRevenueChart(UserDetailedStats stats, ThemeData theme) {
    final sortedMonths = stats.monthlyRevenue.keys.toList().reversed.toList();
    final maxRevenue = stats.monthlyRevenue.values.fold(0.0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Revenue',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxRevenue * 1.2,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compactCurrency(symbol: '\$').format(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < sortedMonths.length) {
                            return RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                sortedMonths[value.toInt()].substring(0, 3),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: sortedMonths.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: stats.monthlyRevenue[entry.value] ?? 0,
                          color: Colors.green,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsChart(UserDetailedStats stats, ThemeData theme) {
    final topProducts = stats.topProducts.entries.take(10).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 10 Products',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...topProducts.map((entry) {
              final maxQty = topProducts.first.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.key,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: LinearProgressIndicator(
                        value: entry.value / maxQty,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.value.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdownChart(UserDetailedStats stats, ThemeData theme) {
    final categories = stats.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalRevenue = categories.fold(0.0, (sum, e) => sum + e.value);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue by Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: categories.take(5).map((entry) {
                    final percentage = (entry.value / totalRevenue * 100);
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: _getCategoryColor(entry.key),
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
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: categories.take(5).map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: _getCategoryColor(entry.key),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.key,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentQuotesTable(UserDetailedStats stats, ThemeData theme, bool isMobile) {
    final recentQuotes = stats.quotes.take(10).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Quotes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Quote #')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Status')),
                ],
                rows: recentQuotes.map((quote) {
                  return DataRow(cells: [
                    DataCell(Text(quote.quoteNumber ?? 'N/A')),
                    DataCell(Text(DateFormat('MM/dd/yyyy').format(quote.createdAt))),
                    DataCell(Text(quote.client?.company ?? 'N/A')),
                    DataCell(Text(NumberFormat.currency(symbol: '\$').format(quote.total))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(quote.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          quote.status,
                          style: TextStyle(
                            color: _getStatusColor(quote.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsList(UserDetailedStats stats, ThemeData theme, bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clients (${stats.clients.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...stats.clients.take(5).map((client) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    client.company.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
                title: Text(client.company),
                subtitle: Text('${client.contactName ?? 'N/A'} • ${client.email ?? 'N/A'}'),
                trailing: Text(
                  client.phone ?? '',
                  style: theme.textTheme.bodySmall,
                ),
              );
            }),
            if (stats.clients.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${stats.clients.length - 5} more clients',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];
    return colors[category.hashCode % colors.length];
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'closed':
      case 'sold':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}