// lib/features/admin/presentation/screens/project_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../projects/presentation/providers/projects_provider.dart' as project_providers;

class ProjectAnalyticsScreen extends ConsumerStatefulWidget {
  const ProjectAnalyticsScreen({super.key});

  @override
  ConsumerState<ProjectAnalyticsScreen> createState() => _ProjectAnalyticsScreenState();
}

class _ProjectAnalyticsScreenState extends ConsumerState<ProjectAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Sales Performance', icon: Icon(Icons.people, size: 20)),
            Tab(text: 'Client Analytics', icon: Icon(Icons.business, size: 20)),
            Tab(text: 'All Projects', icon: Icon(Icons.list, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildSalesPerformanceTab(),
          _buildClientAnalyticsTab(),
          _buildAllProjectsTab(),
        ],
      ),
    );
  }

  // Tab 1: Overview
  Widget _buildOverviewTab() {
    final projectsAsync = ref.watch(project_providers.allProjectsProvider);

    return projectsAsync.when(
      data: (projects) {
        // Calculate KPIs
        final totalProjects = projects.length;
        final activeProjects = projects.where((p) => p.status == 'active').length;
        final completedProjects = projects.where((p) => p.status == 'completed').length;
        final totalValue = projects.fold<double>(
          0,
          (sum, p) => sum + (p.estimatedValue ?? 0),
        );

        // Status distribution
        final statusCounts = <String, int>{};
        for (final project in projects) {
          statusCounts[project.status] = (statusCounts[project.status] ?? 0) + 1;
        }

        // Monthly projects trend (last 6 months)
        final monthlyProjects = <String, int>{};
        final now = DateTime.now();
        for (int i = 5; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i);
          final monthKey = DateFormat('MMM').format(month);
          final count = projects.where((p) {
            return p.createdAt.year == month.year && p.createdAt.month == month.month;
          }).length;
          monthlyProjects[monthKey] = count;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards
              _buildKPISection(
                totalProjects: totalProjects,
                activeProjects: activeProjects,
                completedProjects: completedProjects,
                totalValue: totalValue,
              ),

              const SizedBox(height: 24),

              // Charts Row
              ResponsiveHelper.isDesktop(context)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTrendChart(monthlyProjects)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatusPieChart(statusCounts)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildTrendChart(monthlyProjects),
                        const SizedBox(height: 16),
                        _buildStatusPieChart(statusCounts),
                      ],
                    ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        AppLogger.error('Error loading project analytics', error: error);
        return Center(child: Text('Error: $error'));
      },
    );
  }

  Widget _buildKPISection({
    required int totalProjects,
    required int activeProjects,
    required int completedProjects,
    required double totalValue,
  }) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    final kpis = [
      _KPIData(
        title: 'Total Projects',
        value: totalProjects.toString(),
        icon: Icons.folder,
        color: Colors.blue,
      ),
      _KPIData(
        title: 'Active',
        value: activeProjects.toString(),
        icon: Icons.play_circle,
        color: Colors.green,
      ),
      _KPIData(
        title: 'Completed',
        value: completedProjects.toString(),
        icon: Icons.check_circle,
        color: Colors.purple,
      ),
      _KPIData(
        title: 'Total Value',
        value: _currencyFormat.format(totalValue),
        icon: Icons.attach_money,
        color: Colors.orange,
      ),
    ];

    int crossAxisCount = 2;
    if (isDesktop) {
      crossAxisCount = 4;
    } else if (isTablet) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return _buildKPICard(
          title: kpi.title,
          value: kpi.value,
          icon: kpi.icon,
          color: kpi.color,
        );
      },
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(Map<String, int> monthlyProjects) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Projects Trend (Last 6 Months)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final months = monthlyProjects.keys.toList();
                          if (value.toInt() >= 0 && value.toInt() < months.length) {
                            return Text(months[value.toInt()]);
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: monthlyProjects.values
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPieChart(Map<String, int> statusCounts) {
    final colors = {
      'planning': Colors.grey,
      'active': Colors.green,
      'completed': Colors.blue,
      'on-hold': Colors.orange,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Projects by Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: statusCounts.entries.map((entry) {
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n${entry.value}',
                      color: colors[entry.key] ?? Colors.grey,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 2: Sales Performance
  Widget _buildSalesPerformanceTab() {
    final projectsAsync = ref.watch(project_providers.allProjectsProvider);

    return projectsAsync.when(
      data: (projects) {
        // Group projects by user
        final projectsByUser = <String, List<Project>>{};
        for (final project in projects) {
          projectsByUser.putIfAbsent(project.userId, () => []).add(project);
        }

        // Calculate user stats
        final userStats = projectsByUser.entries.map((entry) {
          final userProjects = entry.value;
          final totalValue = userProjects.fold<double>(
            0,
            (sum, p) => sum + (p.estimatedValue ?? 0),
          );
          final activeCount = userProjects.where((p) => p.status == 'active').length;
          final completedCount = userProjects.where((p) => p.status == 'completed').length;

          return {
            'userId': entry.key,
            'projectCount': userProjects.length,
            'totalValue': totalValue,
            'activeCount': activeCount,
            'completedCount': completedCount,
          };
        }).toList();

        // Sort by total value descending
        userStats.sort((a, b) => (b['totalValue'] as double).compareTo(a['totalValue'] as double));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userStats.length,
          itemBuilder: (context, index) {
            final stats = userStats[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text('${index + 1}'),
                ),
                title: Text('User ${stats['userId']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projects: ${stats['projectCount']}'),
                    Text('Active: ${stats['activeCount']} | Completed: ${stats['completedCount']}'),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Value', style: TextStyle(fontSize: 10)),
                    Text(
                      _currencyFormat.format(stats['totalValue']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // Tab 3: Client Analytics
  Widget _buildClientAnalyticsTab() {
    final topClientsAsync = ref.watch(project_providers.topClientsByProjectsProvider(10));

    return topClientsAsync.when(
      data: (topClients) {
        if (topClients.isEmpty) {
          return const Center(child: Text('No client data available'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: topClients.length,
          itemBuilder: (context, index) {
            final client = topClients[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text('${index + 1}'),
                ),
                title: Text(client['clientName'] as String),
                subtitle: Text('Projects: ${client['projectCount']}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Value', style: TextStyle(fontSize: 10)),
                    Text(
                      _currencyFormat.format(client['totalValue']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // Tab 4: All Projects
  Widget _buildAllProjectsTab() {
    final projectsAsync = ref.watch(project_providers.allProjectsProvider);

    return projectsAsync.when(
      data: (projects) {
        return Column(
          children: [
            // Export Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _exportAllProjects(projects),
                    icon: const Icon(Icons.download),
                    label: const Text('Export to Excel'),
                  ),
                ],
              ),
            ),

            // Projects Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Project Name')),
                      DataColumn(label: Text('Client')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Location')),
                      DataColumn(label: Text('Estimated Value')),
                      DataColumn(label: Text('Created')),
                    ],
                    rows: projects.map((project) {
                      return DataRow(cells: [
                        DataCell(Text(project.name)),
                        DataCell(Text(project.clientName)),
                        DataCell(Text(project.statusDisplay)),
                        DataCell(Text(project.location)),
                        DataCell(Text(
                          project.estimatedValue != null
                              ? _currencyFormat.format(project.estimatedValue)
                              : 'N/A',
                        )),
                        DataCell(Text(_dateFormat.format(project.createdAt))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _exportAllProjects(List<Project> projects) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Excel export...')),
      );

      final bytes = await ExportService.generateProjectsExcel(projects);
      final filename = 'all_projects_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await DownloadHelper.downloadFile(bytes: bytes, filename: filename);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${projects.length} projects')),
        );
      }
    } catch (e) {
      AppLogger.error('Error exporting projects', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _KPIData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _KPIData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
