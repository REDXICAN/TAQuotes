// lib/features/quotes/presentation/screens/quotes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'dart:async';
import '../../../../core/utils/download_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/price_formatter.dart';
import 'package:mailer/mailer.dart';
import 'edit_quote_screen.dart';

// Quotes provider using Realtime Database with real-time updates
final quotesProvider = StreamProvider<List<Quote>>((ref) {
  // Check authentication
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }
  
  final dbService = ref.watch(databaseServiceProvider);
  final database = FirebaseDatabase.instance;

  return database.ref('quotes/${user.uid}').onValue.asyncMap((event) async {
    try {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <Quote>[];
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final quotesList = data.entries.map((e) => {
        ...Map<String, dynamic>.from(e.value),
        'id': e.key,
      }).toList();
      
      // Fetch additional data for each quote
      final List<Quote> quotes = [];

      for (final quoteData in quotesList) {
        // Fetch client data
        Map<String, dynamic>? clientData;
        if (quoteData['client_id'] != null) {
          clientData = await dbService.getClient(quoteData['client_id']);
        }

        // Fetch quote items
        final List<QuoteItem> items = [];
        if (quoteData['quote_items'] != null) {
          final quoteItems = quoteData['quote_items'] is List 
              ? quoteData['quote_items'] as List
              : (quoteData['quote_items'] as Map).values.toList();
              
          for (final itemData in quoteItems) {
            if (itemData is Map) {
              // Fetch product data for each item
              final productData =
                  await dbService.getProduct(itemData['product_id']);
              items.add(QuoteItem(
                productId: itemData['product_id'] ?? '',
                productName: productData?['name'] ?? productData?['description'] ?? 'Unknown Product',
                quantity: itemData['quantity'] ?? 1,
                unitPrice: (itemData['unit_price'] ?? 0).toDouble(),
                total: (itemData['total_price'] ?? 0).toDouble(),
                product: productData != null ? Product.fromMap(productData) : null,
                addedAt: DateTime.now(),
              ));
            }
          }
        }

        quotes.add(Quote(
          id: quoteData['id'],
          clientId: quoteData['client_id'],
          quoteNumber: quoteData['quote_number'],
          subtotal: (quoteData['subtotal'] ?? 0).toDouble(),
          tax: (quoteData['tax_amount'] ?? 0).toDouble(),
          total: (quoteData['total_amount'] ?? 0).toDouble(),
          status: quoteData['status'] ?? 'draft',
          items: items,
          client: clientData != null ? Client.fromMap(clientData) : null,
          createdBy: quoteData['user_id'] ?? '',
          createdAt: quoteData['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(quoteData['created_at'])
              : DateTime.now(),
          projectId: quoteData['project_id'],
          projectName: quoteData['project_name'],
        ));
      }

      // Sort by date (newest first)
      quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return quotes;
    } catch (e) {
      AppLogger.error('Error loading quotes', error: e);
      return <Quote>[];
    }
  });
});

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';
  String? _filterProjectId;
  bool _groupByProject = false;

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Quotes',
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              
              switch (value) {
                case 'pdf':
                  await _exportQuotesToPDF();
                  break;
                case 'xlsx':
                  await _exportQuotesToXLSX(user.uid);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Export as PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'xlsx',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Export as Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.cardColor,
            child: Column(
              children: [
                // Search field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by quote #, company, contact, date...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Filter chips and project controls
                Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Draft', 'draft'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Sent', 'sent'),
                          const SizedBox(width: 16),
                          // Group by project toggle
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _groupByProject = !_groupByProject;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      _groupByProject ? Icons.folder : Icons.folder_outlined,
                                      size: 16,
                                      color: _groupByProject ? theme.primaryColor : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Group by Project',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _groupByProject ? theme.primaryColor : null,
                                        fontWeight: _groupByProject ? FontWeight.bold : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Project filter dropdown
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadProjects(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        final projects = snapshot.data!;
                        
                        return DropdownButtonFormField<String>(
                          value: _filterProjectId,
                          decoration: InputDecoration(
                            labelText: 'Filter by Project',
                            prefixIcon: const Icon(Icons.folder),
                            suffixIcon: _filterProjectId != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _filterProjectId = null;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: theme.inputDecorationTheme.fillColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Projects'),
                            ),
                            ...projects.map((project) {
                              return DropdownMenuItem<String>(
                                value: project['id'],
                                child: Text(project['name'] ?? 'Unnamed Project'),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterProjectId = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quotes list
          Expanded(
            child: quotesAsync.when(
              data: (quotes) {
                // Filter quotes
                var filteredQuotes = quotes;

                if (_filterStatus != 'all') {
                  filteredQuotes =
                      quotes.where((q) => q.status == _filterStatus).toList();
                }

                if (_filterProjectId != null) {
                  filteredQuotes = filteredQuotes.where((q) => q.projectId == _filterProjectId).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredQuotes = filteredQuotes.where((q) {
                    // Search in quote number
                    if (q.quoteNumber?.toLowerCase().contains(query) ?? false) {
                      return true;
                    }
                    
                    // Search in date (format: MMM dd, yyyy)
                    final dateFormat = DateFormat('MMM dd, yyyy');
                    if (dateFormat.format(q.createdAt).toLowerCase().contains(query)) {
                      return true;
                    }
                    
                    // Search in project name
                    if (q.projectName?.toLowerCase().contains(query) ?? false) {
                      return true;
                    }
                    
                    // Search in all client fields
                    if (q.client != null) {
                      final client = q.client!;
                      return client.company.toLowerCase().contains(query) ||
                             client.contactName.toLowerCase().contains(query) ||
                             client.email.toLowerCase().contains(query) ||
                             client.phone.toLowerCase().contains(query) ||
                             (client.address?.toLowerCase().contains(query) ?? false);
                    }
                    
                    return false;
                  }).toList();
                }

                if (filteredQuotes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: theme.iconTheme.color?.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No quotes found',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _filterStatus != 'all'
                              ? 'Try adjusting your filters'
                              : 'Create your first quote from the Cart',
                        ),
                      ],
                    ),
                  );
                }

                // Group quotes by project if enabled
                if (_groupByProject) {
                  // Group quotes by project
                  final Map<String?, List<Quote>> groupedQuotes = {};
                  for (final quote in filteredQuotes) {
                    final projectKey = quote.projectName ?? 'No Project';
                    groupedQuotes[projectKey] ??= [];
                    groupedQuotes[projectKey]!.add(quote);
                  }
                  
                  // Sort groups: named projects first, then 'No Project'
                  final sortedGroups = groupedQuotes.entries.toList()
                    ..sort((a, b) {
                      if (a.key == 'No Project') return 1;
                      if (b.key == 'No Project') return -1;
                      return a.key!.compareTo(b.key!);
                    });
                  
                  return Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveHelper.isMobile(context)
                          ? MediaQuery.of(context).size.width
                          : MediaQuery.of(context).size.width * 0.67,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 8 : 16),
                        itemCount: sortedGroups.length,
                        itemBuilder: (context, groupIndex) {
                          final group = sortedGroups[groupIndex];
                          final projectName = group.key!;
                          final projectQuotes = group.value;
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Project header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                margin: EdgeInsets.only(bottom: 8, top: groupIndex > 0 ? 16 : 0),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder,
                                      size: 20,
                                      color: theme.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        projectName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${projectQuotes.length} quote${projectQuotes.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Project quotes
                              ...projectQuotes.map((quote) => _buildQuoteCard(quote)),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                } else {
                  // Regular list view
                  return Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveHelper.isMobile(context)
                          ? MediaQuery.of(context).size.width  // Full width on mobile
                          : MediaQuery.of(context).size.width * 0.67, // 2/3 of screen width on desktop
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 8 : 16),
                        itemCount: filteredQuotes.length,
                        itemBuilder: (context, index) {
                          final quote = filteredQuotes[index];
                          return _buildQuoteCard(quote);
                        },
                      ),
                    ),
                  );
                }
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading quotes: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(quotesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: theme.chipTheme.backgroundColor,
      selectedColor: theme.primaryColor.withOpacity(0.2),
      checkmarkColor: theme.primaryColor,
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final statusColor = _getStatusColor(quote.status);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width < 900;

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      child: InkWell(
        onTap: () => _showQuoteDetails(quote),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Quote number - make it flexible
                  Flexible(
                    child: Text(
                      '#${quote.quoteNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status chip
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12, 
                      vertical: isMobile ? 2 : 4
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      quote.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: isMobile ? 10 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Client info - with overflow protection
              Row(
                children: [
                  Icon(Icons.business, size: isMobile ? 14 : 16, color: theme.iconTheme.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      quote.client?.company ?? 'Unknown Client',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Project info (if exists)
              if (quote.projectName != null && quote.projectName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.folder, size: isMobile ? 14 : 16, color: theme.primaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        quote.projectName!,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),

              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: isMobile ? 14 : 16, color: theme.iconTheme.color),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(quote.createdAt),
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 12),

              // Items count and total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${quote.items.isEmpty ? "No" : quote.items.length} item${quote.items.length == 1 ? "" : "s"}',
                      style: TextStyle(fontSize: isMobile ? 12 : 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    PriceFormatter.formatPrice(quote.totalAmount),
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),

              // Action buttons - Responsive layout
              SizedBox(height: isMobile ? 8 : 12),
              if (isMobile) 
                // Mobile: Show only essential buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _viewQuote(quote),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                        child: Icon(Icons.visibility, size: 18),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _editQuote(quote),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                        child: Icon(Icons.edit, size: 18, color: Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _emailQuote(quote),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                        child: Icon(Icons.email, size: 18),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _exportQuote(quote, 'pdf'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                        child: Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _exportQuote(quote, 'xlsx'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                        child: Icon(Icons.table_chart, size: 18, color: Colors.green),
                      ),
                    ),
                  ],
                )
              else
                // Tablet/Desktop: Full buttons in grid
                Column(
                  children: [
                    // First row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _viewQuote(quote),
                            icon: Icon(Icons.visibility, size: isTablet ? 14 : 16),
                            label: Text('View', style: TextStyle(fontSize: isTablet ? 12 : 14)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                              minimumSize: Size(0, isTablet ? 32 : 36),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editQuote(quote),
                            icon: Icon(Icons.edit, size: isTablet ? 14 : 16),
                            label: Text('Edit', style: TextStyle(fontSize: isTablet ? 12 : 14)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                              minimumSize: Size(0, isTablet ? 32 : 36),
                              foregroundColor: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _emailQuote(quote),
                            icon: Icon(Icons.email, size: isTablet ? 14 : 16),
                            label: Text('Email', style: TextStyle(fontSize: isTablet ? 12 : 14)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                              minimumSize: Size(0, isTablet ? 32 : 36),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Second row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _exportQuote(quote, 'pdf'),
                            icon: Icon(Icons.picture_as_pdf, size: isTablet ? 14 : 16),
                            label: Text('PDF', style: TextStyle(fontSize: isTablet ? 12 : 14)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                              minimumSize: Size(0, isTablet ? 32 : 36),
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _exportQuote(quote, 'xlsx'),
                            icon: Icon(Icons.table_chart, size: isTablet ? 14 : 16),
                            label: Text('Excel', style: TextStyle(fontSize: isTablet ? 12 : 14)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                              minimumSize: Size(0, isTablet ? 32 : 36),
                              foregroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteQuote(quote),
                            icon: Icon(Icons.delete, size: isTablet ? 14 : 16),
                            label: Text('Delete', style: TextStyle(fontSize: isTablet ? 12 : 14)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                              minimumSize: Size(0, isTablet ? 32 : 36),
                              foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Load all projects for filtering
  Future<List<Map<String, dynamic>>> _loadProjects() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return [];
      
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('projects/${user.uid}').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final projectsMap = Map<String, dynamic>.from(snapshot.value as Map);
        final projects = <Map<String, dynamic>>[];
        
        projectsMap.forEach((key, value) {
          final project = Map<String, dynamic>.from(value);
          project['id'] = key;
          projects.add(project);
        });
        
        // Sort by name
        projects.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
        
        return projects;
      }
      
      return [];
    } catch (e) {
      AppLogger.error('Error loading projects', error: e);
      return [];
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showQuoteDetails(Quote quote) {
    context.push('/quotes/${quote.id}');
  }

  void _viewQuote(Quote quote) {
    _showQuoteDetails(quote);
  }

  void _editQuote(Quote quote) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: EditQuoteScreen(quote: quote),
      ),
    ).then((_) {
      // Refresh quotes after editing
      ref.invalidate(quotesProvider);
    });
  }

  Future<void> _emailQuote(Quote quote) async {
    // Show dialog to get recipient email
    final emailController = TextEditingController(text: quote.client?.email ?? '');
    bool attachPdf = true;
    bool attachExcel = false;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Quote via Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Email',
                  hintText: 'Enter email address',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Attach PDF'),
                subtitle: const Text('Include quote as PDF attachment'),
                value: attachPdf,
                onChanged: (value) => setState(() => attachPdf = value ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Attach Excel'),
                subtitle: const Text('Include quote as Excel spreadsheet'),
                value: attachExcel,
                onChanged: (value) => setState(() => attachExcel = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'email': emailController.text,
                'attachPdf': attachPdf,
                'attachExcel': attachExcel,
              }),
              child: const Text('Send Email'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    
    final email = result['email'] as String;
    final sendPDF = result['attachPdf'] as bool;
    final sendExcel = result['attachExcel'] as bool;
    
    // Track loading dialog state
    bool isLoadingDialogShowing = false;
    
    try {
      // Validate email
      final email = emailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Show loading indicator with proper tracking
      if (mounted) {
        isLoadingDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Sending email...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      
      // Add delay to ensure dialog renders
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Generate PDF with error handling
      Uint8List? pdfBytes;
      if (sendPDF) {
        try {
          pdfBytes = await ExportService.generateQuotePDF(quote.id ?? '');
        } catch (pdfError) {
          // Close loading dialog
          if (mounted && isLoadingDialogShowing) {
            Navigator.of(context, rootNavigator: true).pop();
            isLoadingDialogShowing = false;
          }
          throw Exception('Failed to generate PDF: $pdfError');
        }
      }
      
      // Generate Excel if requested
      Uint8List? excelBytes;
      if (sendExcel) {
        try {
          // Use ExportService instead of local method
          excelBytes = await ExportService.generateQuoteExcel(quote.id ?? '');
        } catch (excelError) {
          // Close loading dialog
          if (mounted && isLoadingDialogShowing) {
            Navigator.of(context, rootNavigator: true).pop();
            isLoadingDialogShowing = false;
          }
          throw Exception('Failed to generate Excel: $excelError');
        }
      }
      
      // Prepare products list for email
      List<Map<String, dynamic>> productsList = [];
      for (var item in quote.items) {
        productsList.add({
          'name': item.productName ?? 'Unknown Product',
          'sku': item.product?.sku ?? item.product?.model ?? 'N/A',
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
        });
      }
          
      // Send email via direct SMTP
      final emailService = EmailService();
      bool success = false;
      
      try {
        // Prepare attachments
        final attachments = <Attachment>[];
        
        if (sendPDF && pdfBytes != null) {
          attachments.add(StreamAttachment(
            Stream.value(pdfBytes),
            'application/pdf',
            fileName: 'Quote_${quote.quoteNumber}.pdf',
          ));
        }
        
        if (sendExcel && excelBytes != null) {
          attachments.add(StreamAttachment(
            Stream.value(excelBytes),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            fileName: 'Quote_${quote.quoteNumber}.xlsx',
          ));
        }
        
        // Build HTML content for email
        final htmlContent = _generateQuoteEmailHtml(quote, productsList);
        
        // Get current user info
        final user = ref.read(currentUserProvider);
        final userInfo = {
          'name': user?.displayName ?? '',
          'email': user?.email ?? '',
          'role': 'Sales Representative',
        };
        
        // Send email
        success = await emailService.sendQuoteEmail(
          recipientEmail: email,
          recipientName: quote.client?.contactName ?? 'Customer',
          quoteNumber: quote.quoteNumber ?? 'N/A',
          htmlContent: htmlContent,
          userInfo: userInfo,
          attachments: attachments.isNotEmpty ? attachments : null,
        );
      } catch (emailError) {
        // Log the error for debugging
        AppLogger.error('Email sending error', error: emailError, category: LogCategory.business);
        
        // Close loading dialog immediately on error
        if (mounted && isLoadingDialogShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          isLoadingDialogShowing = false;
        }
        
        // Re-throw with more context
        if (emailError is TimeoutException) {
          throw Exception('Email service timed out. Please check your internet connection and email configuration.');
        } else {
          throw Exception('Email sending failed: ${emailError.toString()}');
        }
      }
      
      // Close loading dialog after success
      if (mounted && isLoadingDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingDialogShowing = false;
      }
      
      if (success) {
        // Update quote status to 'sent' if it was 'draft'
        if (quote.status == 'draft') {
          try {
            final dbService = ref.read(databaseServiceProvider);
            await dbService.updateQuoteStatus(quote.id ?? '', 'sent');
            ref.invalidate(quotesProvider);
          } catch (_) {
            // Continue even if status update fails
          }
        }
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quote emailed successfully to $email'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Email service returned failure');
      }
    } catch (e) {
      // Ensure loading dialog is closed with multiple fallback methods
      if (mounted && isLoadingDialogShowing) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Try alternative close method
          try {
            Navigator.of(context).pop();
          } catch (_) {
            // Ignore if already closed
          }
        }
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      // Log error
      AppLogger.error('Email failed for quote ${quote.id}', error: e, category: LogCategory.business);
    }
  }


  void _duplicateQuote(Quote quote) async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      
      // Create a duplicate quote with the same items
      // Calculate tax rate from tax amount and subtotal
      final taxRate = quote.subtotal > 0 ? (quote.tax / quote.subtotal) * 100 : 0.0;
      
      final quoteId = await dbService.createQuote(
        clientId: quote.clientId ?? '',
        items: quote.items.map((item) => {
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.total,
        }).toList(),
        subtotal: quote.subtotal,
        taxRate: taxRate,
        taxAmount: quote.tax,
        totalAmount: quote.totalAmount,
      );
      
      // Refresh quotes list
      ref.invalidate(quotesProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote duplicated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to the new quote
        context.push('/quotes/$quoteId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error duplicating quote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteQuote(Quote quote) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Quote'),
        content: Text(
            'Are you sure you want to delete quote #${quote.quoteNumber}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final dbService = ref.read(databaseServiceProvider);
                await dbService.deleteQuote(quote.id ?? '');
                
                // Refresh quotes list
                ref.invalidate(quotesProvider);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quote deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting quote: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Export all quotes to XLSX
  Future<void> _exportQuotesToXLSX(String userId) async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => const AlertDialog(
            content: SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Exporting to Excel...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // For now, show not implemented message
      throw Exception('Excel export not yet implemented');
    } catch (e) {
      // Hide loading indicator if still showing
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting quotes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Export all quotes to PDF (simplified version)
  Future<void> _exportQuotesToPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF export of all quotes not implemented yet. Use individual quote export.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Export individual quote with improved error handling
  Future<void> _exportQuote(Quote quote, String format) async {
    // Track if dialog is showing
    bool isLoadingDialogShowing = false;
    
    try {
      // Show loading indicator
      if (mounted) {
        isLoadingDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating export...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Add delay to ensure dialog is rendered
      await Future.delayed(const Duration(milliseconds: 100));

      Uint8List bytes;
      String filename;
      String mimeType;

      // Generate filename with client name and date
      final clientName = quote.client?.company ?? 'Unknown_Client';
      final cleanClientName = clientName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final dateStr = DateFormat('yyyy-MM-dd').format(quote.createdAt);
      
      if (format == 'pdf') {
        try {
          bytes = await ExportService.generateQuotePDF(quote.id ?? '');
          filename = 'Quote_${quote.quoteNumber}_${cleanClientName}_$dateStr.pdf';
          mimeType = 'application/pdf';
        } catch (pdfError) {
          // Close loading dialog
          if (mounted && isLoadingDialogShowing) {
            Navigator.of(context, rootNavigator: true).pop();
            isLoadingDialogShowing = false;
          }
          throw Exception('Failed to generate PDF: $pdfError');
        }
      } else if (format == 'excel') {
        // Close loading dialog
        if (mounted && isLoadingDialogShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          isLoadingDialogShowing = false;
        }
        
        // Generate Excel export using ExportService
        try {
          bytes = await ExportService.generateQuoteExcel(quote.id ?? '');
          
          // Verify bytes are not empty
          if (bytes.isEmpty) {
            AppLogger.error('Excel bytes are empty', category: LogCategory.business);
            throw Exception('Generated Excel file is empty');
          }
          
          filename = 'Quote_${quote.quoteNumber}_${cleanClientName}_$dateStr.xlsx';
          if (filename.isEmpty || filename == '.xlsx') {
            filename = 'Quote_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
          }
          
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          
          AppLogger.info('Excel ready for download - filename: $filename, size: ${bytes.length}', category: LogCategory.business);
        } catch (excelError) {
          AppLogger.error('Excel generation failed', error: excelError, category: LogCategory.business);
          throw Exception('Failed to generate Excel: $excelError');
        }
      } else {
        // Close loading dialog
        if (mounted && isLoadingDialogShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          isLoadingDialogShowing = false;
        }
        throw Exception('Unsupported format: $format');
      }
      
      // Hide loading indicator
      if (mounted && isLoadingDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingDialogShowing = false;
      }

      // Download file using cross-platform helper with MIME type
      await DownloadHelper.downloadFile(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote #${quote.quoteNumber} exported as ${format.toUpperCase()}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Ensure loading dialog is closed with multiple fallback methods
      if (mounted && isLoadingDialogShowing) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Try alternative close method
          try {
            Navigator.of(context).pop();
          } catch (_) {
            // Ignore if already closed
          }
        }
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      // Log error for debugging
      AppLogger.error('Export failed for quote ${quote.id}', error: e, category: LogCategory.business);
    }
  }
  
  String _generateQuoteEmailHtml(Quote quote, List<Map<String, dynamic>> products) {
    final buffer = StringBuffer();
    
    buffer.writeln('<html><body style="font-family: Arial, sans-serif;">');
    buffer.writeln('<h2>Quote #${quote.quoteNumber}</h2>');
    
    // Client information
    if (quote.client != null) {
      buffer.writeln('<h3>Client Information</h3>');
      buffer.writeln('<p><strong>Company:</strong> ${quote.client!.company}</p>');
      if (quote.client!.contactName.isNotEmpty) {
        buffer.writeln('<p><strong>Contact:</strong> ${quote.client!.contactName}</p>');
      }
    }
    
    // Products table
    buffer.writeln('<h3>Products</h3>');
    buffer.writeln('<table border="1" cellpadding="5" style="border-collapse: collapse;">');
    buffer.writeln('<tr><th>Product</th><th>SKU</th><th>Quantity</th><th>Unit Price</th><th>Total</th></tr>');
    
    for (final product in products) {
      final total = (product['quantity'] ?? 1) * (product['unitPrice'] ?? 0.0);
      buffer.writeln('<tr>');
      buffer.writeln('<td>${product['name']}</td>');
      buffer.writeln('<td>${product['sku']}</td>');
      buffer.writeln('<td>${product['quantity']}</td>');
      buffer.writeln('<td>\$${PriceFormatter.formatPrice(product['unitPrice'] ?? 0)}</td>');
      buffer.writeln('<td>\$${PriceFormatter.formatPrice(total)}</td>');
      buffer.writeln('</tr>');
    }
    
    buffer.writeln('</table>');
    
    // Totals
    buffer.writeln('<h3>Quote Summary</h3>');
    buffer.writeln('<p><strong>Subtotal:</strong> \$${PriceFormatter.formatPrice(quote.subtotal)}</p>');
    buffer.writeln('<p><strong>Tax:</strong> \$${PriceFormatter.formatPrice(quote.tax)}</p>');
    buffer.writeln('<p><strong>Total:</strong> \$${PriceFormatter.formatPrice(quote.total)}</p>');
    
    buffer.writeln('</body></html>');
    
    return buffer.toString();
  }
}
