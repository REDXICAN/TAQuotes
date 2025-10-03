import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/models/user_approval_request.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/backup_status_widget.dart';
import '../widgets/enhanced_backup_widget.dart';
import '../widgets/delete_product_lines_widget.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../../core/services/rbac_service.dart';
import '../../../../core/services/app_logger.dart';
import '../widgets/user_approvals_widget.dart' show pendingUserApprovalsProvider;
// import '../widgets/mock_analytics_generator_widget.dart'; // Removed - no longer needed
import '../widgets/spare_parts_import_widget.dart';
import '../widgets/comprehensive_data_populator.dart';
import '../widgets/tracking_import_widget.dart';
import '../../../../core/services/hybrid_database_service.dart';
import '../../../settings/presentation/screens/app_settings_screen.dart';

// Admin Database Service Provider (HybridDatabaseService)
final adminDatabaseServiceProvider = Provider<HybridDatabaseService>((ref) {
  return HybridDatabaseService();
});

// Admin Dashboard Providers
final adminDashboardProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final dbService = ref.watch(adminDatabaseServiceProvider);

  // Helper function to fetch all dashboard data
  Future<Map<String, dynamic>> fetchDashboardData() async {
    try {
      // Fetch all required data in parallel
      final results = await Future.wait([
        dbService.getTotalProducts(),
        dbService.getTotalClients(),
        dbService.getTotalQuotes(),
        dbService.getAllUsersOnce(),
      ]);

      final totalProducts = results[0] as int;
      final totalClients = results[1] as int;
      final totalQuotes = results[2] as int;
      final users = (results[3] as List<Map<String, dynamic>>).map((userData) => UserProfile.fromJson(userData)).toList();

      // Fetch real data from Firebase
      final quotesData = await dbService.getAllQuotesOnce();
      final productsData = await dbService.getAllProductsOnce();

      final quotes = quotesData.map((q) => Quote.fromMap(Map<String, dynamic>.from(q))).toList();
      final products = productsData.map((p) => Product.fromMap(Map<String, dynamic>.from(p))).toList();

      double totalRevenue = 0.0;
      final categoryRevenue = <String, double>{};

      for (final quote in quotes) {
        if (quote.status == 'accepted') {
          totalRevenue += quote.total;
          for (final item in quote.items) {
            final product = products.firstWhere(
              (p) => p.id == item.productId,
              orElse: () => Product(
                id: '',
                model: '',
                displayName: '',
                name: '',
                description: '',
                category: 'Other',
                price: 0,
                stock: 0,
                createdAt: DateTime.now(),
              ),
            );
            categoryRevenue[product.category] = (categoryRevenue[product.category] ?? 0) + item.total;
          }
        }
      }

      // Calculate monthly quotes
      final monthlyQuotes = <String, int>{};
      final now = DateTime.now();
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        final monthKey = DateFormat('MMM').format(month);
        final count = quotes.where((q) => q.createdAt.year == month.year && q.createdAt.month == month.month).length;
        monthlyQuotes[monthKey] = count;
      }

      final recentQuotes = quotes..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return {
        'totalProducts': totalProducts,
        'totalClients': totalClients,
        'totalQuotes': totalQuotes,
        'totalRevenue': totalRevenue,
        'users': users,
        'products': products,
        'quotes': quotes,
        'recentQuotes': recentQuotes.take(10).toList(),
        'categoryRevenue': categoryRevenue,
        'monthlyQuotes': monthlyQuotes,
      };
    } catch (e) {
      AppLogger.error('Error fetching dashboard data', error: e);
      rethrow;
    }
  }

  // Initial load
  yield await fetchDashboardData();

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await fetchDashboardData();
    } catch (e) {
      AppLogger.error('Error in dashboard auto-refresh', error: e);
      // Continue with previous data on error
    }
  }
});

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  String? _selectedView; // null = show menu, otherwise show selected view
  String? _selectedCategory; // For showing products when pie chart clicked

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    // Check if user is authenticated
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      // User not logged in
      Future.microtask(() {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to access admin panel.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    // Check if user has admin access using RBAC
    final hasAdminAccess = await RBACService.hasPermission('access_admin');

    if (!hasAdminAccess) {
      // Not admin - BLOCK ACCESS
      Future.microtask(() {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access Denied: Admin privileges required.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
      AppLogger.warning('Access denied to Admin Panel', data: {'user_email': user.email, 'reason': 'insufficient_privileges'});
      return;
    }

    AppLogger.info('Admin Panel access granted', data: {'user_email': user.email});
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWithClient(
        title: _selectedView != null ? _getViewTitle() : 'Admin Panel',
        leading: _selectedView != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedView = null),
                tooltip: 'Back to menu',
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminDashboardProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }
  
  String _getViewTitle() {
    switch (_selectedView) {
      case 'dashboard':
        return 'Dashboard Overview';
      case 'pending_users':
        return 'Pending User Approvals';
      case 'analytics':
        return 'Analytics';
      case 'settings':
        return 'Settings';
      default:
        return 'Admin Panel';
    }
  }
  
  Widget _buildBody(ThemeData theme) {
    if (_selectedView == null) {
      return _buildCardMenu(theme);
    }
    
    switch (_selectedView) {
      case 'dashboard':
        return _buildDashboard();
      case 'pending_users':
        return _buildPendingUsers();
      case 'analytics':
        return _buildAnalytics();
      case 'backup':
        return _buildBackupManagement();
      case 'settings':
        return _buildSettings();
      default:
        return _buildCardMenu(theme);
    }
  }

  Widget _buildCardMenu(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Menu Cards - Admin Functions only
          Text(
            'Admin Functions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Menu Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildMenuCard(
                icon: Icons.dashboard,
                title: 'Dashboard',
                subtitle: 'View overview',
                color: Colors.blue,
                onTap: () => setState(() => _selectedView = 'dashboard'),
              ),
              _buildMenuCard(
                icon: Icons.bar_chart,
                title: 'Monitoring',
                subtitle: 'Sales, inventory & analytics',
                color: Colors.purple,
                onTap: () => context.go('/admin/monitoring'),
              ),
              _buildMenuCard(
                icon: Icons.people,
                title: 'Users',
                subtitle: 'Manage users',
                color: Colors.green,
                onTap: () => context.go('/admin/users'),
              ),
              _buildMenuCard(
                icon: Icons.pending_actions,
                title: 'Pending Users',
                subtitle: 'Review approvals',
                color: Colors.amber,
                onTap: () => setState(() => _selectedView = 'pending_users'),
              ),
              _buildMenuCard(
                icon: Icons.analytics,
                title: 'Analytics',
                subtitle: 'View analytics',
                color: Colors.orange,
                onTap: () => setState(() => _selectedView = 'analytics'),
              ),
              _buildMenuCard(
                icon: Icons.error_outline,
                title: 'Error Monitoring',
                subtitle: 'View system errors',
                color: Colors.red,
                onTap: () => context.go('/admin/errors'),
              ),
              _buildMenuCard(
                icon: Icons.backup,
                title: 'Backup Management',
                subtitle: 'View and manage backups',
                color: Colors.indigo,
                onTap: () => setState(() => _selectedView = 'backup'),
              ),
              _buildMenuCard(
                icon: Icons.storage,
                title: 'Database Management',
                subtitle: 'Manage database',
                color: Colors.teal,
                onTap: () => context.go('/admin/database'),
              ),
              _buildMenuCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'App configuration & permissions',
                color: Colors.grey,
                onTap: () => setState(() => _selectedView = 'settings'),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Removed stats overview - this should be in home screen

  Widget _buildDashboard() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboardAsync = ref.watch(adminDashboardProvider);

        return dashboardAsync.when(
          data: (dashboardData) {
            final totalProducts = dashboardData['totalProducts'] as int;
            final totalClients = dashboardData['totalClients'] as int;
            final totalQuotes = dashboardData['totalQuotes'] as int;
            final totalRevenue = dashboardData['totalRevenue'] as double;
            final recentQuotes = dashboardData['recentQuotes'] as List<Quote>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Statistics cards
                  GridView.count(
                    crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                        'Total Products',
                        totalProducts.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Total Clients',
                        totalClients.toString(),
                        Icons.people,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Total Quotes',
                        totalQuotes.toString(),
                        Icons.receipt_long,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Revenue',
                        '\$${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Recent quotes
                  const Text(
                    'Recent Quotes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentQuotesTable(recentQuotes),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load dashboard data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(adminDashboardProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildKPICard(
    String title, 
    String value, 
    IconData icon, 
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 24, color: color),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentQuotesTable(List<Quote> recentQuotes) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Quote #')),
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Created By')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: recentQuotes.map((quote) {
            return DataRow(cells: [
              DataCell(
                  Text('#${quote.quoteNumber ?? (quote.id != null && quote.id!.length >= 8 ? quote.id!.substring(0, 8) : quote.id ?? 'N/A')}')),
              DataCell(Text(quote.clientName ?? 'Unknown')),
              DataCell(Text(quote.createdBy)),
              DataCell(Text('\$${quote.total.toStringAsFixed(2)}')),
              DataCell(_buildStatusChip(quote.status)),
              DataCell(Text(DateFormat('MM/dd/yyyy').format(quote.createdAt))),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    onPressed: () {
                      if (quote.id != null) {
                        context.go('/quotes/${quote.id}');
                      }
                    },
                    tooltip: 'View Quote',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      if (quote.id != null) {
                        context.go('/quotes/${quote.id}?edit=true');
                      }
                    },
                    tooltip: 'Edit Quote',
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'draft':
        color = Colors.grey;
        break;
      case 'sent':
        color = Colors.blue;
        break;
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 10),
      ),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color),
      padding: EdgeInsets.zero,
    );
  }


  Widget _buildRoleChip(String role) {
    final color = role == 'admin' ? Colors.purple : Colors.blue;

    return Chip(
      label: Text(
        role.toUpperCase(),
        style: const TextStyle(fontSize: 10),
      ),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color),
      padding: EdgeInsets.zero,
    );
  }


  Widget _buildAnalytics() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboardAsync = ref.watch(adminDashboardProvider);

        return dashboardAsync.when(
          data: (dashboardData) {
            final totalQuotes = dashboardData['totalQuotes'] as int;
            final totalRevenue = dashboardData['totalRevenue'] as double;
            final users = dashboardData['users'] as List<UserProfile>;
            final quotes = dashboardData['quotes'] as List<Quote>;
            final categoryRevenue = dashboardData['categoryRevenue'] as Map<String, double>;
            final monthlyQuotes = dashboardData['monthlyQuotes'] as Map<String, int>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analytics',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // KPI Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildKPICard(
                        'Conversion Rate',
                        '${(() {
                          if (totalQuotes == 0) return '0.0';
                          final acceptedQuotes = quotes.where((q) => q.status == 'accepted').length;
                          return ((acceptedQuotes / totalQuotes) * 100).toStringAsFixed(1);
                        })()}%',
                        Icons.trending_up,
                        Colors.green,
                        'Accepted / Total quotes',
                      ),
                      _buildKPICard(
                        'Avg Quote Value',
                        '\$${(totalQuotes > 0 ? (totalRevenue / totalQuotes) : 0).toStringAsFixed(0)}',
                        Icons.attach_money,
                        Colors.blue,
                        '+8.3% from last month',
                      ),
                      _buildKPICard(
                        'Active Users',
                        '${(() {
                          try {
                            final now = DateTime.now();
                            return users.where((u) {
                              if (u.lastLoginAt == null) return false;
                              try {
                                return now.difference(u.lastLoginAt!).inDays < 7;
                              } catch (e) {
                                return false;
                              }
                            }).length;
                          } catch (e) {
                            return 0;
                          }
                        })()}',
                        Icons.people,
                        Colors.orange,
                        'Active in last 7 days',
                      ),
                      _buildKPICard(
                        'Product Categories',
                        categoryRevenue.keys.length.toString(),
                        Icons.category,
                        Colors.purple,
                        'Generating revenue',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Revenue by category chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revenue by Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (categoryRevenue.isNotEmpty)
                            GestureDetector(
                              onTapUp: (details) {
                                final categories = categoryRevenue.keys.toList();
                                if (categories.isNotEmpty) {
                                  setState(() {
                                    _selectedCategory = _selectedCategory == categories.first
                                        ? null
                                        : categories.first;
                                  });
                                }
                              },
                              child: SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: categoryRevenue.entries.map((entry) {
                                      final index = categoryRevenue.keys.toList().indexOf(entry.key);
                                      final colors = [
                                        Colors.blue,
                                        Colors.green,
                                        Colors.orange,
                                        Colors.purple,
                                        Colors.red,
                                      ];

                                      return PieChartSectionData(
                                        value: entry.value,
                                        title: '${entry.key}\n\$${entry.value.toStringAsFixed(0)}',
                                        color: colors[index % colors.length],
                                        radius: 100,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        badgeWidget: null,
                                        showTitle: true,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            )
                          else
                            const Center(
                              child: Text('No revenue data available'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Show product table when category is selected
                  if (_selectedCategory != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Products in $_selectedCategory',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() => _selectedCategory = null),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildCategoryProductsTable(),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Monthly quotes chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Quotes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (monthlyQuotes.isNotEmpty)
                            SizedBox(
                              height: 200,
                              child: BarChart(
                                BarChartData(
                                  barGroups: monthlyQuotes.entries.map((entry) {
                                    final index = monthlyQuotes.keys.toList().indexOf(entry.key);

                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value.toDouble(),
                                          color: const Color(0xFF4169E1),
                                          width: 30,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          backDrawRodData: BackgroundBarChartRodData(
                                            show: true,
                                            toY: 100,
                                            color: Colors.grey.shade200,
                                          ),
                                          rodStackItems: [
                                            BarChartRodStackItem(
                                              0,
                                              entry.value.toDouble(),
                                              const Color(0xFF4169E1),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final keys = monthlyQuotes.keys.toList();
                                          if (value.toInt() < keys.length) {
                                            return Text(keys[value.toInt()]);
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          return Text(value.toInt().toString());
                                        },
                                      ),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final keys = monthlyQuotes.keys.toList();
                                          if (value.toInt() < keys.length) {
                                            final count = monthlyQuotes[keys[value.toInt()]];
                                            return Text(
                                              count.toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const Center(
                              child: Text('No quote data available'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load analytics data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(adminDashboardProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettings() {
    // Navigate to the new settings screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AppSettingsScreen(),
        ),
      );
      // Reset view to menu after navigation
      setState(() => _selectedView = null);
    });

    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildBackupManagement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Backup Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Enhanced Backup Widget - Full database export/import
          const EnhancedBackupWidget(),
          const SizedBox(height: 24),

          // Backup Status Section
          const BackupStatusWidget(),
          const SizedBox(height: 24),

          // Comprehensive Mock Data Populator
          const ComprehensiveDataPopulatorWidget(),
          const SizedBox(height: 24),

          // Spare Parts Import
          const SparePartsImportWidget(),
          const SizedBox(height: 24),

          // Shipment Tracking Import
          const TrackingImportWidget(),
          const SizedBox(height: 24),

          // Delete Product Lines Widget
          const DeleteProductLinesWidget(),
          const SizedBox(height: 24),

          // Export data
          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Products'),
              subtitle: const Text('Download product data as CSV or Excel'),
              trailing: PopupMenuButton<String>(
                onSelected: (format) async {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    // Fetch all products first
                    final dbService = ref.read(adminDatabaseServiceProvider);
                    final productsData = await dbService.getAllProductsOnce();
                    final products = productsData
                        .map((p) => Product.fromMap(Map<String, dynamic>.from(p)))
                        .toList();

                    // Generate Excel file
                    final bytes = await ExportService.generateProductsExcel(products);

                    // Download the file
                    final filename = 'products_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
                    await DownloadHelper.downloadFile(
                      bytes: bytes,
                      filename: filename,
                      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    );

                    // Close loading dialog
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Products exported successfully (${products.length} items)'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    // Close loading dialog if error
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    _showError('Export failed: $e');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'csv', child: Text('Export as CSV')),
                  const PopupMenuItem(
                      value: 'excel', child: Text('Export as Excel')),
                ],
                child: const Icon(Icons.more_vert),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Clients'),
              subtitle: const Text('Download client data as CSV or Excel'),
              trailing: PopupMenuButton<String>(
                onSelected: (format) async {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    // Fetch all clients first
                    final dbService = ref.read(adminDatabaseServiceProvider);
                    final clientsData = await dbService.getAllClientsOnce();
                    final clients = clientsData
                        .map((c) => Client.fromMap(Map<String, dynamic>.from(c)))
                        .toList();

                    // Generate Excel file
                    final bytes = await ExportService.generateClientsExcel(clients);

                    // Download the file
                    final filename = 'clients_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
                    await DownloadHelper.downloadFile(
                      bytes: bytes,
                      filename: filename,
                      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    );

                    // Close loading dialog
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Clients exported successfully (${clients.length} items)'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    // Close loading dialog if error
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    _showError('Export failed: $e');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'csv', child: Text('Export as CSV')),
                  const PopupMenuItem(
                      value: 'excel', child: Text('Export as Excel')),
                ],
                child: const Icon(Icons.more_vert),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Quotes'),
              subtitle: const Text('Download quote data as CSV or Excel'),
              trailing: PopupMenuButton<String>(
                onSelected: (format) async {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    // Fetch all quotes first
                    final dbService = ref.read(adminDatabaseServiceProvider);
                    final quotesData = await dbService.getAllQuotesOnce();

                    // Generate Excel file
                    final bytes = await ExportService.generateQuotesExcel(quotesData);

                    // Download the file
                    final filename = 'quotes_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
                    await DownloadHelper.downloadFile(
                      bytes: bytes,
                      filename: filename,
                      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    );

                    // Close loading dialog
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Quotes exported successfully (${quotesData.length} items)'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    // Close loading dialog if error
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    _showError('Export failed: $e');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'csv', child: Text('Export as CSV')),
                  const PopupMenuItem(
                      value: 'excel', child: Text('Export as Excel')),
                ],
                child: const Icon(Icons.more_vert),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Cache management
          Card(
            child: ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Clear Cache'),
              subtitle: const Text('Remove all cached data'),
              trailing: ElevatedButton(
                onPressed: () async {
                  await CacheManager.clearAllCache();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared')),
                    );
                  }
                },
                child: const Text('Clear'),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPendingUsers() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending User Approvals',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Review and approve or reject user registration requests',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Pending users table
          Consumer(
            builder: (context, ref, child) {
              final pendingUsersAsync = ref.watch(pendingUserApprovalsProvider);

              return pendingUsersAsync.when(
                data: (pendingUsers) {
                  if (pendingUsers.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No Pending Approvals',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'All user registration requests have been processed.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Requested Role')),
                          DataColumn(label: Text('Company')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Requested At')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: pendingUsers.map((request) {
                          return DataRow(cells: [
                            DataCell(Text(request.name)),
                            DataCell(Text(request.email)),
                            DataCell(_buildRoleChip(request.requestedRole)),
                            DataCell(Text(request.company ?? 'N/A')),
                            DataCell(Text(request.phone ?? 'N/A')),
                            DataCell(Text(_formatDate(request.requestedAt.toIso8601String()))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _approveUser(request),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(100, 36),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _rejectUser(request),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reject'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(100, 36),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Error Loading Pending Users',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load pending user approvals: $error',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.refresh(pendingUserApprovalsProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      DateTime? date;

      // Handle Firebase timestamp integers
      if (dateValue is int) {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is double) {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue.toInt());
      } else if (dateValue is String) {
        // Try parsing as timestamp integer first
        final timestampInt = int.tryParse(dateValue);
        if (timestampInt != null) {
          date = DateTime.fromMillisecondsSinceEpoch(timestampInt);
        } else {
          // Try ISO format or other date string formats
          date = DateTime.parse(dateValue);
        }
      } else if (dateValue is DateTime) {
        date = dateValue;
      }

      if (date != null) {
        return DateFormat('MM/dd/yyyy HH:mm').format(date);
      }
    } catch (e) {
      // Log the error for debugging
      AppLogger.warning('Failed to format date "$dateValue"', error: e, category: LogCategory.data);
    }
    return 'Invalid Date';
  }

  Future<void> _approveUser(UserApprovalRequest request) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        _showError('You must be logged in to approve users');
        return;
      }

      final dbService = ref.read(adminDatabaseServiceProvider);
      await dbService.approveUserRequest(
        requestId: request.id,
        approvedBy: user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${request.name} approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to approve user: $e');
    }
  }

  Future<void> _rejectUser(UserApprovalRequest request) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject User'),
          content: Text('Are you sure you want to reject ${request.name}\'s registration request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final user = ref.read(currentUserProvider);
      if (user == null) {
        _showError('You must be logged in to reject users');
        return;
      }

      final dbService = ref.read(adminDatabaseServiceProvider);
      await dbService.rejectUserRequest(
        requestId: request.id,
        rejectedBy: user.uid,
        reason: 'Registration request rejected by administrator',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${request.name} rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to reject user: $e');
    }
  }

  Widget _buildCategoryProductsTable() {
    return Consumer(
      builder: (context, ref, child) {
        final dashboardAsync = ref.watch(adminDashboardProvider);

        return dashboardAsync.when(
          data: (dashboardData) {
            final allProducts = dashboardData['products'] as List<Product>? ?? [];
            final products = allProducts
                .where((p) => p.category == _selectedCategory)
                .toList();

            if (products.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No products in this category'),
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Model')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Stock')),
                ],
                rows: products.take(10).map((product) {
                  return DataRow(cells: [
                    DataCell(Text(product.sku ?? 'N/A')),
                    DataCell(Text(product.model)),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          product.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text('\$${product.price.toStringAsFixed(2)}')),
                    DataCell(Text(product.stock.toString())),
                  ]);
                }).toList(),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error loading products: $error'),
          ),
        );
      },
    );
  }


}
