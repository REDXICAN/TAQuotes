// lib/features/admin/presentation/screens/performance_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:typed_data';
import '../../../../core/models/models.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/rbac_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/download_helper.dart';
import '../../models/report_schedule.dart';
import '../../services/report_scheduler_service.dart';
import '../../services/performance_report_email_service.dart';
import '../../widgets/report_schedule_dialog.dart';


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
  final List<Quote> allQuotes; // All quotes for accurate chart data
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
    required this.allQuotes,
    required this.averageResponseTime,
    required this.totalProducts,
  });
}

// Performance filter parameters
class PerformanceFilterParams {
  final String period;
  final DateTime? customStart;
  final DateTime? customEnd;

  const PerformanceFilterParams({
    required this.period,
    this.customStart,
    this.customEnd,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformanceFilterParams &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          customStart == other.customStart &&
          customEnd == other.customEnd;

  @override
  int get hashCode => period.hashCode ^ customStart.hashCode ^ customEnd.hashCode;
}

// Auto-refreshing provider for aggregating user performance data with period filtering
final userPerformanceProvider = StreamProvider.autoDispose.family<List<UserPerformanceMetrics>, PerformanceFilterParams>((ref, params) async* {
  // Initial load
  yield await _fetchUserPerformanceMetrics(params.period, customStart: params.customStart, customEnd: params.customEnd);

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await _fetchUserPerformanceMetrics(params.period, customStart: params.customStart, customEnd: params.customEnd);
    } catch (e) {
      // Continue with previous data on error, don't break the stream
      AppLogger.error('Auto-refresh failed for performance metrics', error: e);
    }
  }
});

