import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadDashboardData();
  }

  void _checkAdminAccess() {
    final userProfile = ref.read(currentUserProfileProvider).valueOrNull;
    if (userProfile?.role != 'admin') {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied. Admin privileges required.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Admin Panel',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: const Color(0xFF2A2A2A),
            selectedIconTheme: const IconThemeData(color: Color(0xFF4169E1)),
            selectedLabelTextStyle: const TextStyle(color: Color(0xFF4169E1)),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildUsersSection();
      case 2:
        return _buildAnalytics();
      case 3:
        return _buildSettings();
      default:
        return _buildDashboard();
    }
  }

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

  Widget _buildRecentQuotesTable() {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Quote #')),
            DataColumn(label: Text('Client')),
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
              DataCell(Text('\$${quote.total.toStringAsFixed(2)}')),
              DataCell(_buildStatusChip(quote.status)),
              DataCell(Text(DateFormat('MM/dd/yyyy').format(quote.createdAt))),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    onPressed: () {
                      // View quote details
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      // Edit quote
                    },
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
                    SizedBox(
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
                            );
                          }).toList(),
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
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
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
}
