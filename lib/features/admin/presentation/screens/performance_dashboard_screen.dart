// lib/features/admin/presentation/screens/performance_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/config/env_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/realtime_database_service.dart';

// User performance metrics model
class UserPerformanceMetrics {
  final String userId;
  final String email;
  final String displayName;
  final int totalQuotes;
  final int acceptedQuotes;
  final int pendingQuotes;
  final int rejectedQuotes;
  final double totalRevenue;
  final double averageQuoteValue;
  final double conversionRate;
  final int totalClients;
  final int newClientsThisMonth;
  final DateTime? lastActivity;
  final int quotesThisWeek;
  final int quotesThisMonth;
  final double revenueThisMonth;
  final Map<String, int> productsSold;
  final Map<String, double> categoryRevenue;
  final List<Quote> recentQuotes;
  final double averageResponseTime; // hours
  final int totalProducts;
  
  UserPerformanceMetrics({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.totalQuotes,
    required this.acceptedQuotes,
    required this.pendingQuotes,
    required this.rejectedQuotes,
    required this.totalRevenue,
    required this.averageQuoteValue,
    required this.conversionRate,
    required this.totalClients,
    required this.newClientsThisMonth,
    this.lastActivity,
    required this.quotesThisWeek,
    required this.quotesThisMonth,
    required this.revenueThisMonth,
    required this.productsSold,
    required this.categoryRevenue,
    required this.recentQuotes,
    required this.averageResponseTime,
    required this.totalProducts,
  });
}

