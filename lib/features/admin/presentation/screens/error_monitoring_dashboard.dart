import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/error_monitoring_service.dart';

// Provider for error monitoring service
final errorMonitoringProvider = Provider<ErrorMonitoringService>((ref) {
  return ErrorMonitoringService();
});

// Provider for error stream
final errorsStreamProvider = StreamProvider.autoDispose<List<ErrorReport>>((ref) {
  final service = ref.watch(errorMonitoringProvider);
  return service.streamErrors();
});

// Provider for unresolved errors
final unresolvedErrorsStreamProvider = StreamProvider.autoDispose<List<ErrorReport>>((ref) {
  final service = ref.watch(errorMonitoringProvider);
  return service.streamErrors(unresolvedOnly: true);
});

// Provider for error statistics
final errorStatisticsProvider = FutureProvider.autoDispose<ErrorStatistics>((ref) async {
  final service = ref.watch(errorMonitoringProvider);
  return await service.getStatistics();
});

class ErrorMonitoringDashboard extends ConsumerStatefulWidget {
  const ErrorMonitoringDashboard({super.key});

  @override
  ConsumerState<ErrorMonitoringDashboard> createState() => _ErrorMonitoringDashboardState();
}

class _ErrorMonitoringDashboardState extends ConsumerState<ErrorMonitoringDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ErrorSeverity? _selectedSeverity;
  ErrorCategory? _selectedCategory;
  bool _showUnresolvedOnly = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
  }

  void _checkAdminAccess() {
    // Check if user is admin (hardcoded for security)
    final userEmail = ref.read(errorMonitoringProvider).userEmail?.toLowerCase();
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
              content: Text('Access Denied: Admin privileges required for Error Monitoring.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
      return;
    }

    setState(() {
      _hasAccess = true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getSeverityColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return Colors.red[900]!;
      case ErrorSeverity.high:
        return Colors.red;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.low:
        return Colors.yellow[700]!;
    }
  }

  IconData _getSeverityIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return Icons.error;
      case ErrorSeverity.high:
        return Icons.warning;
      case ErrorSeverity.medium:
        return Icons.info;
      case ErrorSeverity.low:
        return Icons.info_outline;
    }
  }

  IconData _getCategoryIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return Icons.lock;
      case ErrorCategory.database:
        return Icons.storage;
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.ui:
        return Icons.web;
      case ErrorCategory.business_logic:
        return Icons.business_center;
      case ErrorCategory.performance:
        return Icons.speed;
      case ErrorCategory.security:
        return Icons.security;
      case ErrorCategory.unknown:
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking access
    if (!_hasAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Monitoring Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Errors', icon: Icon(Icons.error_outline)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(errorStatisticsProvider);
              ref.invalidate(errorsStreamProvider);
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => _showClearOldErrorsDialog(),
            tooltip: 'Clear Old Errors',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildErrorsTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final statisticsAsync = ref.watch(errorStatisticsProvider);

    return statisticsAsync.when(
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Errors',
                  stats.totalErrors.toString(),
                  Icons.error_outline,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Critical',
                  stats.criticalErrors.toString(),
                  Icons.error,
                  Colors.red[900]!,
                ),
                _buildStatCard(
                  'High Priority',
                  stats.highErrors.toString(),
                  Icons.warning,
                  Colors.red,
                ),
                _buildStatCard(
                  'Medium Priority',
                  stats.mediumErrors.toString(),
                  Icons.info,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Low Priority',
                  stats.lowErrors.toString(),
                  Icons.info_outline,
                  Colors.yellow[700]!,
                ),
                _buildStatCard(
                  'Unresolved',
                  stats.unresolvedErrors.toString(),
                  Icons.pending_actions,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Error Rate',
                  '${stats.errorRate.toStringAsFixed(1)}/hr',
                  Icons.speed,
                  Colors.teal,
                ),
                _buildStatCard(
                  'Categories',
                  stats.errorsByCategory.length.toString(),
                  Icons.category,
                  Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Errors by Category
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Errors by Category',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (stats.errorsByCategory.isNotEmpty) ...[
                      SizedBox(
                        height: 200,
                        child: _buildCategoryChart(stats.errorsByCategory),
                      ),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No errors to display'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Error Messages
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Error Messages',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (stats.topErrorMessages.isNotEmpty) ...[
                      ...stats.topErrorMessages.take(10).map((message) => ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        dense: true,
                      )),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No errors to display'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading statistics: $error'),
      ),
    );
  }

  Widget _buildErrorsTab() {
    final errorsAsync = _showUnresolvedOnly
        ? ref.watch(unresolvedErrorsStreamProvider)
        : ref.watch(errorsStreamProvider);

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search errors...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 16),

              // Severity Filter
              DropdownButton<ErrorSeverity?>(
                value: _selectedSeverity,
                hint: const Text('Severity'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...ErrorSeverity.values.map((severity) => DropdownMenuItem(
                    value: severity,
                    child: Row(
                      children: [
                        Icon(
                          _getSeverityIcon(severity),
                          color: _getSeverityColor(severity),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(severity.toString().split('.').last),
                      ],
                    ),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedSeverity = value),
              ),
              const SizedBox(width: 16),

              // Category Filter
              DropdownButton<ErrorCategory?>(
                value: _selectedCategory,
                hint: const Text('Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...ErrorCategory.values.map((category) => DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(category.toString().split('.').last),
                      ],
                    ),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              const SizedBox(width: 16),

              // Unresolved Filter
              FilterChip(
                label: const Text('Unresolved Only'),
                selected: _showUnresolvedOnly,
                onSelected: (value) => setState(() => _showUnresolvedOnly = value),
              ),
            ],
          ),
        ),

        // Error List
        Expanded(
          child: errorsAsync.when(
            data: (errors) {
              // Apply filters
              var filteredErrors = errors;

              if (_searchQuery.isNotEmpty) {
                filteredErrors = filteredErrors.where((e) =>
                  e.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (e.stackTrace?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
                ).toList();
              }

              if (_selectedSeverity != null) {
                filteredErrors = filteredErrors.where((e) => e.severity == _selectedSeverity).toList();
              }

              if (_selectedCategory != null) {
                filteredErrors = filteredErrors.where((e) => e.category == _selectedCategory).toList();
              }

              if (filteredErrors.isEmpty) {
                return const Center(
                  child: Text('No errors found'),
                );
              }

              return ListView.builder(
                itemCount: filteredErrors.length,
                itemBuilder: (context, index) {
                  final error = filteredErrors[index];
                  return _buildErrorCard(error);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error loading errors: $error'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    final statisticsAsync = ref.watch(errorStatisticsProvider);

    return statisticsAsync.when(
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Severity Distribution
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error Severity Distribution',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: _buildSeverityPieChart(stats),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Errors by Screen
            if (stats.errorsByScreen.isNotEmpty) Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Errors by Screen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: _buildScreenBarChart(stats.errorsByScreen),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading analytics: $error'),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ErrorReport error) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: Icon(
          _getSeverityIcon(error.severity),
          color: _getSeverityColor(error.severity),
        ),
        title: Text(
          error.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              _getCategoryIcon(error.category),
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              error.category.toString().split('.').last,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(width: 16),
            Text(
              dateFormat.format(error.timestamp),
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (error.resolved) ...[
              const SizedBox(width: 16),
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
              const Text(' Resolved', style: TextStyle(color: Colors.green)),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error.userEmail != null) ...[
                  _buildDetailRow('User', error.userEmail!),
                ],
                if (error.screen != null) ...[
                  _buildDetailRow('Screen', error.screen!),
                ],
                if (error.action != null) ...[
                  _buildDetailRow('Action', error.action!),
                ],
                if (error.stackTrace != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Stack Trace:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      error.stackTrace!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (!error.resolved) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _markErrorResolved(error.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mark as Resolved'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, int> data) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: sortedEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final categoryData = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: categoryData.value.toDouble(),
                color: Theme.of(context).primaryColor,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedEntries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    sortedEntries[value.toInt()].key,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, horizontalInterval: 5),
      ),
    );
  }

  Widget _buildSeverityPieChart(ErrorStatistics stats) {
    final sections = <PieChartSectionData>[
      if (stats.criticalErrors > 0)
        PieChartSectionData(
          value: stats.criticalErrors.toDouble(),
          title: 'Critical\n${stats.criticalErrors}',
          color: Colors.red[900],
          radius: 100,
        ),
      if (stats.highErrors > 0)
        PieChartSectionData(
          value: stats.highErrors.toDouble(),
          title: 'High\n${stats.highErrors}',
          color: Colors.red,
          radius: 100,
        ),
      if (stats.mediumErrors > 0)
        PieChartSectionData(
          value: stats.mediumErrors.toDouble(),
          title: 'Medium\n${stats.mediumErrors}',
          color: Colors.orange,
          radius: 100,
        ),
      if (stats.lowErrors > 0)
        PieChartSectionData(
          value: stats.lowErrors.toDouble(),
          title: 'Low\n${stats.lowErrors}',
          color: Colors.yellow[700],
          radius: 100,
        ),
    ];

    if (sections.isEmpty) {
      return const Center(
        child: Text('No errors to display'),
      );
    }

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildScreenBarChart(Map<String, int> data) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: sortedEntries.take(10).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final screenData = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: screenData.value.toDouble(),
                color: Colors.blue,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedEntries.length) return const SizedBox();
                final screen = sortedEntries[value.toInt()].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: Text(
                      screen.length > 15 ? '${screen.substring(0, 15)}...' : screen,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, horizontalInterval: 5),
      ),
    );
  }

  Future<void> _markErrorResolved(String errorId) async {
    try {
      final service = ref.read(errorMonitoringProvider);
      await service.markErrorResolved(errorId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error marked as resolved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark error as resolved: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClearOldErrorsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Old Errors'),
        content: const Text(
          'This will delete all errors older than 30 days. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                final service = ref.read(errorMonitoringProvider);
                await service.clearOldErrors();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Old errors cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  ref.invalidate(errorStatisticsProvider);
                  ref.invalidate(errorsStreamProvider);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear old errors: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Old Errors'),
          ),
        ],
      ),
    );
  }
}