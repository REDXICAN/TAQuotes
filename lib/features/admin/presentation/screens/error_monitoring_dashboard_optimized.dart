import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../../../core/services/error_monitoring_service.dart';
import '../../../../core/services/error_demo_data_service.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
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
          criticalErrors: 0,
          highErrors: 0,
          mediumErrors: 0,
          lowErrors: 0,
          unresolvedErrors: 0,
          errorsByCategory: {},
          errorsByScreen: {},
          topErrorMessages: [],
          errorRate: 0.0,
        );
      });
});

class OptimizedErrorMonitoringDashboard extends ConsumerStatefulWidget {
  const OptimizedErrorMonitoringDashboard({super.key});

  @override
  ConsumerState<OptimizedErrorMonitoringDashboard> createState() => _OptimizedErrorMonitoringDashboardState();
}

class _OptimizedErrorMonitoringDashboardState extends ConsumerState<OptimizedErrorMonitoringDashboard> {
  ErrorSeverity? _selectedSeverity;
  ErrorCategory? _selectedCategory;
  bool _showUnresolvedOnly = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _hasAccess = false;
  String _errorSortBy = 'timestamp'; // 'timestamp', 'severity', 'category'
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _isLoading = false;
  bool _isPopulatingDemoData = false;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _lastRefresh = DateTime.now();
  }

  void _checkAdminAccess() {
    // Check if user has permission to view system logs
    ref.read(hasPermissionProvider(Permission.viewSystemLogs).future).then((hasPermission) {
      if (!hasPermission) {
        // No permission - BLOCK ACCESS
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
    });

    setState(() {
      _hasAccess = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get category color for display
  Color _getCategoryColor(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return Colors.red;
      case ErrorCategory.database:
        return Colors.blue;
      case ErrorCategory.network:
        return Colors.orange;
      case ErrorCategory.ui:
        return Colors.green;
      case ErrorCategory.business_logic:
        return Colors.purple;
      case ErrorCategory.performance:
        return Colors.teal;
      case ErrorCategory.security:
        return Colors.red[900]!;
      case ErrorCategory.unknown:
      default:
        return Colors.grey;
    }
  }

  // Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final dateFormat = DateFormat('MMM dd, HH:mm');
      return dateFormat.format(timestamp);
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _showExportDialog(),
            tooltip: 'Export',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'clear_old':
                  _showClearOldErrorsDialog();
                  break;
                case 'populate_demo':
                  _populateDemoErrorData();
                  break;
                case 'clear_demo':
                  _showClearDemoDataDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_old',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear Old Errors'),
                  subtitle: Text('Remove errors older than 30 days'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'populate_demo',
                child: ListTile(
                  leading: Icon(Icons.data_saver_on),
                  title: Text('Populate Demo Data'),
                  subtitle: Text('Add 50 sample error reports'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_demo',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Clear Demo Data'),
                  subtitle: Text('Remove all demo error data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildSingleScreenDashboard(),
    );
  }

  Widget _buildSingleScreenDashboard() {
    final statisticsAsync = ref.watch(errorStatisticsProvider);
    final errorsAsync = _showUnresolvedOnly
        ? ref.watch(unresolvedErrorsStreamProvider)
        : ref.watch(errorsStreamProvider);

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats Row - Compact version
            statisticsAsync.when(
              data: (stats) => stats.totalErrors == 0 ? _buildEmptyStatsRow() : _buildQuickStatsRow(stats),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Container(
                height: 100,
                alignment: Alignment.center,
                child: Text('Error loading stats: $error', style: TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 16),

            // Critical Alerts Banner
            statisticsAsync.when(
              data: (stats) => _buildCriticalAlertsBanner(stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Top Error Messages - Clickable Section
            statisticsAsync.when(
              data: (stats) => _buildTopErrorMessagesSection(stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Category Distribution - Compact Chart
            statisticsAsync.when(
              data: (stats) => _buildCompactCategoryChart(stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Quick Filters
            _buildQuickFilters(),
            const SizedBox(height: 16),

            // Recent Errors List
            errorsAsync.when(
              data: (errors) => _buildRecentErrorsList(errors),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading errors: $error', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New optimized methods for single-screen layout
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _lastRefresh = DateTime.now();
    });

    ref.invalidate(errorStatisticsProvider);
    ref.invalidate(errorsStreamProvider);

    // Wait a moment to show loading state
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _populateDemoErrorData() async {
    setState(() {
      _isPopulatingDemoData = true;
    });

    try {
      final demoService = ErrorDemoDataService();
      await demoService.populateDemoErrors(numberOfErrors: 50);

      // Refresh the data to show the new demo errors
      ref.invalidate(errorStatisticsProvider);
      ref.invalidate(errorsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Demo error data populated successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to populate demo data: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPopulatingDemoData = false;
        });
      }
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Error Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStatsRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.blue[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Error Statistics Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No error data has been collected yet. The dashboard will show statistics once errors are recorded.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow(ErrorStatistics stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                'Total',
                stats.totalErrors.toString(),
                Icons.error_outline,
                Colors.blue,
              ),
            ),
            Expanded(
              child: _buildMiniStatCard(
                'Critical',
                stats.criticalErrors.toString(),
                Icons.error,
                Colors.red[900]!,
              ),
            ),
            Expanded(
              child: _buildMiniStatCard(
                'Unresolved',
                stats.unresolvedErrors.toString(),
                Icons.pending_actions,
                Colors.purple,
              ),
            ),
            Expanded(
              child: _buildMiniStatCard(
                'Rate/hr',
                stats.errorRate.toStringAsFixed(1),
                Icons.speed,
                Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalAlertsBanner(ErrorStatistics stats) {
    final criticalCount = stats.criticalErrors + stats.highErrors;
    if (criticalCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alert: $criticalCount critical/high priority errors require attention',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSeverity = ErrorSeverity.critical;
                _showUnresolvedOnly = true;
              });
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopErrorMessagesSection(ErrorStatistics stats) {
    if (stats.topErrorMessages.isEmpty) return const SizedBox.shrink();

    return Card(
      child: InkWell(
        onTap: () => _showErrorCategoriesPopup(stats),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Top Error Messages',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Text(
                        '${stats.topErrorMessages.length} messages',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...stats.topErrorMessages.take(3).map((message) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
              if (stats.topErrorMessages.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap to view all ${stats.topErrorMessages.length} messages by category',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCategoryChart(ErrorStatistics stats) {
    if (stats.errorsByCategory.isEmpty) return const SizedBox.shrink();

    final sortedEntries = stats.errorsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Errors by Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...sortedEntries.take(5).map((entry) {
              final percentage = ((entry.value / stats.totalErrors) * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(_parseCategoryFromString(entry.key)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${entry.value} ($percentage%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
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

  ErrorCategory _parseCategoryFromString(String categoryString) {
    return ErrorCategory.values.firstWhere(
      (cat) => cat.toString().split('.').last == categoryString,
      orElse: () => ErrorCategory.unknown,
    );
  }

  Widget _buildQuickFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Filters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search errors...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            // Filter chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: const Text('Unresolved Only'),
                  selected: _showUnresolvedOnly,
                  onSelected: (value) => setState(() => _showUnresolvedOnly = value),
                ),
                if (_selectedSeverity != null)
                  FilterChip(
                    label: Text('${_selectedSeverity.toString().split('.').last} severity'),
                    selected: true,
                    onSelected: (value) => setState(() => _selectedSeverity = null),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                if (_selectedCategory != null)
                  FilterChip(
                    label: Text('${_selectedCategory.toString().split('.').last} category'),
                    selected: true,
                    onSelected: (value) => setState(() => _selectedCategory = null),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                // Quick severity filters
                FilterChip(
                  label: const Text('Critical'),
                  selected: _selectedSeverity == ErrorSeverity.critical,
                  onSelected: (value) => setState(() =>
                    _selectedSeverity = value ? ErrorSeverity.critical : null
                  ),
                ),
                FilterChip(
                  label: const Text('High'),
                  selected: _selectedSeverity == ErrorSeverity.high,
                  onSelected: (value) => setState(() =>
                    _selectedSeverity = value ? ErrorSeverity.high : null
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentErrorsList(List<ErrorReport> errors) {
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

    if (_showUnresolvedOnly) {
      filteredErrors = filteredErrors.where((e) => !e.resolved).toList();
    }

    // Apply sorting
    filteredErrors = _sortErrors(filteredErrors);

    // Apply pagination
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, filteredErrors.length);
    final paginatedErrors = filteredErrors.sublist(startIndex, endIndex);

    if (filteredErrors.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                errors.isEmpty ? Icons.info_outline : Icons.check_circle_outline,
                size: 48,
                color: errors.isEmpty ? Colors.blue : Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                errors.isEmpty ? 'No error data available' : 'No errors found',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                errors.isEmpty
                    ? 'No error data has been collected yet. You can populate demo data to see how the dashboard works.'
                    : 'Great! Your application is running smoothly.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              if (errors.isEmpty) ...[
                const SizedBox(height: 24),
                _isPopulatingDemoData
                    ? const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Populating demo data...', style: TextStyle(fontSize: 14)),
                        ],
                      )
                    : ElevatedButton.icon(
                        onPressed: _populateDemoErrorData,
                        icon: const Icon(Icons.data_saver_on),
                        label: const Text('Populate Demo Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                const SizedBox(height: 12),
                Text(
                  'This will create 50 sample error reports for demonstration purposes.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Errors (${filteredErrors.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
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
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showErrorActions(context, filteredErrors),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...paginatedErrors.map((error) => _buildCompactErrorCard(error)),
          if (filteredErrors.length > _pageSize)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page ${_currentPage + 1} of ${(filteredErrors.length / _pageSize).ceil()}'),
                  TextButton(
                    onPressed: endIndex < filteredErrors.length ? () => setState(() => _currentPage++) : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
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

  void _showErrorCategoriesPopup(ErrorStatistics stats) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: DefaultTabController(
            length: ErrorCategory.values.length + 1, // +1 for "All" tab
            child: Column(
              children: [
                AppBar(
                  title: const Text('Error Messages by Category'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () {
                        Navigator.pop(context);
                        _showExportDialog();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                  bottom: TabBar(
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'All'),
                      ...ErrorCategory.values.map((cat) => Tab(
                        text: cat.toString().split('.').last,
                      )),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAllErrorsTab(stats),
                      ...ErrorCategory.values.map((cat) => _buildCategoryErrorsTab(cat, stats)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllErrorsTab(ErrorStatistics stats) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (stats.topErrorMessages.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No error messages found'),
            ),
          )
        else
          ...stats.topErrorMessages.asMap().entries.map((entry) {
            final index = entry.key;
            final message = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.search, size: 18),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _searchQuery = message;
                      _searchController.text = message;
                    });
                  },
                  tooltip: 'Search for this error',
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCategoryErrorsTab(ErrorCategory category, ErrorStatistics stats) {
    // This would require additional data from the service to show errors by category
    // For now, show a placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(category),
            size: 48,
            color: _getCategoryColor(category),
          ),
          const SizedBox(height: 16),
          Text(
            '${category.toString().split('.').last} Errors',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Count: ${stats.errorsByCategory[category.toString().split('.').last] ?? 0}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedCategory = category;
              });
            },
            child: const Text('Filter by this category'),
          ),
        ],
      ),
    );
  }

  void _showErrorActions(BuildContext context, List<ErrorReport> errors) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Error Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportErrorsToCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as JSON'),
              onTap: () {
                Navigator.pop(context);
                _exportErrorsToJSON();
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('Clear Resolved'),
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
          ],
        ),
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
          backgroundColor: _getSeverityColor(error.severity).withValues(alpha: 0.2),
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
                color: _getCategoryColor(error.category).withValues(alpha: 0.1),
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
              color: Colors.grey.withValues(alpha: 0.1),
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

  Future<void> _showClearDemoDataDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Demo Data'),
        content: const Text(
          'This will delete all demo error data from the database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              setState(() {
                _isLoading = true;
              });

              try {
                final demoService = ErrorDemoDataService();
                await demoService.clearDemoErrors();

                // Refresh the data to show the changes
                ref.invalidate(errorStatisticsProvider);
                ref.invalidate(errorsStreamProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Demo data cleared successfully'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Failed to clear demo data: $e')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Demo Data'),
          ),
        ],
      ),
    );
  }
}