// lib/features/projects/presentation/screens/project_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../quotes/presentation/screens/quote_detail_screen.dart';
import '../widgets/project_form_dialog.dart';

// Provider for project quotes
final projectQuotesProvider = StreamProvider.family.autoDispose<List<Quote>, String>((ref, projectId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final database = FirebaseDatabase.instance;
  return database
      .ref('quotes/${user.uid}')
      .orderByChild('projectId')
      .equalTo(projectId)
      .onValue
      .map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return [];

    final quotesMap = event.snapshot.value as Map;
    return quotesMap.entries.map((entry) {
      final quoteData = Map<String, dynamic>.from(entry.value);
      quoteData['id'] = entry.key;
      return Quote.fromMap(quoteData);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailScreen({
    super.key,
    required this.project,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dateFormatter = DateFormat('MMM d, yyyy');
  final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'on-hold':
        return Colors.orange;
      case 'planning':
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.play_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'on-hold':
        return Icons.pause_circle_filled;
      case 'planning':
      default:
        return Icons.article;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(projectQuotesProvider(widget.project.id));
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(widget.project.status);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Project Info
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: theme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(widget.project.status),
                                size: 18,
                                color: statusColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.project.statusDisplay,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Project Name
                        Text(
                          widget.project.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Client Name
                        Row(
                          children: [
                            const Icon(Icons.business, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              widget.project.clientName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Location
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              widget.project.location,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Person in Charge
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              'Manager: ${widget.project.personInCharge}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                        if (widget.project.estimatedValue != null) ...[
                          const SizedBox(height: 8),
                          // Estimated Value
                          Row(
                            children: [
                              const Icon(Icons.attach_money, size: 16, color: Colors.white70),
                              Text(
                                'Est. Value: ${currencyFormatter.format(widget.project.estimatedValue)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => ProjectFormDialog(project: widget.project),
                  ).then((result) {
                    if (result == true && mounted) {
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pop(); // Go back to refresh the data
                    }
                  });
                },
              ),
            ],
          ),

          // Project Metrics
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: quotesAsync.when(
                data: (quotes) {
                  final totalValue = quotes.fold<double>(
                    0,
                    (sum, quote) => sum + quote.total,
                  );
                  final avgQuoteValue = quotes.isEmpty ? 0 : totalValue / quotes.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Overview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildMetricCard(
                            'Total Quotes',
                            '${quotes.length}',
                            Icons.description,
                            Colors.blue,
                          ),
                          _buildMetricCard(
                            'Total Value',
                            currencyFormatter.format(totalValue),
                            Icons.attach_money,
                            Colors.green,
                          ),
                          _buildMetricCard(
                            'Avg Quote',
                            currencyFormatter.format(avgQuoteValue),
                            Icons.trending_up,
                            Colors.orange,
                          ),
                          _buildMetricCard(
                            'Created',
                            dateFormatter.format(widget.project.createdAt),
                            Icons.calendar_today,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ),

          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: theme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: theme.primaryColor,
                tabs: const [
                  Tab(text: 'Quotes'),
                  Tab(text: 'Details'),
                  Tab(text: 'Product Lines'),
                ],
              ),
            ),
          ),

          // Tab Views
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Quotes Tab
                quotesAsync.when(
                  data: (quotes) => _buildQuotesTab(quotes),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),

                // Details Tab
                _buildDetailsTab(),

                // Product Lines Tab
                _buildProductLinesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesTab(List<Quote> quotes) {
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No quotes yet for this project', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to create quote with project preselected
                Navigator.pushNamed(
                  context,
                  '/quotes/new',
                  arguments: {'projectId': widget.project.id},
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Quote'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quotes.length,
      itemBuilder: (context, index) {
        final quote = quotes[index];
        final statusColor = _getQuoteStatusColor(quote.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                '#${quote.quoteNumber}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text('Quote #${quote.quoteNumber}'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quote.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateFormatter.format(quote.createdAt)),
                Row(
                  children: [
                    Text(
                      currencyFormatter.format(quote.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${quote.items.length} items',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuoteDetailScreen(quoteId: quote.id ?? ''),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notes
          if (widget.project.notes != null && widget.project.notes!.isNotEmpty) ...[
            _buildDetailSection(
              'Notes',
              widget.project.notes!,
              Icons.note,
            ),
            const SizedBox(height: 16),
          ],

          // Timeline
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Timeline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.project.startDate != null)
                    _buildTimelineItem(
                      'Start Date',
                      dateFormatter.format(widget.project.startDate!),
                      Icons.play_arrow,
                      Colors.green,
                    ),
                  if (widget.project.completionDate != null)
                    _buildTimelineItem(
                      'Completion Date',
                      dateFormatter.format(widget.project.completionDate!),
                      Icons.stop,
                      Colors.red,
                    ),
                  _buildTimelineItem(
                    'Created',
                    dateFormatter.format(widget.project.createdAt),
                    Icons.add_circle,
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductLinesTab() {
    if (widget.project.productLines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No product lines added', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.project.productLines.length,
      itemBuilder: (context, index) {
        final productLine = widget.project.productLines[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: const Icon(Icons.category),
            ),
            title: Text(productLine),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getQuoteStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}