// lib/features/admin/presentation/screens/kpi_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/models/models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/download_helper.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:typed_data';

// Provider for KPI data
final kpiDataProvider = StreamProvider.autoDispose<KPIData>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(KPIData.empty());

  final database = FirebaseDatabase.instance;

  return Stream.periodic(const Duration(seconds: 30), (_) => null)
      .asyncMap((_) async {
    try {
      // Fetch quotes
      final quotesSnapshot = await database.ref('quotes/${user.uid}').get();
      final List<Quote> quotes = [];

      if (quotesSnapshot.exists && quotesSnapshot.value != null) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        for (final entry in quotesData.entries) {
          final quoteData = Map<String, dynamic>.from(entry.value);
          quoteData['id'] = entry.key;

          quotes.add(Quote(
            id: quoteData['id'],
            clientId: quoteData['client_id'],
            quoteNumber: quoteData['quote_number'],
            subtotal: (quoteData['subtotal'] ?? 0).toDouble(),
            tax: (quoteData['tax_amount'] ?? 0).toDouble(),
            total: (quoteData['total_amount'] ?? 0).toDouble(),
            status: quoteData['status'] ?? 'draft',
            archived: quoteData['archived'] ?? false,
            createdAt: quoteData['created_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(quoteData['created_at'])
                : DateTime.now(),
            createdBy: quoteData['created_by'] ?? user.uid,
            items: [],
          ));
        }
      }

      // Fetch clients
      final clientsSnapshot = await database.ref('clients/${user.uid}').get();
      int totalClients = 0;

      if (clientsSnapshot.exists && clientsSnapshot.value != null) {
        final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);
        totalClients = clientsData.length;
      }

      // Calculate KPIs
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month);
      final lastMonth = DateTime(now.year, now.month - 1);

      final thisMonthQuotes = quotes.where((q) =>
        q.createdAt.isAfter(thisMonth) &&
        q.createdAt.isBefore(now)
      ).toList();

      final lastMonthQuotes = quotes.where((q) =>
        q.createdAt.isAfter(lastMonth) &&
        q.createdAt.isBefore(thisMonth)
      ).toList();

      // Revenue metrics
      final totalRevenue = quotes.fold<double>(0, (sum, q) => sum + q.total);
      final monthlyRevenue = thisMonthQuotes.fold<double>(0, (sum, q) => sum + q.total);
      final lastMonthRevenue = lastMonthQuotes.fold<double>(0, (sum, q) => sum + q.total);

      // Quote metrics
      final totalQuotes = quotes.length;
      final acceptedQuotes = quotes.where((q) => q.status == 'accepted').length;
      final conversionRate = totalQuotes > 0 ? (acceptedQuotes / totalQuotes) * 100 : 0;

      // Average metrics
      final avgQuoteValue = totalQuotes > 0 ? totalRevenue / totalQuotes : 0;
      final avgResponseTime = _calculateAverageResponseTime(quotes);

      // Growth metrics
      final revenueGrowth = lastMonthRevenue > 0
        ? ((monthlyRevenue - lastMonthRevenue) / lastMonthRevenue) * 100
        : 0;

      final quotesGrowth = lastMonthQuotes.isNotEmpty
        ? ((thisMonthQuotes.length - lastMonthQuotes.length) / lastMonthQuotes.length) * 100
        : 0;

      return KPIData(
        totalRevenue: totalRevenue,
        monthlyRevenue: monthlyRevenue,
        revenueGrowth: revenueGrowth.toDouble(),
        totalQuotes: totalQuotes,
        monthlyQuotes: thisMonthQuotes.length,
        quotesGrowth: quotesGrowth.toDouble(),
        conversionRate: conversionRate.toDouble(),
        avgQuoteValue: avgQuoteValue.toDouble(),
        avgResponseTime: avgResponseTime,
        totalClients: totalClients,
        topProducts: _getTopProducts(quotes),
        revenueByMonth: _getRevenueByMonth(quotes),
        quotesByStatus: _getQuotesByStatus(quotes),
      );
    } catch (e) {
      AppLogger.error('Error loading KPI data', error: e);
      return KPIData.empty();
    }
  });
});

