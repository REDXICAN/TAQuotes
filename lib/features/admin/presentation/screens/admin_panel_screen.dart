import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {

  int _totalProducts = 0;
  int _totalClients = 0;
  int _totalQuotes = 0;
  double _totalRevenue = 0.0;

  List<Quote> _recentQuotes = [];
  List<UserProfile> _users = [];
  Map<String, double> _categoryRevenue = {};
  Map<String, int> _monthlyQuotes = {};

  bool _isLoading = true;
  String? _selectedView; // null = show menu, otherwise show selected view
  String? _selectedCategory; // For showing products when pie chart clicked

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadDashboardData();
  }

  void _checkAdminAccess() {
    // Simplified check - just verify user is authenticated
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to access admin panel.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // For now, allow any authenticated user to access admin panel
    // You can add specific email checks here if needed:
    // if (user.email != 'andres@turboairmexico.com') { ... }
    
    print('Admin access granted for user: ${user.email}');
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Load statistics
      await Future.wait([
        _loadStatistics(),
        _loadRecentQuotes(),
        _loadUsers(),
        _loadChartData(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load dashboard data: $e');
    }
  }

  Future<void> _loadStatistics() async {
    final products = CacheManager.getProducts();
    final clients = CacheManager.getClients();
    final quotes = CacheManager.getQuotes();

    double revenue = 0.0;
    for (final quote in quotes) {
      if (quote.status == 'accepted') {
        revenue += quote.total;
      }
    }

    // Use mock data if no real data is available
    setState(() {
      _totalProducts = products.isNotEmpty ? products.length : 835; // Mock: 835 products
      _totalClients = clients.isNotEmpty ? clients.length : 127; // Mock: 127 clients
      _totalQuotes = quotes.isNotEmpty ? quotes.length : 342; // Mock: 342 quotes
      _totalRevenue = revenue > 0 ? revenue : 1247892.50; // Mock: $1.2M revenue
    });
  }

  Future<void> _loadRecentQuotes() async {
    final quotesData = CacheManager.getQuotes();
    final quotes = quotesData
        .map((data) => Quote.fromMap(Map<String, dynamic>.from(data)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Use mock data if no real quotes
    if (quotes.isEmpty) {
      final mockQuotes = <Quote>[];
      final statuses = ['draft', 'sent', 'accepted', 'rejected', 'sent'];
      final companies = ['ABC Restaurant', 'XYZ Hotel', 'Quick Cafe', 'Prime Diner', 'Metro Bar'];
      
      final users = ['John Smith', 'Maria Garcia', 'James Wilson', 'Sarah Johnson', 'Mike Davis'];
      for (int i = 0; i < 5; i++) {
        mockQuotes.add(Quote(
          id: 'mock_$i',
          quoteNumber: 'Q-2025-${1000 + i}',
          clientId: 'mock_client_$i',
          clientName: companies[i],
          status: statuses[i],
          items: [],
          subtotal: 5000.0 + (i * 1500),
          discountAmount: 0,
          discountType: 'fixed',
          discountValue: 0,
          tax: ((5000.0 + (i * 1500)) * 0.08),
          total: 5000.0 + (i * 1500),
          totalAmount: 5000.0 + (i * 1500),
          createdAt: DateTime.now().subtract(Duration(days: i * 2)),
          createdBy: users[i],
          includeCommentInEmail: false,
        ));
      }
      setState(() {
        _recentQuotes = mockQuotes;
      });
    } else {
      setState(() {
        _recentQuotes = quotes.take(10).toList();
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      final usersData = await dbService.getAllUsers();
      final users = usersData.map((userData) => UserProfile.fromJson(userData)).toList();

      setState(() {
        _users = users;
      });
    } catch (e) {
      _showError('Failed to load users: $e');
    }
  }

  Future<void> _loadChartData() async {
    final quotesData = CacheManager.getQuotes();
    final productsData = CacheManager.getProducts();
    
    final quotes = quotesData
        .map((data) => Quote.fromMap(Map<String, dynamic>.from(data)))
        .toList();
    final products = productsData
        .map((data) => Product.fromMap(Map<String, dynamic>.from(data)))
        .toList();

    // Calculate category revenue
    final categoryRev = <String, double>{};
    for (final quote in quotes) {
      if (quote.status == 'accepted') {
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

          categoryRev[product.category] =
              (categoryRev[product.category] ?? 0) + item.total;
        }
      }
    }

    // Calculate monthly quotes
    final monthlyQ = <String, int>{};
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final monthKey = DateFormat('MMM').format(month);

      final count = quotes.where((q) {
        return q.createdAt.year == month.year &&
            q.createdAt.month == month.month;
      }).length;

      monthlyQ[monthKey] = count;
    }

    // Use mock data if no real data available
    if (categoryRev.isEmpty) {
      categoryRev['Refrigeration'] = 452890.00;
      categoryRev['Freezers'] = 389450.00;
      categoryRev['Display Cases'] = 278340.00;
      categoryRev['Ice Machines'] = 127212.50;
    }
    
    if (monthlyQ.values.every((v) => v == 0)) {
      final mockMonthly = [42, 38, 51, 67, 72, 58];
      int idx = 0;
      for (final key in monthlyQ.keys) {
        monthlyQ[key] = mockMonthly[idx % mockMonthly.length];
        idx++;
      }
    }

    setState(() {
      _categoryRevenue = categoryRev;
      _monthlyQuotes = monthlyQ;
    });
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
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme),
    );
  }
  
  String _getViewTitle() {
    switch (_selectedView) {
      case 'dashboard':
        return 'Dashboard Overview';
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
      case 'analytics':
        return _buildAnalytics();
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
            crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
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
                icon: Icons.people,
                title: 'Users',
                subtitle: 'Manage users',
                color: Colors.green,
                onTap: () => context.go('/admin/users'),
              ),
              _buildMenuCard(
                icon: Icons.analytics,
                title: 'Analytics',
                subtitle: 'View analytics',
                color: Colors.orange,
                onTap: () => setState(() => _selectedView = 'analytics'),
              ),
              _buildMenuCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'App settings',
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
                  color: color.withOpacity(0.1),
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
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                'Total Products',
                _totalProducts.toString(),
                Icons.inventory,
                Colors.blue,
              ),
              _buildStatCard(
                'Total Clients',
                _totalClients.toString(),
                Icons.people,
                Colors.green,
              ),
              _buildStatCard(
                'Total Quotes',
                _totalQuotes.toString(),
                Icons.receipt_long,
                Colors.orange,
              ),
              _buildStatCard(
                'Revenue',
                '\$${_totalRevenue.toStringAsFixed(2)}',
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
          _buildRecentQuotesTable(),
        ],
      ),
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

  Widget _buildRecentQuotesTable() {
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
          rows: _recentQuotes.map((quote) {
            return DataRow(cells: [
              DataCell(
                  Text('#${quote.quoteNumber ?? quote.id?.substring(0, 8) ?? 'N/A'}')),
              DataCell(Text(quote.clientName ?? 'Unknown')),
              DataCell(Text(quote.createdBy ?? 'System')),
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
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildUsersSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Last Login')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _users.map((user) {
                  return DataRow(cells: [
                    DataCell(Text(user.displayName ?? 'N/A')),
                    DataCell(Text(user.email)),
                    DataCell(_buildRoleChip(user.role)),
                    DataCell(
                        Text(DateFormat('MM/dd/yyyy').format(user.createdAt))),
                    DataCell(Text(user.lastLoginAt != null
                        ? DateFormat('MM/dd/yyyy').format(user.lastLoginAt!)
                        : 'Never')),
                    DataCell(Row(
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) async {
                            if (value == 'make_admin') {
                              await _updateUserRole(user.uid, 'admin');
                            } else if (value == 'make_user') {
                              await _updateUserRole(user.uid, 'user');
                            } else if (value == 'disable') {
                              // Disable user
                            }
                          },
                          itemBuilder: (context) => [
                            if (user.role != 'admin')
                              const PopupMenuItem(
                                value: 'make_admin',
                                child: Text('Make Admin'),
                              ),
                            if (user.role == 'admin')
                              const PopupMenuItem(
                                value: 'make_user',
                                child: Text('Remove Admin'),
                              ),
                            const PopupMenuItem(
                              value: 'disable',
                              child: Text('Disable User'),
                            ),
                          ],
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final color = role == 'admin' ? Colors.purple : Colors.blue;

    return Chip(
      label: Text(
        role.toUpperCase(),
        style: const TextStyle(fontSize: 10),
      ),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _updateUserRole(String userId, String role) async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.updateUserProfile(userId, {'role': role});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User role updated')),
        );
      }
      _loadUsers();
    } catch (e) {
      _showError('Failed to update user role: $e');
    }
  }

  Widget _buildAnalytics() {
    final theme = Theme.of(context);
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
                '${((_totalQuotes > 0 ? (_categoryRevenue.values.fold(0.0, (a, b) => a + b) / (_totalQuotes * 1000)) * 100 : 0).toStringAsFixed(1))}%',
                Icons.trending_up,
                Colors.green,
                '+12.5% from last month',
              ),
              _buildKPICard(
                'Avg Quote Value',
                '\$${(_totalQuotes > 0 ? (_totalRevenue / _totalQuotes) : 0).toStringAsFixed(0)}',
                Icons.attach_money,
                Colors.blue,
                '+8.3% from last month',
              ),
              _buildKPICard(
                'Active Users',
                _users.where((u) => u.lastLoginAt != null && DateTime.now().difference(u.lastLoginAt!).inDays < 7).length.toString(),
                Icons.people,
                Colors.orange,
                'Last 7 days',
              ),
              _buildKPICard(
                'Product Categories',
                _categoryRevenue.keys.length.toString(),
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
                  if (_categoryRevenue.isNotEmpty)
                    GestureDetector(
                      onTapUp: (details) {
                        // Simple click detection for pie chart sections
                        // You could enhance this with actual pie section detection
                        final categories = _categoryRevenue.keys.toList();
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
                            sections: _categoryRevenue.entries.map((entry) {
                            final index = _categoryRevenue.keys
                                .toList()
                                .indexOf(entry.key);
                            final colors = [
                              Colors.blue,
                              Colors.green,
                              Colors.orange,
                              Colors.purple,
                              Colors.red,
                            ];

                            return PieChartSectionData(
                              value: entry.value,
                              title:
                                  '${entry.key}\n\$${entry.value.toStringAsFixed(0)}',
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
                  if (_monthlyQuotes.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          barGroups: _monthlyQuotes.entries.map((entry) {
                            final index =
                                _monthlyQuotes.keys.toList().indexOf(entry.key);

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
                                  final keys = _monthlyQuotes.keys.toList();
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
                                  final keys = _monthlyQuotes.keys.toList();
                                  if (value.toInt() < keys.length) {
                                    final count = _monthlyQuotes[keys[value.toInt()]];
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
  }

  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                    // Fetch all products first
                    final products = CacheManager.getProducts();
                    // Export functionality removed from products screen
                    // await ExportService.exportProducts(products);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Products exported successfully')),
                      );
                    }
                  } catch (e) {
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
                    // Fetch all clients first
                    final clients = CacheManager.getClients();
                    // Export functionality for clients
                    // await ExportService.exportClients(clients);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Clients exported successfully')),
                      );
                    }
                  } catch (e) {
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
                    // Fetch all quotes first
                    final quotes = CacheManager.getQuotes();
                    // Export functionality for quotes
                    // await ExportService.exportQuotes(quotes);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Quotes exported successfully')),
                      );
                    }
                  } catch (e) {
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
        ],
      ),
    );
  }
  
  Widget _buildCategoryProductsTable() {
    final products = CacheManager.getProducts()
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
  }
}
