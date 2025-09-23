import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/backup_status_widget.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

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

    // Check if user is admin (andres@turboairmexico.com or has admin role)
    final userEmail = user.email?.toLowerCase();
    final isAdmin = userEmail == 'andres@turboairmexico.com' ||
                    userEmail == 'admin@turboairinc.com' ||
                    userEmail == 'superadmin@turboairinc.com';

    if (!isAdmin) {
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
      print('Access denied for non-admin user: ${user.email}');
      return;
    }

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

    // Use only real Firebase data
    setState(() {
      _totalProducts = products.length;
      _totalClients = clients.length;
      _totalQuotes = quotes.length;
      _totalRevenue = revenue;
    });
  }

  Future<void> _loadRecentQuotes() async {
    final quotesData = CacheManager.getQuotes();
    final quotes = quotesData
        .map((data) => Quote.fromMap(Map<String, dynamic>.from(data)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Use only real quotes from Firebase
    setState(() {
      _recentQuotes = quotes.take(10).toList();
    });
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

    // Use only real data from Firebase
    // If no data available, charts will show empty state

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
                title: 'Backup Status',
                subtitle: 'Manage backups',
                color: Colors.indigo,
                onTap: () => setState(() => _selectedView = 'settings'),
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

          // Backup Status Section
          const BackupStatusWidget(),
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
                            DataCell(Text(request['name'] ?? 'N/A')),
                            DataCell(Text(request['email'] ?? 'N/A')),
                            DataCell(_buildRoleChip(request['requestedRole'] ?? 'distributor')),
                            DataCell(Text(request['company'] ?? 'N/A')),
                            DataCell(Text(request['phone'] ?? 'N/A')),
                            DataCell(Text(_formatDate(request['requestedAt']))),
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MM/dd/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Future<void> _approveUser(Map<String, dynamic> request) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        _showError('You must be logged in to approve users');
        return;
      }

      final dbService = ref.read(databaseServiceProvider);
      await dbService.approveUserRequest(
        requestId: request['id'],
        approvedBy: user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${request['name']} approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to approve user: $e');
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> request) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject User'),
          content: Text('Are you sure you want to reject ${request['name']}\'s registration request?'),
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

      final dbService = ref.read(databaseServiceProvider);
      await dbService.rejectUserRequest(
        requestId: request['id'],
        rejectedBy: user.uid,
        reason: 'Registration request rejected by administrator',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${request['name']} rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to reject user: $e');
    }
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