class KPIData {
  final double totalRevenue;
  final double monthlyRevenue;
  final double revenueGrowth;
  final int totalQuotes;
  final int monthlyQuotes;
  final double quotesGrowth;
  final double conversionRate;
  final double avgQuoteValue;
  final double avgResponseTime;
  final int totalClients;
  final List<ProductKPI> topProducts;
  final Map<String, double> revenueByMonth;
  final Map<String, int> quotesByStatus;

  KPIData({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.revenueGrowth,
    required this.totalQuotes,
    required this.monthlyQuotes,
    required this.quotesGrowth,
    required this.conversionRate,
    required this.avgQuoteValue,
    required this.avgResponseTime,
    required this.totalClients,
    required this.topProducts,
    required this.revenueByMonth,
    required this.quotesByStatus,
  });

  factory KPIData.empty() => KPIData(
    totalRevenue: 0,
    monthlyRevenue: 0,
    revenueGrowth: 0,
    totalQuotes: 0,
    monthlyQuotes: 0,
    quotesGrowth: 0,
    conversionRate: 0,
    avgQuoteValue: 0,
    avgResponseTime: 0,
    totalClients: 0,
    topProducts: [],
    revenueByMonth: {},
    quotesByStatus: {},
  );
}

class ProductKPI {
  final String name;
  final int quantity;
  final double revenue;