// Extract the logic to a separate function for reuse with period filtering
Future<List<UserPerformanceMetrics>> _fetchUserPerformanceMetrics(String period, {DateTime? customStart, DateTime? customEnd}) async {
  final database = FirebaseDatabase.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  // Check if user has permission to access performance dashboard
  if (currentUser == null) {
    return [];
  }

  final hasPermission = await RBACService.hasPermission('access_performance_dashboard');
  if (!hasPermission) {
    return [];
  }

  try {
    // Get all users
    final usersSnapshot = await database.ref('users').get();
    if (!usersSnapshot.exists) return [];

    final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
    final List<UserPerformanceMetrics> metrics = [];

    final now = DateTime.now();

    // Calculate date range based on selected period
    final DateTime periodStartDate;
    if (period == 'custom' && customStart != null) {
      periodStartDate = customStart;
    } else {
      switch (period) {
        case 'week':
          periodStartDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          periodStartDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'quarter':
          periodStartDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case 'year':
          periodStartDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case 'all':
        default:
          periodStartDate = DateTime(2000, 1, 1); // Beginning of time for "all time"
          break;
      }
    }

    final DateTime periodEndDate = (period == 'custom' && customEnd != null) ? customEnd : now;

    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    
    for (final entry in users.entries) {
      final userId = entry.key;
      final userData = Map<String, dynamic>.from(entry.value);
      
      // Get user's quotes and filter by period
      final quotesSnapshot = await database.ref('quotes/$userId').get();
      final quotes = <Quote>[];
      final allQuotes = <Quote>[]; // Store all quotes for chart data

      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        for (final quoteEntry in quotesData.entries) {
          final quoteMap = Map<String, dynamic>.from(quoteEntry.value);
          quoteMap['id'] = quoteEntry.key;
          final quote = Quote.fromMap(quoteMap);

          // Store all quotes for complete data set
          allQuotes.add(quote);

          // Filter quotes by selected period for metrics calculation
          final isInRange = (quote.createdAt.isAfter(periodStartDate) ||
                            quote.createdAt.isAtSameMomentAs(periodStartDate)) &&
                           (quote.createdAt.isBefore(periodEndDate.add(const Duration(days: 1))) ||
                            period == 'all');
          if (isInRange) {
            quotes.add(quote);
          }
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
          final createdAt = safeParseDateTimeWithFallback(clientData['created_at'] ?? clientData['createdAt']);
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
              final productName = item.productName;
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
        lastActivity: safeParseDateTimeOrNull(userData['lastLoginAt']),
        quotesThisWeek: quotesThisWeek,
        quotesThisMonth: quotesThisMonth,
        revenueThisMonth: revenueThisMonth,
        productsSold: productsSold,
        categoryRevenue: categoryRevenue,
        recentQuotes: recentQuotes,
        allQuotes: allQuotes, // Pass all quotes for chart calculations
        averageResponseTime: avgResponseTime,
        totalProducts: totalProducts,
      ));
    }
    
    // Sort by total revenue (best performers first)
    metrics.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    
    return metrics;
  } catch (e) {
    AppLogger.error('Error fetching performance metrics', error: e);
    return [];
  }
}

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
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isExporting = false;

  // Add missing getters
  ThemeData get theme => Theme.of(context);
  NumberFormat get numberFormat => NumberFormat('#,##0');
  NumberFormat get currencyFormat => NumberFormat.currency(symbol: '\$');
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAccess();
  }
  
  Future<void> _checkAccess() async {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to access this page'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return;
    }

    // Check if user has permission to access performance dashboard
    final hasPermission = await RBACService.hasPermission('access_performance_dashboard');

    if (!hasPermission) {
      // No permission - BLOCK ACCESS
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: SuperAdmin privileges required for Performance Dashboard.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      });
      AppLogger.warning('Access denied to Performance Dashboard', data: {'user_email': user.email});
      return;
    }

    AppLogger.info('Performance Dashboard access granted', data: {'user_email': user.email});
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Admin access check
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Performance Dashboard'),
        ),
        body: const Center(
          child: Text('Please log in to access this page'),
        ),
      );
    }

    // Check if user has permission to view performance dashboard
    final hasPermission = ref.watch(hasPermissionProvider(Permission.viewPerformanceDashboard));

    return hasPermission.when(
      data: (canView) {
        if (!canView) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Denied'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'You do not have permission to view the performance dashboard.',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return _buildDashboard(currentUser, ref);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Error checking permissions: $error'),
        ),
      ),
    );
  }

  Widget _buildDashboard(User currentUser, WidgetRef ref) {
    // Watch the performance provider with the selected period and custom dates
    final filterParams = PerformanceFilterParams(
      period: _selectedPeriod,
      customStart: _customStartDate,
      customEnd: _customEndDate,
    );
    final performanceAsync = ref.watch(userPerformanceProvider(filterParams));
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final isMobile = ResponsiveHelper.isMobile(context);

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
                DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
              ],
              onChanged: (value) {
                if (value == 'custom') {
                  _showCustomDateRangePicker(context);
                } else {
                  setState(() {
                    _selectedPeriod = value!;
                    _customStartDate = null;
                    _customEndDate = null;
                  });
                }
              },
            ),
          ),
          // Date range display for custom period
          if (_selectedPeriod == 'custom' && _customStartDate != null && _customEndDate != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Send email button
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendEmailReport(performanceAsync.value),
            tooltip: 'Send Report via Email',
          ),
          // Export button
          IconButton(
            icon: _isExporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : () => _exportToExcel(performanceAsync.value),
            tooltip: 'Export to Excel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final params = PerformanceFilterParams(
                period: _selectedPeriod,
                customStart: _customStartDate,
                customEnd: _customEndDate,
              );
              ref.invalidate(userPerformanceProvider(params));
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
            Tab(text: 'Schedules', icon: Icon(Icons.schedule)),
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

              // Schedules Tab
              _buildSchedulesTab(metrics, theme, isMobile),
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
                onPressed: () {
                  final params = PerformanceFilterParams(
                    period: _selectedPeriod,
                    customStart: _customStartDate,
                    customEnd: _customEndDate,
                  );
                  ref.invalidate(userPerformanceProvider(params));
                },
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
            childAspectRatio: isMobile ? 1.2 : 1.5,
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
              }),
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
    final Map<String, double> monthlyRevenue = {};
    final Map<String, int> userQuoteCount = {};
    
    for (final user in metrics) {
      user.categoryRevenue.forEach((category, revenue) {
        categoryRevenue[category] = (categoryRevenue[category] ?? 0) + revenue;
      });
      user.productsSold.forEach((product, quantity) {
        productsSold[product] = (productsSold[product] ?? 0) + quantity;
      });
      userQuoteCount[user.displayName] = user.totalQuotes;

      // Calculate monthly revenue from ALL quotes (not just recent 5)
      for (final quote in user.allQuotes) {
        final monthKey = DateFormat('MMM').format(quote.createdAt);
        if (quote.status.toLowerCase() == 'accepted' ||
            quote.status.toLowerCase() == 'closed' ||
            quote.status.toLowerCase() == 'sold') {
          monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + quote.total;
        }
      }
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
          // Revenue Trend Chart
          Text(
            'Revenue Trend',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildRevenueLineChart(monthlyRevenue, theme),
          ),
          const SizedBox(height: 32),
          
          // Category Revenue Pie Chart
          Text(
            'Revenue by Category',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pie Chart
              Expanded(
                flex: isMobile ? 1 : 2,
                child: Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildCategoryPieChart(topCategories.take(5).toList(), theme),
                ),
              ),
              if (!isMobile) ...[  
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  child: Container(
                    height: 300,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildChartLegend(topCategories.take(5).toList(), currencyFormat, theme),
                  ),
                ),
              ],
            ],
          ),
          if (isMobile) ...[  
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildChartLegend(topCategories.take(5).toList(), currencyFormat, theme),
            ),
          ],
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
                    backgroundColor: theme.primaryColor.withValues(alpha:0.1),
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
                      color: theme.primaryColor.withValues(alpha:0.1),
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
            color: Colors.black.withValues(alpha:0.05),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
          colors: [color.withValues(alpha:0.1), color.withValues(alpha:0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.disabledColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.disabledColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                      color: theme.primaryColor.withValues(alpha:0.1),
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
          }),
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
          )),
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
            title: Text(
              '${quote.quoteNumber ?? 'Quote'} - ${user.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${quote.client?.company ?? 'Unknown Client'} • ${_formatDate(quote.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  
  // Chart building methods
  Widget _buildRevenueLineChart(Map<String, double> monthlyRevenue, ThemeData theme) {
    if (monthlyRevenue.isEmpty) {
      return const Center(child: Text('No revenue data available'));
    }
    
    final spots = <FlSpot>[];
    final months = monthlyRevenue.keys.toList();
    double maxY = 0;
    
    for (int i = 0; i < months.length; i++) {
      final value = monthlyRevenue[months[i]] ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
      if (value > maxY) maxY = value;
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: maxY > 0 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withValues(alpha:0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withValues(alpha:0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      months[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY > 0 ? maxY / 5 : 1,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value / 1000).toStringAsFixed(0)}K',
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: theme.dividerColor.withValues(alpha:0.5)),
        ),
        minX: 0,
        maxX: months.length.toDouble() - 1,
        minY: 0,
        maxY: maxY * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.primaryColor.withValues(alpha:0.7)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: theme.primaryColor,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor.withValues(alpha:0.2),
                  theme.primaryColor.withValues(alpha:0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryPieChart(List<MapEntry<String, double>> categories, ThemeData theme) {
    if (categories.isEmpty) {
      return const Center(child: Text('No category data available'));
    }
    
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    
    final total = categories.fold(0.0, (sum, entry) => sum + entry.value);
    
    return PieChart(
      PieChartData(
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final percentage = (category.value / total * 100);
          
          return PieChartSectionData(
            color: colors[index % colors.length],
            value: category.value,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildChartLegend(
    List<MapEntry<String, double>> categories,
    NumberFormat currencyFormat,
    ThemeData theme,
  ) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    final total = categories.fold(0.0, (sum, entry) => sum + entry.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final percentage = (category.value / total * 100);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currencyFormat.format(category.value)} (${percentage.toStringAsFixed(1)}%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const Spacer(),
        Divider(color: theme.dividerColor),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currencyFormat.format(total),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Custom Date Range Picker
  Future<void> _showCustomDateRangePicker(BuildContext context) async {
    final now = DateTime.now();
    DateTime? startDate = _customStartDate ?? now.subtract(const Duration(days: 30));
    DateTime? endDate = _customEndDate ?? now;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Custom Date Range'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start Date
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Start Date'),
                      subtitle: Text(
                        startDate != null
                            ? DateFormat('MMMM dd, yyyy').format(startDate!)
                            : 'Not selected',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? now.subtract(const Duration(days: 30)),
                          firstDate: DateTime(2000),
                          lastDate: endDate ?? now,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // End Date
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text('End Date'),
                      subtitle: Text(
                        endDate != null
                            ? DateFormat('MMMM dd, yyyy').format(endDate!)
                            : 'Not selected',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? now,
                          firstDate: startDate ?? DateTime(2000),
                          lastDate: now,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Quick date range buttons
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildQuickRangeChip(
                          'Last 7 Days',
                          () {
                            setDialogState(() {
                              endDate = now;
                              startDate = now.subtract(const Duration(days: 7));
                            });
                          },
                        ),
                        _buildQuickRangeChip(
                          'Last 30 Days',
                          () {
                            setDialogState(() {
                              endDate = now;
                              startDate = now.subtract(const Duration(days: 30));
                            });
                          },
                        ),
                        _buildQuickRangeChip(
                          'Last 90 Days',
                          () {
                            setDialogState(() {
                              endDate = now;
                              startDate = now.subtract(const Duration(days: 90));
                            });
                          },
                        ),
                        _buildQuickRangeChip(
                          'Year to Date',
                          () {
                            setDialogState(() {
                              endDate = now;
                              startDate = DateTime(now.year, 1, 1);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: startDate != null && endDate != null
                      ? () {
                          setState(() {
                            _customStartDate = startDate;
                            _customEndDate = endDate;
                            _selectedPeriod = 'custom';
                          });
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickRangeChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }

  // Export to Excel
  Future<void> _exportToExcel(List<UserPerformanceMetrics>? metrics) async {
    if (metrics == null || metrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final excel = excel_pkg.Excel.createExcel();
      excel.delete('Sheet1');

      // Create Overview Sheet
      _createOverviewSheet(excel, metrics);

      // Create User Details Sheet
      _createUserDetailsSheet(excel, metrics);

      // Create Analytics Sheet
      _createAnalyticsSheet(excel, metrics);

      // Save and download
      final bytes = excel.save();
      if (bytes != null) {
        final periodName = _getPeriodDisplayName();
        final fileName = 'Performance_Dashboard_${periodName}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';

        await DownloadHelper.downloadFile(
          bytes: Uint8List.fromList(bytes),
          filename: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel file exported: $fileName')),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error exporting to Excel', error: e, category: LogCategory.business);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _getPeriodDisplayName() {
    if (_selectedPeriod == 'custom' && _customStartDate != null && _customEndDate != null) {
      return '${DateFormat('MMM_dd').format(_customStartDate!)}_to_${DateFormat('MMM_dd_yyyy').format(_customEndDate!)}';
    }
    switch (_selectedPeriod) {
      case 'week': return 'This_Week';
      case 'month': return 'This_Month';
      case 'quarter': return 'This_Quarter';
      case 'year': return 'This_Year';
      case 'all': return 'All_Time';
      default: return _selectedPeriod;
    }
  }

  void _createOverviewSheet(excel_pkg.Excel excel, List<UserPerformanceMetrics> metrics) {
    final sheet = excel['Overview'];

    // Calculate totals
    final totalRevenue = metrics.fold(0.0, (sum, m) => sum + m.totalRevenue);
    final totalQuotes = metrics.fold(0, (sum, m) => sum + m.totalQuotes);
    final totalClients = metrics.fold(0, (sum, m) => sum + m.totalClients);
    final avgConversion = metrics.isEmpty ? 0.0 :
        metrics.fold(0.0, (sum, m) => sum + m.conversionRate) / metrics.length;

    int row = 0;

    // Title
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('PERFORMANCE DASHBOARD - OVERVIEW')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 16);
    row += 2;

    // Period
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('Period:')
      ..cellStyle = excel_pkg.CellStyle(bold: true);
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      .value = excel_pkg.TextCellValue(_getPeriodDisplayName().replaceAll('_', ' '));
    row += 2;

    // Company KPIs
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('COMPANY PERFORMANCE')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
    row += 1;

    final kpiData = [
      ['Total Revenue', NumberFormat.currency(symbol: '\$').format(totalRevenue)],
      ['Total Quotes', totalQuotes.toString()],
      ['Total Clients', totalClients.toString()],
      ['Average Conversion Rate', '${avgConversion.toStringAsFixed(1)}%'],
    ];

    for (final kpi in kpiData) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue(kpi[0])
        ..cellStyle = excel_pkg.CellStyle(bold: true);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = excel_pkg.TextCellValue(kpi[1]);
      row++;
    }

    row += 2;

    // Top Performers
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('TOP PERFORMERS')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
    row += 1;

    final topByRevenue = [...metrics]..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final topByQuotes = [...metrics]..sort((a, b) => b.totalQuotes.compareTo(a.totalQuotes));
    final topByConversion = [...metrics]..sort((a, b) => b.conversionRate.compareTo(a.conversionRate));

    // Headers
    final headers = ['Rank', 'By Revenue', 'Amount', 'By Quotes', 'Count', 'By Conversion', 'Rate'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
        ..value = excel_pkg.TextCellValue(headers[i])
        ..cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
    }
    row++;

    // Top 10
    for (int i = 0; i < 10 && i < metrics.length; i++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = excel_pkg.IntCellValue(i + 1);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = excel_pkg.TextCellValue(topByRevenue[i].displayName);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = excel_pkg.TextCellValue(NumberFormat.currency(symbol: '\$').format(topByRevenue[i].totalRevenue));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = excel_pkg.TextCellValue(topByQuotes[i].displayName);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = excel_pkg.IntCellValue(topByQuotes[i].totalQuotes);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = excel_pkg.TextCellValue(topByConversion[i].displayName);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = excel_pkg.TextCellValue('${topByConversion[i].conversionRate.toStringAsFixed(1)}%');
      row++;
    }

    // Auto-size columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }
  }

  void _createUserDetailsSheet(excel_pkg.Excel excel, List<UserPerformanceMetrics> metrics) {
    final sheet = excel['User Details'];

    // Headers
    final headers = [
      'User Name',
      'Email',
      'Total Revenue',
      'Total Quotes',
      'Accepted',
      'Pending',
      'Rejected',
      'Conversion Rate',
      'Avg Quote Value',
      'Total Clients',
      'New Clients This Month',
      'Quotes This Week',
      'Quotes This Month',
      'Revenue This Month',
      'Avg Response Time (hrs)',
      'Total Products Sold',
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = excel_pkg.TextCellValue(headers[i])
        ..cellStyle = excel_pkg.CellStyle(
          bold: true,
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#4CAF50'),
          fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        );
    }

    // Data rows
    for (int rowIndex = 0; rowIndex < metrics.length; rowIndex++) {
      final user = metrics[rowIndex];
      final row = rowIndex + 1;

      final rowData = [
        user.displayName,
        user.email,
        NumberFormat.currency(symbol: '\$').format(user.totalRevenue),
        user.totalQuotes.toString(),
        user.acceptedQuotes.toString(),
        user.pendingQuotes.toString(),
        user.rejectedQuotes.toString(),
        '${user.conversionRate.toStringAsFixed(1)}%',
        NumberFormat.currency(symbol: '\$').format(user.averageQuoteValue),
        user.totalClients.toString(),
        user.newClientsThisMonth.toString(),
        user.quotesThisWeek.toString(),
        user.quotesThisMonth.toString(),
        NumberFormat.currency(symbol: '\$').format(user.revenueThisMonth),
        user.averageResponseTime.toStringAsFixed(1),
        user.totalProducts.toString(),
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row))
          .value = excel_pkg.TextCellValue(rowData[colIndex]);
      }
    }

    // Auto-size columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }
  }

  void _createAnalyticsSheet(excel_pkg.Excel excel, List<UserPerformanceMetrics> metrics) {
    final sheet = excel['Analytics'];

    int row = 0;

    // Title
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('ANALYTICS SUMMARY')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 16);
    row += 2;

    // Category Revenue
    final Map<String, double> categoryRevenue = {};
    for (final user in metrics) {
      user.categoryRevenue.forEach((category, revenue) {
        categoryRevenue[category] = (categoryRevenue[category] ?? 0) + revenue;
      });
    }

    if (categoryRevenue.isNotEmpty) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('REVENUE BY CATEGORY')
        ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
      row += 1;

      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Category')
        ..cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Revenue')
        ..cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Percentage')
        ..cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      row++;

      final totalRevenue = categoryRevenue.values.fold(0.0, (sum, val) => sum + val);
      final sortedCategories = categoryRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedCategories) {
        final percentage = (entry.value / totalRevenue * 100).toStringAsFixed(1);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = excel_pkg.TextCellValue(entry.key);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = excel_pkg.TextCellValue(NumberFormat.currency(symbol: '\$').format(entry.value));
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = excel_pkg.TextCellValue('$percentage%');
        row++;
      }

      row += 2;
    }

    // Top Products
    final Map<String, int> productsSold = {};
    for (final user in metrics) {
      user.productsSold.forEach((product, quantity) {
        productsSold[product] = (productsSold[product] ?? 0) + quantity;
      });
    }

    if (productsSold.isNotEmpty) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('TOP PRODUCTS SOLD')
        ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
      row += 1;

      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Rank')
        ..cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Product')
        ..cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Units Sold')
        ..cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      row++;

      final sortedProducts = productsSold.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < sortedProducts.length && i < 20; i++) {
        final entry = sortedProducts[i];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = excel_pkg.IntCellValue(i + 1);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = excel_pkg.TextCellValue(entry.key);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = excel_pkg.IntCellValue(entry.value);
        row++;
      }
    }

    // Auto-size columns
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 20);
  }

  // Build schedules tab
  Widget _buildSchedulesTab(
    List<UserPerformanceMetrics> metrics,
    ThemeData theme,
    bool isMobile,
  ) {
    return StreamBuilder<List<ReportSchedule>>(
      stream: ReportSchedulerService.getUserSchedules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading schedules: ${snapshot.error}'),
              ],
            ),
          );
        }

        final schedules = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with create button
              Row(
                children: [
                  Icon(Icons.schedule_send, color: theme.primaryColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Report Schedules',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Automatically send performance reports via email',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showScheduleDialog(null, metrics),
                    icon: const Icon(Icons.add),
                    label: const Text('New Schedule'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: Actual scheduled sending requires backend setup (Firebase Cloud Functions). '
                        'Currently, you can create schedules and send reports manually.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Schedules list
              if (schedules.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule,
                          size: 80, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text(
                        'No schedules created yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first schedule to automate performance reports',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showScheduleDialog(null, metrics),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Schedule'),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return _buildScheduleCard(schedule, theme, metrics);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(
    ReportSchedule schedule,
    ThemeData theme,
    List<UserPerformanceMetrics> metrics,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: schedule.isEnabled
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.grey.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    schedule.isEnabled ? Icons.schedule : Icons.schedule_outlined,
                    color: schedule.isEnabled ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            schedule.getFrequencyDisplay(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: schedule.isEnabled
                                  ? Colors.green.withValues(alpha:0.1)
                                  : Colors.grey.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              schedule.isEnabled ? 'Active' : 'Disabled',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: schedule.isEnabled
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${schedule.recipientEmails.length} recipient(s)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'send_now':
                        _sendScheduledReport(schedule, metrics);
                        break;
                      case 'edit':
                        _showScheduleDialog(schedule, metrics);
                        break;
                      case 'toggle':
                        ReportSchedulerService.toggleSchedule(
                            schedule.id, !schedule.isEnabled);
                        break;
                      case 'delete':
                        _deleteSchedule(schedule);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'send_now',
                      child: Row(
                        children: [
                          Icon(Icons.send, size: 20),
                          SizedBox(width: 8),
                          Text('Send Now'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            schedule.isEnabled
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(schedule.isEnabled ? 'Disable' : 'Enable'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Recipients
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schedule.recipientEmails.map((email) {
                return Chip(
                  avatar: const Icon(Icons.email, size: 16),
                  label: Text(email),
                  labelStyle: theme.textTheme.bodySmall,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            // Last sent / Next scheduled
            if (schedule.lastSent != null || schedule.nextScheduled != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (schedule.lastSent != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Last sent: ${DateFormat('MMM dd, yyyy HH:mm').format(schedule.lastSent!)}',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (schedule.nextScheduled != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Next: ${DateFormat('MMM dd, yyyy HH:mm').format(schedule.nextScheduled!)}',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showScheduleDialog(
    ReportSchedule? existingSchedule,
    List<UserPerformanceMetrics> metrics,
  ) async {
    final result = await showDialog<ReportSchedule>(
      context: context,
      builder: (context) => ReportScheduleDialog(
        existingSchedule: existingSchedule,
      ),
    );

    if (result != null) {
      final success = existingSchedule == null
          ? await ReportSchedulerService.createSchedule(result)
          : await ReportSchedulerService.updateSchedule(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? existingSchedule == null
                      ? 'Schedule created successfully'
                      : 'Schedule updated successfully'
                  : 'Failed to save schedule',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSchedule(ReportSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text(
          'Are you sure you want to delete this schedule?\n\n${schedule.getFrequencyDisplay()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ReportSchedulerService.deleteSchedule(schedule.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Schedule deleted successfully'
                  : 'Failed to delete schedule',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendScheduledReport(
    ReportSchedule schedule,
    List<UserPerformanceMetrics> metrics,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Sending report...'),
          ],
        ),
      ),
    );

    try {
      final success =
          await PerformanceReportEmailService.sendPerformanceReport(
        metrics: metrics,
        recipientEmails: schedule.recipientEmails,
        period: _selectedPeriod,
        customPeriodText: _selectedPeriod == 'custom' &&
                _customStartDate != null &&
                _customEndDate != null
            ? '${DateFormat('MMM dd').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}'
            : null,
      );

      if (success) {
        await ReportSchedulerService.markScheduleAsSent(schedule.id);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Report sent to ${schedule.recipientEmails.length} recipient(s)'
                  : 'Failed to send report',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmailReport(List<UserPerformanceMetrics>? metrics) async {
    if (metrics == null || metrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to send')),
      );
      return;
    }

    // Show dialog to enter recipient emails
    final recipientsController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Report via Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter recipient email addresses (comma-separated):'),
            const SizedBox(height: 12),
            TextField(
              controller: recipientsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'user1@example.com, user2@example.com',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true && recipientsController.text.isNotEmpty) {
      final recipients = recipientsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (recipients.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid email addresses')),
        );
        return;
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Sending report...'),
            ],
          ),
        ),
      );

      try {
        final success =
            await PerformanceReportEmailService.sendPerformanceReport(
          metrics: metrics,
          recipientEmails: recipients,
          period: _selectedPeriod,
          customPeriodText: _selectedPeriod == 'custom' &&
                  _customStartDate != null &&
                  _customEndDate != null
              ? '${DateFormat('MMM dd').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}'
              : null,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Report sent to ${recipients.length} recipient(s)'
                    : 'Failed to send report',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending report: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    recipientsController.dispose();
  }
}