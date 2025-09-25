import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../../../core/services/error_monitoring_service.dart';
import '../../../../core/utils/download_helper.dart';

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

// Provider for error statistics with auto-refresh
final errorStatisticsProvider = StreamProvider.autoDispose<ErrorStatistics>((ref) {
  final service = ref.watch(errorMonitoringProvider);
  // Refresh statistics every 30 seconds
  return Stream.periodic(const Duration(seconds: 30), (_) => null)
      .asyncMap((_) async => await service.getStatistics())
      .handleError((error) {
        // Return empty statistics on error
        return ErrorStatistics(
          totalErrors: 0,
          unresolvedErrors: 0,
          errorsByCategory: {},
          errorsBySeverity: {},
          recentErrors: [],
        );
      });
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
  bool _isErrorListExpanded = false;
  String _errorSortBy = 'timestamp'; // 'timestamp', 'severity', 'category'

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

        // Expandable Error List Section
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            initiallyExpanded: _isErrorListExpanded,
            onExpansionChanged: (expanded) {
              setState(() => _isErrorListExpanded = expanded);
            },
            leading: Icon(
              _isErrorListExpanded ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).primaryColor,
            ),
            title: Row(
              children: [
                const Text(
                  'All Errors',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${errorsAsync.value?.length ?? 0} total',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              _isErrorListExpanded ? 'Click to collapse' : 'Click to view all errors',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sort dropdown
                DropdownButton<String>(
                  value: _errorSortBy,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'timestamp', child: Text('Latest First')),
                    DropdownMenuItem(value: 'severity', child: Text('By Severity')),
                    DropdownMenuItem(value: 'category', child: Text('By Category')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _errorSortBy = value);
                    }
                  },
                ),
              ],
            ),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5, // Half screen height
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

                    // Apply sorting
                    filteredErrors = _sortErrors(filteredErrors);

                    if (filteredErrors.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                              SizedBox(height: 16),
                              Text(
                                'No errors found',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Great! Your application is running smoothly.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Error count summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Theme.of(context).primaryColor.withOpacity(0.05),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${filteredErrors.length} error(s)',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  // Export or clear functionality
                                  _showErrorActions(context, filteredErrors);
                                },
                                icon: const Icon(Icons.more_vert),
                                label: const Text('Actions'),
                              ),
                            ],
                          ),
                        ),
                        // Scrollable error list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: filteredErrors.length,
                            itemBuilder: (context, index) {
                              final error = filteredErrors[index];
                              return _buildCompactErrorCard(error);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Error loading errors: $error'),
                  ),
                ),
              ),
            ],
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

  List<ErrorReport> _sortErrors(List<ErrorReport> errors) {
    switch (_errorSortBy) {
      case 'severity':
        errors.sort((a, b) {
          // Sort by severity (critical first)
          const severityOrder = {
            ErrorSeverity.critical: 0,
            ErrorSeverity.high: 1,
            ErrorSeverity.medium: 2,
            ErrorSeverity.low: 3,
          };
          return (severityOrder[a.severity] ?? 99).compareTo(severityOrder[b.severity] ?? 99);
        });
        break;
      case 'category':
        errors.sort((a, b) => a.category.toString().compareTo(b.category.toString()));
        break;
      case 'timestamp':
      default:
        errors.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
    }
    return errors;
  }

  void _showErrorActions(BuildContext context, List<ErrorReport> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export as CSV'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.pop(context);
                _exportErrorsToCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as JSON'),
              subtitle: const Text('Developer format'),
              onTap: () {
                Navigator.pop(context);
                _exportErrorsToJSON();
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('Clear Resolved'),
              subtitle: const Text('Remove all resolved errors'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(errorMonitoringProvider).clearResolvedErrors();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resolved errors cleared')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear All Errors'),
              subtitle: const Text('Remove all error logs'),
              onTap: () {
                Navigator.pop(context);
                _confirmClearAllErrors(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportErrorsToCSV() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Preparing export...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get errors from the provider
      final errorsAsync = ref.read(errorsStreamProvider);

      List<ErrorReport> errors = [];
      errorsAsync.when(
        data: (data) => errors = data,
        loading: () => errors = [],
        error: (_, __) => errors = [],
      );

      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No error reports to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Build CSV content
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      final StringBuffer csvBuffer = StringBuffer();

      // Add headers
      csvBuffer.writeln('ID,Timestamp,Severity,Category,Message,Screen,Action,User Email,Resolved,Resolved By,Resolved At,Stack Trace');

      // Add data rows
      for (final error in errors) {
        final row = [
          error.id,
          dateFormat.format(error.timestamp),
          error.severity.toString().split('.').last,
          error.category.toString().split('.').last,
          '"${error.message.replaceAll('"', '""')}"', // Escape quotes in message
          error.screen ?? '',
          error.action ?? '',
          error.userEmail ?? '',
          error.resolved ? 'Yes' : 'No',
          error.resolvedBy ?? '',
          error.resolvedAt != null ? dateFormat.format(error.resolvedAt!) : '',
          error.stackTrace != null ? '"${error.stackTrace!.replaceAll('"', '""').replaceAll('\n', ' ')}"' : '',
        ];
        csvBuffer.writeln(row.join(','));
      }

      // Convert to bytes
      final bytes = Uint8List.fromList(utf8.encode(csvBuffer.toString()));

      // Generate filename with timestamp
      final fileDate = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final filename = 'error_reports_$fileDate.csv';

      // Download the file
      await DownloadHelper.downloadFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'text/csv',
      );

      // Clear loading snackbar and show success
      ScaffoldMessenger.of(context).clearSnackBars();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully exported ${errors.length} error reports'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export error reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportErrorsToJSON() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Preparing JSON export...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get errors from the provider
      final errorsAsync = ref.read(errorsStreamProvider);

      List<ErrorReport> errors = [];
      errorsAsync.when(
        data: (data) => errors = data,
        loading: () => errors = [],
        error: (_, __) => errors = [],
      );

      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No error reports to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Build JSON content
      final List<Map<String, dynamic>> jsonData = errors.map((error) {
        return {
          'id': error.id,
          'timestamp': error.timestamp.toIso8601String(),
          'severity': error.severity.toString().split('.').last,
          'category': error.category.toString().split('.').last,
          'message': error.message,
          'stackTrace': error.stackTrace,
          'screen': error.screen,
          'action': error.action,
          'userId': error.userId,
          'userEmail': error.userEmail,
          'context': error.context,
          'resolved': error.resolved,
          'resolvedBy': error.resolvedBy,
          'resolvedAt': error.resolvedAt?.toIso8601String(),
        };
      }).toList();

      // Create the final JSON structure with metadata
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalErrors': errors.length,
        'unresolvedCount': errors.where((e) => !e.resolved).length,
        'resolvedCount': errors.where((e) => e.resolved).length,
        'errors': jsonData,
      };

      // Convert to pretty JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      // Generate filename with timestamp
      final fileDate = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final filename = 'error_reports_$fileDate.json';

      // Download the file
      await DownloadHelper.downloadFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/json',
      );

      // Clear loading snackbar and show success
      ScaffoldMessenger.of(context).clearSnackBars();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully exported ${errors.length} error reports as JSON'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export error reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmClearAllErrors(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Errors?'),
        content: const Text('This will permanently delete all error logs. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(errorMonitoringProvider).clearAllErrors();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All errors cleared')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactErrorCard(ErrorReport error) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _getSeverityColor(error.severity).withOpacity(0.2),
          child: Icon(
            _getSeverityIcon(error.severity),
            color: _getSeverityColor(error.severity),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                error.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getCategoryColor(error.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                error.category.toString().split('.').last,
                style: TextStyle(
                  fontSize: 10,
                  color: _getCategoryColor(error.category),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${_formatTimestamp(error.timestamp)} • ${error.userId ?? 'System'}',
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!error.isResolved)
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                onPressed: () async {
                  await ref.read(errorMonitoringProvider).markErrorAsResolved(error.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error marked as resolved')),
                    );
                  }
                },
                tooltip: 'Mark as Resolved',
              )
            else
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: () => _showErrorDetails(error),
              tooltip: 'View Details',
            ),
          ],
        ),
        onTap: () => _showErrorDetails(error),
      ),
    );
  }

  void _showErrorDetails(ErrorReport error) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Column(
            children: [
              AppBar(
                title: const Text('Error Details'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildFullErrorDetails(error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullErrorDetails(ErrorReport error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('ID', error.id),
        _buildDetailRow('Message', error.message),
        _buildDetailRow('Severity', error.severity.toString().split('.').last),
        _buildDetailRow('Category', error.category.toString().split('.').last),
        _buildDetailRow('Timestamp', _formatTimestamp(error.timestamp)),
        if (error.userId != null) _buildDetailRow('User ID', error.userId!),
        if (error.stackTrace != null) ...[
          const SizedBox(height: 16),
          const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              error.stackTrace!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
        if (error.metadata != null && error.metadata!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...error.metadata!.entries.map((e) => _buildDetailRow(e.key, e.value.toString())),
        ],
      ],
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