  ProductKPI({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

double _calculateAverageResponseTime(List<Quote> quotes) {
  // For now, return a placeholder
  // In a real implementation, you'd track when quotes are sent vs created
  return 24.0; // hours
}

List<ProductKPI> _getTopProducts(List<Quote> quotes) {
  // This would need actual quote items data
  // For now, return empty list
  return [];
}

Map<String, double> _getRevenueByMonth(List<Quote> quotes) {
  final Map<String, double> revenue = {};
  final dateFormat = DateFormat('MMM yyyy');

  for (final quote in quotes) {
    final monthKey = dateFormat.format(quote.createdAt);
    revenue[monthKey] = (revenue[monthKey] ?? 0) + quote.total;
  }

  return revenue;
}

Map<String, int> _getQuotesByStatus(List<Quote> quotes) {
  final Map<String, int> statusCount = {};

  for (final quote in quotes) {
    final status = quote.status;
    statusCount[status] = (statusCount[status] ?? 0) + 1;
  }

  return statusCount;
}

class KPIDashboardScreen extends ConsumerStatefulWidget {
  const KPIDashboardScreen({super.key});

  @override
  ConsumerState<KPIDashboardScreen> createState() => _KPIDashboardScreenState();
}

class _KPIDashboardScreenState extends ConsumerState<KPIDashboardScreen> {
  final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final percentFormatter = NumberFormat.percentPattern();

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(kpiDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Dashboard'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
            onPressed: () => _exportReport(kpiAsync.value ?? KPIData.empty()),
          ),
        ],
      ),
      body: kpiAsync.when(
        data: (kpi) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue KPIs
              Text(
                'Revenue Metrics',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildKPICard(
                    'Total Revenue',
                    currencyFormatter.format(kpi.totalRevenue),
                    Icons.monetization_on,
                    Colors.green,
                    null,
                  ),
                  _buildKPICard(
                    'Monthly Revenue',
                    currencyFormatter.format(kpi.monthlyRevenue),
                    Icons.calendar_today,
                    Colors.blue,
                    kpi.revenueGrowth,
                  ),
                  _buildKPICard(
                    'Avg Quote Value',
                    currencyFormatter.format(kpi.avgQuoteValue),
                    Icons.trending_up,
                    Colors.orange,
                    null,
                  ),
                  _buildKPICard(
                    'Total Clients',
                    '${kpi.totalClients}',
                    Icons.people,
                    Colors.purple,
                    null,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Quote KPIs
              Text(
                'Quote Metrics',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildKPICard(
                    'Total Quotes',
                    '${kpi.totalQuotes}',
                    Icons.description,
                    Colors.indigo,
                    null,
                  ),
                  _buildKPICard(
                    'Monthly Quotes',
                    '${kpi.monthlyQuotes}',
                    Icons.calendar_month,
                    Colors.teal,
                    kpi.quotesGrowth,
                  ),
                  _buildKPICard(
                    'Conversion Rate',
                    '${kpi.conversionRate.toStringAsFixed(1)}%',
                    Icons.check_circle,
                    Colors.green,
                    null,
                  ),
                  _buildKPICard(
                    'Response Time',
                    '${kpi.avgResponseTime.toStringAsFixed(1)}h',
                    Icons.speed,
                    Colors.amber,
                    null,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Revenue Chart
              if (kpi.revenueByMonth.isNotEmpty) ...[
                Text(
                  'Revenue Trend',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 250,
                      child: _buildRevenueChart(kpi.revenueByMonth),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Quote Status Distribution
              if (kpi.quotesByStatus.isNotEmpty) ...[
                Text(
                  'Quote Status Distribution',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: kpi.quotesByStatus.entries.map((entry) {
                        final percentage = (entry.value / kpi.totalQuotes) * 100;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(entry.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text('${entry.value} (${percentage.toStringAsFixed(1)}%)'),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    IconData icon,
    Color color,
    double? growth,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (growth != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    growth >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: growth >= 0 ? Colors.green : Colors.red,
                  ),
                  Text(
                    '${growth.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: growth >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
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

  Widget _buildRevenueChart(Map<String, double> revenueByMonth) {
    final sortedEntries = revenueByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final lastSixMonths = sortedEntries.length > 6
      ? sortedEntries.sublist(sortedEntries.length - 6)
      : sortedEntries;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value / 1000).toStringAsFixed(0)}K',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < lastSixMonths.length) {
                  return Text(
                    lastSixMonths[value.toInt()].key.split(' ')[0],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: lastSixMonths.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'sent':
        return Colors.blue;
      case 'draft':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _exportReport(KPIData kpi) async {
    try {
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['KPI Report'];

      // Add headers
      sheet.appendRow([
        excel.TextCellValue('KPI Report'),
        excel.TextCellValue('Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}'),
      ]);

      sheet.appendRow([]);

      // Revenue Metrics
      sheet.appendRow([excel.TextCellValue('Revenue Metrics')]);
      sheet.appendRow([
        excel.TextCellValue('Total Revenue'),
        excel.DoubleCellValue(kpi.totalRevenue),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Monthly Revenue'),
        excel.DoubleCellValue(kpi.monthlyRevenue),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Revenue Growth'),
        excel.TextCellValue('${kpi.revenueGrowth.toStringAsFixed(1)}%'),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Average Quote Value'),
        excel.DoubleCellValue(kpi.avgQuoteValue),
      ]);

      sheet.appendRow([]);

      // Quote Metrics
      sheet.appendRow([excel.TextCellValue('Quote Metrics')]);
      sheet.appendRow([
        excel.TextCellValue('Total Quotes'),
        excel.IntCellValue(kpi.totalQuotes),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Monthly Quotes'),
        excel.IntCellValue(kpi.monthlyQuotes),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Conversion Rate'),
        excel.TextCellValue('${kpi.conversionRate.toStringAsFixed(1)}%'),
      ]);
      sheet.appendRow([
        excel.TextCellValue('Avg Response Time'),
        excel.TextCellValue('${kpi.avgResponseTime.toStringAsFixed(1)} hours'),
      ]);

      sheet.appendRow([]);

      // Client Metrics
      sheet.appendRow([excel.TextCellValue('Client Metrics')]);
      sheet.appendRow([
        excel.TextCellValue('Total Clients'),
        excel.IntCellValue(kpi.totalClients),
      ]);

      // Generate file
      final excelBytes = excelFile.save();
      if (excelBytes != null) {
        await DownloadHelper.downloadFile(
          bytes: Uint8List.fromList(excelBytes),
          filename: 'KPI_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KPI report exported successfully')),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error exporting KPI report', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}