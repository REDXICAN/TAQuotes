// lib/core/widgets/kpi_card_example.dart
/// Example demonstrating usage of KPI card widgets across different scenarios
library;

import 'package:flutter/material.dart';
import 'kpi_card.dart';
import 'package:intl/intl.dart';

/// Example screen showing all KPI card variations
class KPICardExampleScreen extends StatelessWidget {
  const KPICardExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final numberFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Card Examples'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example 1: Basic KPI Card Grid
            const Text(
              '1. Basic KPI Card Grid (Auto-Responsive)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            KPICardGrid(
              children: [
                KPICard(
                  title: 'Total Revenue',
                  value: currencyFormat.format(125000),
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
                KPICard(
                  title: 'Total Quotes',
                  value: numberFormat.format(1250),
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
                KPICard(
                  title: 'Active Users',
                  value: numberFormat.format(847),
                  icon: Icons.people,
                  color: Colors.orange,
                ),
                KPICard(
                  title: 'Conversion Rate',
                  value: '84.4%',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Example 2: KPI Cards with Trend Indicators
            const Text(
              '2. KPI Cards with Trend Indicators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            KPICardGrid(
              crossAxisCount: 2,
              children: [
                KPICard(
                  title: 'Monthly Revenue',
                  value: currencyFormat.format(45234),
                  icon: Icons.analytics,
                  color: Colors.green,
                  subtitle: TrendIndicator(
                    value: 12.5,
                    comparison: 'vs last month',
                  ).toString(),
                ),
                KPICard(
                  title: 'Avg Quote Value',
                  value: currencyFormat.format(2777),
                  icon: Icons.attach_money,
                  color: Colors.blue,
                  subtitle: TrendIndicator(
                    value: 8.3,
                    comparison: 'vs last month',
                  ).toString(),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Example 3: Tappable KPI Cards
            const Text(
              '3. Interactive KPI Cards (Tap to View Details)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            KPICardGrid(
              crossAxisCount: 3,
              children: [
                KPICard(
                  title: 'Pending Quotes',
                  value: '23',
                  icon: Icons.pending,
                  color: Colors.amber,
                  onTap: () => _showSnackbar(context, 'Opening pending quotes...'),
                ),
                KPICard(
                  title: 'New Clients',
                  value: '12',
                  icon: Icons.person_add,
                  color: Colors.teal,
                  onTap: () => _showSnackbar(context, 'Opening new clients...'),
                ),
                KPICard(
                  title: 'Alerts',
                  value: '5',
                  icon: Icons.notifications,
                  color: Colors.red,
                  onTap: () => _showSnackbar(context, 'Opening alerts...'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Example 4: Horizontal KPI Cards (Compact Layout)
            const Text(
              '4. Horizontal KPI Cards (List View Style)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            KPICardHorizontal(
              title: 'Total Products',
              value: numberFormat.format(835),
              icon: Icons.inventory,
              color: Colors.indigo,
            ),
            const SizedBox(height: 12),
            KPICardHorizontal(
              title: 'Low Stock Items',
              value: '12',
              icon: Icons.warning,
              color: Colors.orange,
              subtitle: 'Requires attention',
            ),
            const SizedBox(height: 12),
            KPICardHorizontal(
              title: 'Warehouse Locations',
              value: '6',
              icon: Icons.warehouse,
              color: Colors.cyan,
            ),
            const SizedBox(height: 32),

            // Example 5: Loading State
            const Text(
              '5. Loading State',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            KPICardGrid(
              crossAxisCount: 2,
              children: const [
                KPICard(
                  title: 'Loading Data...',
                  value: '',
                  icon: Icons.hourglass_empty,
                  color: Colors.grey,
                  isLoading: true,
                ),
                KPICardHorizontal(
                  title: 'Fetching Metrics...',
                  value: '',
                  icon: Icons.sync,
                  color: Colors.grey,
                  isLoading: true,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Example 6: Negative Trend (Cost Reduction)
            const Text(
              '6. Negative Trend (Good for Cost Metrics)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            KPICardGrid(
              crossAxisCount: 2,
              children: [
                KPICard(
                  title: 'Operating Costs',
                  value: currencyFormat.format(8500),
                  icon: Icons.trending_down,
                  color: Colors.green,
                  subtitle: TrendIndicator(
                    value: -15.2,
                    comparison: 'vs last quarter',
                    invertColors: true, // Make negative = green
                  ).toString(),
                ),
                KPICard(
                  title: 'Support Tickets',
                  value: '34',
                  icon: Icons.support_agent,
                  color: Colors.green,
                  subtitle: TrendIndicator(
                    value: -22.5,
                    comparison: 'vs last month',
                    invertColors: true,
                  ).toString(),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Example 7: Custom Grid Configuration
            const Text(
              '7. Custom Grid (3 columns, custom aspect ratio)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            KPICardGrid(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                KPICard(
                  title: 'Metric A',
                  value: '123',
                  icon: Icons.assessment,
                  color: Colors.pink,
                ),
                KPICard(
                  title: 'Metric B',
                  value: '456',
                  icon: Icons.bar_chart,
                  color: Colors.deepPurple,
                ),
                KPICard(
                  title: 'Metric C',
                  value: '789',
                  icon: Icons.pie_chart,
                  color: Colors.brown,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Integration Example
            const Text(
              'Integration Example: Replace Existing Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Before:\n'
              '_buildStatCard("Total Products", "835", Icons.inventory, Colors.blue)\n\n'
              'After:\n'
              'KPICard(\n'
              '  title: "Total Products",\n'
              '  value: "835",\n'
              '  icon: Icons.inventory,\n'
              '  color: Colors.blue,\n'
              ')',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
