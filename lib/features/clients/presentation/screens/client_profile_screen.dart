// lib/features/clients/presentation/screens/client_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/models/models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../quotes/presentation/screens/quote_detail_screen.dart';
import '../../../projects/presentation/screens/project_detail_screen.dart';

// Provider for client quotes
final clientQuotesProvider = StreamProvider.family.autoDispose<List<Quote>, String>((ref, clientId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final database = FirebaseDatabase.instance;
  return database
      .ref('quotes/${user.uid}')
      .orderByChild('clientId')
      .equalTo(clientId)
      .onValue
      .map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return [];

    final quotesMap = event.snapshot.value as Map;
    return quotesMap.entries.map((entry) {
      final quoteData = Map<String, dynamic>.from(entry.value);
      quoteData['id'] = entry.key;
      return Quote.fromMap(quoteData);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});

// Provider for client projects
final clientProjectsProvider = StreamProvider.family.autoDispose<List<Project>, String>((ref, clientId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final database = FirebaseDatabase.instance;
  return database
      .ref('projects/${user.uid}')
      .orderByChild('clientId')
      .equalTo(clientId)
      .onValue
      .map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return [];

    final projectsMap = event.snapshot.value as Map;
    return projectsMap.entries.map((entry) {
      final projectData = Map<String, dynamic>.from(entry.value);
      projectData['id'] = entry.key;
      return Project.fromJson(projectData);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});

class ClientProfileScreen extends ConsumerStatefulWidget {
  final Client client;

  const ClientProfileScreen({
    super.key,
    required this.client,
  });

  @override
  ConsumerState<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final dateFormatter = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(clientQuotesProvider(widget.client.id ?? ''));
    final projectsAsync = ref.watch(clientProjectsProvider(widget.client.id ?? ''));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Client Info
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: theme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // Profile Picture or Icon
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Text(
                            widget.client.company.isNotEmpty
                                ? widget.client.company[0].toUpperCase()
                                : 'C',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Company Name
                        Text(
                          widget.client.company,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Contact Name
                        Text(
                          widget.client.contactName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Contact Info Row
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              widget.client.email,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.phone_outlined, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              widget.client.phone,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                        if (widget.client.address != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: Colors.white70),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${widget.client.address}, ${widget.client.city ?? ''}, ${widget.client.state ?? ''} ${widget.client.zipCode ?? ''}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  // Navigate to edit client screen
                  Navigator.of(context).pop({'action': 'edit', 'client': widget.client});
                },
              ),
            ],
          ),

          // Sales Metrics Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: quotesAsync.when(
                data: (quotes) {
                  final metrics = _calculateMetrics(quotes);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales Overview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildMetricCard(
                            'Total Sales',
                            currencyFormatter.format(metrics['totalSales']),
                            Icons.attach_money,
                            Colors.green,
                          ),
                          _buildMetricCard(
                            'Total Quotes',
                            '${metrics['totalQuotes']}',
                            Icons.description,
                            Colors.blue,
                          ),
                          _buildMetricCard(
                            'Avg Order Value',
                            currencyFormatter.format(metrics['avgOrderValue']),
                            Icons.trending_up,
                            Colors.orange,
                          ),
                          _buildMetricCard(
                            'Last Order',
                            metrics['lastOrderDate'] as String,
                            Icons.schedule,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ),

          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: theme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: theme.primaryColor,
                tabs: const [
                  Tab(text: 'Quotes'),
                  Tab(text: 'Projects'),
                  Tab(text: 'Analytics'),
                  Tab(text: 'Notes'),
                ],
              ),
            ),
          ),

          // Tab Views
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Quotes Tab
                quotesAsync.when(
                  data: (quotes) => _buildQuotesTab(quotes),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),

                // Projects Tab
                projectsAsync.when(
                  data: (projects) => _buildProjectsTab(projects),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),

                // Analytics Tab
                quotesAsync.when(
                  data: (quotes) => _buildAnalyticsTab(quotes),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),

                // Notes Tab
                _buildNotesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateMetrics(List<Quote> quotes) {
    if (quotes.isEmpty) {
      return {
        'totalSales': 0.0,
        'totalQuotes': 0,
        'avgOrderValue': 0.0,
        'lastOrderDate': 'No orders yet',
      };
    }

    double totalSales = quotes.fold(0, (sum, quote) => sum + quote.total);
    int totalQuotes = quotes.length;
    double avgOrderValue = totalSales / totalQuotes;
    String lastOrderDate = quotes.isNotEmpty
        ? dateFormatter.format(quotes.first.createdAt)
        : 'No orders yet';

    return {
      'totalSales': totalSales,
      'totalQuotes': totalQuotes,
      'avgOrderValue': avgOrderValue,
      'lastOrderDate': lastOrderDate,
    };
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesTab(List<Quote> quotes) {
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No quotes yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quotes.length,
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                '#${quote.quoteNumber}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            title: Text('Quote #${quote.quoteNumber}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateFormatter.format(quote.createdAt)),
                Text(
                  currencyFormatter.format(quote.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            trailing: Chip(
              label: Text(
                quote.status.toUpperCase(),
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: _getStatusColor(quote.status).withValues(alpha: 0.2),
              labelStyle: TextStyle(color: _getStatusColor(quote.status)),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuoteDetailScreen(quoteId: quote.id ?? ''),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProjectsTab(List<Project> projects) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No projects yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.folder),
            ),
            title: Text(project.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (project.notes != null)
                  Text(
                    project.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'Created: ${dateFormatter.format(project.createdAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to project detail
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailScreen(project: project),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab(List<Quote> quotes) {
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No data to analyze yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    // Calculate monthly sales data
    final monthlyData = _calculateMonthlySales(quotes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly Sales Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Sales Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
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
                                  '\$${(value / 1000).toStringAsFixed(1)}K',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() < 0 || value.toInt() >= monthlyData.length) {
                                  return const Text('');
                                }
                                final month = monthlyData[value.toInt()]['month'] as String;
                                return Text(
                                  month,
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: monthlyData.asMap().entries.map((entry) {
                              return FlSpot(
                                entry.key.toDouble(),
                                entry.value['sales'] as double,
                              );
                            }).toList(),
                            isCurved: true,
                            color: Theme.of(context).primaryColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Top Products
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Products Purchased',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._getTopProducts(quotes).map((product) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(product['name'] as String),
                      trailing: Text(
                        '${product['count']} units',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.client.notes != null && widget.client.notes!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.client.notes!),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No notes added yet', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Customer Since
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Customer Since'),
              subtitle: Text(dateFormatter.format(widget.client.createdAt)),
            ),
          ),

          if (widget.client.updatedAt != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.update),
                title: const Text('Last Updated'),
                subtitle: Text(dateFormatter.format(widget.client.updatedAt!)),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _calculateMonthlySales(List<Quote> quotes) {
    final Map<String, double> monthlySales = {};

    for (final quote in quotes) {
      final monthKey = DateFormat('MMM').format(quote.createdAt);
      monthlySales[monthKey] = (monthlySales[monthKey] ?? 0) + quote.total;
    }

    // Get last 6 months
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM').format(month);
      result.add({
        'month': monthKey,
        'sales': monthlySales[monthKey] ?? 0,
      });
    }

    return result;
  }

  List<Map<String, dynamic>> _getTopProducts(List<Quote> quotes) {
    final Map<String, int> productCounts = {};
    final Map<String, String> productNames = {};

    for (final quote in quotes) {
      for (final item in quote.items) {
        final product = item.product;
        if (product != null) {
          final sku = product.sku ?? product.model;
          productCounts[sku] = (productCounts[sku] ?? 0) + item.quantity;
          productNames[sku] = product.displayName;
        }
      }
    }

    final sortedProducts = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedProducts.take(5).map((entry) {
      return {
        'name': productNames[entry.key] ?? entry.key,
        'count': entry.value,
      };
    }).toList();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}