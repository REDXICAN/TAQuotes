// lib/features/admin/presentation/widgets/mock_analytics_generator_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../scripts/generate_mock_analytics_data.dart';
import '../../../../core/services/app_logger.dart';

/// Widget for admin panel to generate mock analytics data
class MockAnalyticsGeneratorWidget extends ConsumerStatefulWidget {
  const MockAnalyticsGeneratorWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<MockAnalyticsGeneratorWidget> createState() => _MockAnalyticsGeneratorWidgetState();
}

class _MockAnalyticsGeneratorWidgetState extends ConsumerState<MockAnalyticsGeneratorWidget> {
  bool _isGenerating = false;
  bool _isCleaning = false;
  String _statusMessage = '';
  Map<String, dynamic> _lastSummary = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsSummary();
  }

  Future<void> _loadAnalyticsSummary() async {
    try {
      final generator = MockAnalyticsDataGenerator();
      final summary = await generator.getAnalyticsSummary();
      setState(() {
        _lastSummary = summary;
      });
    } catch (e) {
      AppLogger.error('Error loading analytics summary', error: e);
    }
  }

  Future<void> _generateMockData({bool forceRegenerate = false}) async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Starting mock data generation...';
    });

    try {
      final generator = MockAnalyticsDataGenerator();

      final success = await generator.generateMockAnalyticsData(
        skipIfDataExists: !forceRegenerate,
        onProgress: (message) {
          setState(() {
            _statusMessage = message;
          });
        },
      );

      if (success) {
        setState(() {
          _statusMessage = 'Mock data generation completed successfully!';
        });
        await _loadAnalyticsSummary();
        _showSuccessDialog();
      } else {
        setState(() {
          _statusMessage = 'Failed to generate mock data. Check logs for details.';
        });
        _showErrorDialog('Failed to generate mock data');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _cleanupMockData() async {
    final confirmed = await _showConfirmationDialog(
      'Cleanup Mock Data',
      'Are you sure you want to remove all mock analytics data? This action cannot be undone.',
    );

    if (!confirmed) return;

    setState(() {
      _isCleaning = true;
      _statusMessage = 'Cleaning up mock data...';
    });

    try {
      final generator = MockAnalyticsDataGenerator();
      final success = await generator.cleanupMockData();

      if (success) {
        setState(() {
          _statusMessage = 'Mock data cleanup completed successfully!';
          _lastSummary = {};
        });
        _showSuccessDialog('All mock data has been removed successfully.');
      } else {
        setState(() {
          _statusMessage = 'Failed to cleanup mock data. Check logs for details.';
        });
        _showErrorDialog('Failed to cleanup mock data');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during cleanup: ${e.toString()}';
      });
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isCleaning = false;
      });
    }
  }

  void _showSuccessDialog([String? message]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message ?? _statusMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingData = _lastSummary.isNotEmpty && (_lastSummary['mockUsers'] as int? ?? 0) > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Mock Analytics Data Generator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isGenerating || _isCleaning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            const Text(
              'Generate comprehensive mock data for testing analytics features including users, clients, quotes, projects, and performance metrics.',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            // Data Overview (if exists)
            if (hasExistingData) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Mock Data:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mock Users: ${_lastSummary['mockUsers'] ?? 0}'),
                        Text('Total Quotes: ${_lastSummary['totalQuotes'] ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Revenue: \$${(_lastSummary['totalRevenue'] as double? ?? 0.0).toStringAsFixed(0)}',
                        ),
                        Text(
                          'Avg per User: \$${(_lastSummary['averageRevenuePerUser'] as double? ?? 0.0).toStringAsFixed(0)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status Message
            if (_statusMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    if (_isGenerating || _isCleaning)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                // Generate Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating || _isCleaning
                        ? null
                        : () => _generateMockData(),
                    icon: const Icon(Icons.add_chart),
                    label: Text(hasExistingData ? 'Add More Data' : 'Generate Mock Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Regenerate Button (if data exists)
                if (hasExistingData) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating || _isCleaning
                          ? null
                          : () => _generateMockData(forceRegenerate: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Cleanup Button (if data exists)
                if (hasExistingData)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating || _isCleaning
                          ? null
                          : _cleanupMockData,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Cleanup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Features List
            ExpansionTile(
              title: const Text('Generated Data Includes:'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FeatureItem(
                        icon: Icons.people,
                        title: '10 Mock Users',
                        description: 'Sales reps, distributors, and admins with different experience levels',
                      ),
                      _FeatureItem(
                        icon: Icons.business,
                        title: '2-3 Clients per User',
                        description: 'Realistic businesses (restaurants, hotels, supermarkets, etc.)',
                      ),
                      _FeatureItem(
                        icon: Icons.assignment_turned_in,
                        title: '1-2 Closed Quotes per User',
                        description: 'Won deals with realistic revenue for performance metrics',
                      ),
                      _FeatureItem(
                        icon: Icons.assignment,
                        title: '3 In-Progress Quotes per User',
                        description: 'Active pipeline showing competitive analysis',
                      ),
                      _FeatureItem(
                        icon: Icons.build,
                        title: 'Spare Parts Integration',
                        description: '30% of quotes include spare parts for variety',
                      ),
                      _FeatureItem(
                        icon: Icons.work,
                        title: 'Linked Projects',
                        description: 'Projects connected to clients for project-based analytics',
                      ),
                      _FeatureItem(
                        icon: Icons.attach_money,
                        title: 'Realistic Pricing',
                        description: 'Equipment pricing based on actual categories and user experience',
                      ),
                      _FeatureItem(
                        icon: Icons.analytics,
                        title: 'Performance Metrics',
                        description: 'Conversion rates, revenue tracking, and user scoring',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}