// Provider for aggregating user performance data
final userPerformanceProvider = FutureProvider<List<UserPerformanceMetrics>>((ref) async {
  final database = FirebaseDatabase.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  
  // Check if user is admin
  if (currentUser?.email != EnvConfig.adminEmail) {
    return [];
  }
  
  try {
    // Get all users
    final usersSnapshot = await database.ref('users').get();
    if (!usersSnapshot.exists) return [];
    
    final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
    final List<UserPerformanceMetrics> metrics = [];
    
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    
    for (final entry in users.entries) {
      final userId = entry.key;
      final userData = Map<String, dynamic>.from(entry.value);
      
      // Get user's quotes
      final quotesSnapshot = await database.ref('quotes/$userId').get();
      final quotes = <Quote>[];
      
      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        for (final quoteEntry in quotesData.entries) {
          final quoteMap = Map<String, dynamic>.from(quoteEntry.value);
          quoteMap['id'] = quoteEntry.key;
          quotes.add(Quote.fromMap(quoteMap));
        }
      }
      
      // Get user's clients
      final clientsSnapshot = await database.ref('clients/$userId').get();
      int totalClients = 0;
      int newClientsThisMonth = 0;
      
      if (clientsSnapshot.exists) {
        final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);
        totalClients = clientsData.length;
        
        for (final clientEntry in clientsData.values) {
          final clientData = Map<String, dynamic>.from(clientEntry as Map);
          final createdAt = DateTime.parse(clientData['created_at'] ?? DateTime.now().toIso8601String());
          if (createdAt.isAfter(monthAgo)) {
            newClientsThisMonth++;
          }
        }
      }
      
      // Calculate metrics
      int acceptedQuotes = 0;
      int pendingQuotes = 0;
      int rejectedQuotes = 0;
      int quotesThisWeek = 0;
      int quotesThisMonth = 0;
      double totalRevenue = 0;
      double revenueThisMonth = 0;
      Map<String, int> productsSold = {};
      Map<String, double> categoryRevenue = {};
      List<DateTime> responseTimes = [];
      
      for (final quote in quotes) {
        // Status counts
        switch (quote.status.toLowerCase()) {
          case 'accepted':
          case 'closed':
          case 'sold':
            acceptedQuotes++;
            totalRevenue += quote.total;
            
            // Track products sold
            for (final item in quote.items) {
              final productName = item.productName ?? 'Unknown';
              productsSold[productName] = (productsSold[productName] ?? 0) + item.quantity;
              
              // Track category revenue
              final category = item.product?.category ?? 'Other';
              categoryRevenue[category] = (categoryRevenue[category] ?? 0) + item.total;
            }
            break;
          case 'pending':
          case 'sent':
            pendingQuotes++;
            break;
          case 'rejected':
          case 'expired':
            rejectedQuotes++;
            break;
        }
        
        // Time-based counts
        if (quote.createdAt.isAfter(weekAgo)) {
          quotesThisWeek++;
        }
        if (quote.createdAt.isAfter(monthAgo)) {
          quotesThisMonth++;
          if (quote.status.toLowerCase() == 'accepted' || 
              quote.status.toLowerCase() == 'closed' ||
              quote.status.toLowerCase() == 'sold') {
            revenueThisMonth += quote.total;
          }
        }
        
        // Calculate response time (using status change as proxy)
        if (quote.status != 'pending' && quote.status != 'draft') {
          // Assume 24 hour average response time for accepted quotes
          responseTimes.add(quote.createdAt.add(const Duration(hours: 24)));
        }
      }
      
      // Calculate averages
      final averageQuoteValue = quotes.isEmpty ? 0.0 : totalRevenue / acceptedQuotes.clamp(1, double.infinity);
      final conversionRate = quotes.isEmpty ? 0.0 : (acceptedQuotes / quotes.length) * 100;
      
      // Calculate average response time in hours
      double avgResponseTime = 0;
      if (responseTimes.isNotEmpty) {
        int totalHours = 0;
        for (int i = 0; i < responseTimes.length; i++) {
          if (i < quotes.length) {
            totalHours += responseTimes[i].difference(quotes[i].createdAt).inHours;
          }
        }
        avgResponseTime = totalHours / responseTimes.length;
      }
      
      // Sort quotes by date and take recent 5
      quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final recentQuotes = quotes.take(5).toList();
      
      // Count total products in quotes
      int totalProducts = 0;
      for (final quote in quotes) {
        totalProducts += quote.items.fold(0, (sum, item) => sum + item.quantity);
      }
      
      metrics.add(UserPerformanceMetrics(
        userId: userId,
        email: userData['email'] ?? 'Unknown',
        displayName: userData['displayName'] ?? userData['email'] ?? 'User',
        totalQuotes: quotes.length,
        acceptedQuotes: acceptedQuotes,
        pendingQuotes: pendingQuotes,
        rejectedQuotes: rejectedQuotes,
        totalRevenue: totalRevenue,
        averageQuoteValue: averageQuoteValue,
        conversionRate: conversionRate,
        totalClients: totalClients,
        newClientsThisMonth: newClientsThisMonth,
        lastActivity: userData['lastLoginAt'] != null 
            ? DateTime.parse(userData['lastLoginAt']) 
            : null,
        quotesThisWeek: quotesThisWeek,
        quotesThisMonth: quotesThisMonth,
        revenueThisMonth: revenueThisMonth,
        productsSold: productsSold,
        categoryRevenue: categoryRevenue,
        recentQuotes: recentQuotes,
        averageResponseTime: avgResponseTime,
        totalProducts: totalProducts,
      ));
    }
    
    // Sort by total revenue (best performers first)
    metrics.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    
    return metrics;
  } catch (e) {
    print('Error fetching performance metrics: $e');
    return [];
  }
});

class PerformanceDashboardScreen extends ConsumerStatefulWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  ConsumerState<PerformanceDashboardScreen> createState() => _PerformanceDashboardScreenState();
}

class _PerformanceDashboardScreenState extends ConsumerState<PerformanceDashboardScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'month';
  String _sortBy = 'revenue';
  UserPerformanceMetrics? _selectedUser;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final performanceAsync = ref.watch(userPerformanceProvider);
    final numberFormat = NumberFormat('#,###');
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final isMobile = ResponsiveHelper.isMobile(context);
    
    // Check if user is admin
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    if (currentUser?.email != EnvConfig.adminEmail) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Performance Dashboard'),
        ),
        body: const Center(
          child: Text('Access Denied: Admin privileges required'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Performance Dashboard'),
        centerTitle: true,
        actions: [
          // Period selector
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'quarter', child: Text('This Quarter')),
                DropdownMenuItem(value: 'year', child: Text('This Year')),
                DropdownMenuItem(value: 'all', child: Text('All Time')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPeriod = value!;
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userPerformanceProvider);
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: performanceAsync.when(
        data: (metrics) {
          if (metrics.isEmpty) {
            return const Center(
              child: Text('No performance data available'),
            );
          }
          
          return TabBarView(
            controller: _tabController,
            children: [
              // Overview Tab
              _buildOverviewTab(metrics, theme, numberFormat, currencyFormat, isMobile),
              
              // Users Tab
              _buildUsersTab(metrics, theme, numberFormat, currencyFormat, isMobile),
              
              // Analytics Tab
              _buildAnalyticsTab(metrics, theme, numberFormat, currencyFormat, isMobile),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading performance data: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userPerformanceProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOverviewTab(
    List<UserPerformanceMetrics> metrics,
    ThemeData theme,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
    bool isMobile,
  ) {
    // Calculate totals
    final totalRevenue = metrics.fold(0.0, (sum, m) => sum + m.totalRevenue);
    final totalQuotes = metrics.fold(0, (sum, m) => sum + m.totalQuotes);
    final totalClients = metrics.fold(0, (sum, m) => sum + m.totalClients);
    final avgConversion = metrics.isEmpty ? 0.0 : 
        metrics.fold(0.0, (sum, m) => sum + m.conversionRate) / metrics.length;
    
    // Get top performers
    final topByRevenue = [...metrics]..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final topByQuotes = [...metrics]..sort((a, b) => b.totalQuotes.compareTo(a.totalQuotes));
    final topByConversion = [...metrics]..sort((a, b) => b.conversionRate.compareTo(a.conversionRate));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company-wide KPIs
          Text(
            'Company Performance',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isMobile ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isMobile ? 1.5 : 1.8,
            children: [
              _buildKPICard(
                title: 'Total Revenue',
                value: currencyFormat.format(totalRevenue),
                icon: Icons.attach_money,
                color: Colors.green,
                theme: theme,
              ),
              _buildKPICard(
                title: 'Total Quotes',
                value: numberFormat.format(totalQuotes),
                icon: Icons.receipt_long,
                color: Colors.blue,
                theme: theme,
              ),
              _buildKPICard(
                title: 'Total Clients',
                value: numberFormat.format(totalClients),
                icon: Icons.people,
                color: Colors.orange,
                theme: theme,
              ),
              _buildKPICard(
                title: 'Avg Conversion',
                value: '${avgConversion.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: Colors.purple,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Top Performers
          Text(
            'Top Performers',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTopPerformerCard(
                  title: 'Highest Revenue',
                  user: topByRevenue.first,
                  metric: currencyFormat.format(topByRevenue.first.totalRevenue),
                  icon: Icons.monetization_on,
                  color: Colors.green,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16),
              if (!isMobile) ...[
                Expanded(
                  child: _buildTopPerformerCard(
                    title: 'Most Quotes',
                    user: topByQuotes.first,
                    metric: '${topByQuotes.first.totalQuotes} quotes',
                    icon: Icons.assignment,
                    color: Colors.blue,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTopPerformerCard(
                    title: 'Best Conversion',
                    user: topByConversion.first,
                    metric: '${topByConversion.first.conversionRate.toStringAsFixed(1)}%',
                    icon: Icons.star,
                    color: Colors.amber,
                    theme: theme,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          
          // Activity Timeline
          Text(
            'Recent Activity',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActivityTimeline(metrics, theme),
        ],
      ),
    );
  }
  
  Widget _buildUsersTab(
    List<UserPerformanceMetrics> metrics,
    ThemeData theme,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
    bool isMobile,
  ) {
    // Sort metrics based on selected criteria
    final sortedMetrics = [...metrics];
    switch (_sortBy) {
      case 'revenue':
        sortedMetrics.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
        break;
      case 'quotes':
        sortedMetrics.sort((a, b) => b.totalQuotes.compareTo(a.totalQuotes));
        break;
      case 'conversion':
        sortedMetrics.sort((a, b) => b.conversionRate.compareTo(a.conversionRate));
        break;
      case 'clients':
        sortedMetrics.sort((a, b) => b.totalClients.compareTo(a.totalClients));
        break;
    }
    
    return Column(
      children: [
        // Sort controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              const Text('Sort by:'),
              const SizedBox(width: 16),
              ...['revenue', 'quotes', 'conversion', 'clients'].map((sortOption) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getSortLabel(sortOption)),
                    selected: _sortBy == sortOption,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _sortBy = sortOption;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        
        // User list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedMetrics.length,
            itemBuilder: (context, index) {
              final user = sortedMetrics[index];
              return _buildUserCard(user, theme, numberFormat, currencyFormat, isMobile);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnalyticsTab(
    List<UserPerformanceMetrics> metrics,
    ThemeData theme,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
    bool isMobile,
  ) {
    // Aggregate data for charts
    final Map<String, double> categoryRevenue = {};
    final Map<String, int> productsSold = {};
    
    for (final user in metrics) {
      user.categoryRevenue.forEach((category, revenue) {
        categoryRevenue[category] = (categoryRevenue[category] ?? 0) + revenue;
      });
      user.productsSold.forEach((product, quantity) {
        productsSold[product] = (productsSold[product] ?? 0) + quantity;
      });
    }
    
    // Sort and get top items
    final topCategories = categoryRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topProducts = productsSold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue by Category
          Text(
            'Revenue by Category',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: topCategories.take(10).map((entry) {
                final maxRevenue = topCategories.first.value;
                final percentage = (entry.value / maxRevenue);
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currencyFormat.format(entry.value),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: theme.dividerColor,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          
          // Top Products
          Text(
            'Top Products Sold',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: topProducts.take(10).map((entry) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Text(
                      '${topProducts.indexOf(entry) + 1}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(entry.key),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.value} units',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          
          // User Performance Matrix
          Text(
            'Performance Matrix',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPerformanceMatrix(metrics, theme),
        ],
      ),
    );
  }
  
  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopPerformerCard({
    required String title,
    required UserPerformanceMetrics user,
    required String metric,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Text(
                  user.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metric,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserCard(
    UserPerformanceMetrics user,
    ThemeData theme,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
    bool isMobile,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedUser = _selectedUser == user ? null : user;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primaryColor,
                    child: Text(
                      user.displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                        if (user.lastActivity != null)
                          Text(
                            'Last active: ${_formatDate(user.lastActivity!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _selectedUser == user 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickStat(
                    label: 'Revenue',
                    value: currencyFormat.format(user.totalRevenue),
                    color: Colors.green,
                    theme: theme,
                  ),
                  _buildQuickStat(
                    label: 'Quotes',
                    value: numberFormat.format(user.totalQuotes),
                    color: Colors.blue,
                    theme: theme,
                  ),
                  _buildQuickStat(
                    label: 'Conversion',
                    value: '${user.conversionRate.toStringAsFixed(1)}%',
                    color: Colors.orange,
                    theme: theme,
                  ),
                  _buildQuickStat(
                    label: 'Clients',
                    value: numberFormat.format(user.totalClients),
                    color: Colors.purple,
                    theme: theme,
                  ),
                ],
              ),
              // Expanded details
              if (_selectedUser == user) ...[
                const Divider(height: 32),
                _buildExpandedUserDetails(user, theme, numberFormat, currencyFormat),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickStat({
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.disabledColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildExpandedUserDetails(
    UserPerformanceMetrics user,
    ThemeData theme,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Performance metrics
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(
                title: 'This Month',
                items: [
                  'Quotes: ${user.quotesThisMonth}',
                  'Revenue: ${currencyFormat.format(user.revenueThisMonth)}',
                  'New Clients: ${user.newClientsThisMonth}',
                ],
                theme: theme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDetailCard(
                title: 'Quote Status',
                items: [
                  'Accepted: ${user.acceptedQuotes}',
                  'Pending: ${user.pendingQuotes}',
                  'Rejected: ${user.rejectedQuotes}',
                ],
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Top products
        if (user.productsSold.isNotEmpty) ...[
          Text(
            'Top Products',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...user.productsSold.entries.take(5).map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.value} units',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
  
  Widget _buildDetailCard({
    required String title,
    required List<String> items,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              item,
              style: theme.textTheme.bodySmall,
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildActivityTimeline(List<UserPerformanceMetrics> metrics, ThemeData theme) {
    // Collect all recent quotes from all users
    final List<Quote> allRecentQuotes = [];
    for (final user in metrics) {
      for (final quote in user.recentQuotes) {
        allRecentQuotes.add(quote);
      }
    }
    
    // Sort by date
    allRecentQuotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: allRecentQuotes.take(10).map((quote) {
          final user = metrics.firstWhere(
            (m) => m.recentQuotes.contains(quote),
            orElse: () => metrics.first,
          );
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(quote.status),
              child: Icon(
                _getStatusIcon(quote.status),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text('${quote.quoteNumber ?? 'Quote'} - ${user.displayName}'),
            subtitle: Text(
              '${quote.client?.company ?? 'Unknown Client'} • ${_formatDate(quote.createdAt)}',
            ),
            trailing: Text(
              NumberFormat.currency(symbol: '\$').format(quote.total),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildPerformanceMatrix(List<UserPerformanceMetrics> metrics, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Revenue'), numeric: true),
          DataColumn(label: Text('Quotes'), numeric: true),
          DataColumn(label: Text('Conversion'), numeric: true),
          DataColumn(label: Text('Avg Value'), numeric: true),
          DataColumn(label: Text('Response Time'), numeric: true),
          DataColumn(label: Text('Score'), numeric: true),
        ],
        rows: metrics.map((user) {
          // Calculate performance score (0-100)
          final revenueScore = (user.totalRevenue / metrics.first.totalRevenue) * 30;
          final conversionScore = (user.conversionRate / 100) * 30;
          final quotesScore = (user.totalQuotes / metrics.first.totalQuotes) * 20;
          final responseScore = user.averageResponseTime < 24 ? 20 : 
                               user.averageResponseTime < 48 ? 10 : 0;
          final totalScore = (revenueScore + conversionScore + quotesScore + responseScore)
              .clamp(0, 100);
          
          return DataRow(
            cells: [
              DataCell(Text(user.displayName)),
              DataCell(Text(NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(user.totalRevenue))),
              DataCell(Text(user.totalQuotes.toString())),
              DataCell(Text('${user.conversionRate.toStringAsFixed(1)}%')),
              DataCell(Text(NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                  .format(user.averageQuoteValue))),
              DataCell(Text('${user.averageResponseTime.toStringAsFixed(0)}h')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(totalScore.toDouble()),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    totalScore.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  String _getSortLabel(String sort) {
    switch (sort) {
      case 'revenue': return 'Revenue';
      case 'quotes': return 'Quotes';
      case 'conversion': return 'Conversion';
      case 'clients': return 'Clients';
      default: return sort;
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'closed':
      case 'sold':
        return Colors.green;
      case 'pending':
      case 'sent':
        return Colors.orange;
      case 'rejected':
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'closed':
      case 'sold':
        return Icons.check_circle;
      case 'pending':
      case 'sent':
        return Icons.schedule;
      case 'rejected':
      case 'expired':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
  
  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.amber;
    return Colors.red;
  }
}