// lib/features/quotes/presentation/screens/quotes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/services/app_logger.dart';
import 'package:excel/excel.dart' as excel;
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
        ));
      }

      // Sort by date (newest first)
      quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return quotes;
    } catch (e) {
      print('Error loading quotes: $e');
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

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotes'),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
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
                    hintText: 'Search quotes...',
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

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Draft', 'draft'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sent', 'sent'),
                    ],
                  ),
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

                if (_searchQuery.isNotEmpty) {
                  filteredQuotes = filteredQuotes
                      .where((q) =>
                          (q.quoteNumber
                              ?.toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ?? false) ||
                          (q.client?.company ?? '')
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                      .toList();
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

                return Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.67, // 2/3 of screen width
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredQuotes.length,
                      itemBuilder: (context, index) {
                        final quote = filteredQuotes[index];
                        return _buildQuoteCard(quote);
                      },
                    ),
                  ),
                );
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
                    '\$${quote.totalAmount.toStringAsFixed(2)}',
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
                        child: Icon(Icons.visibility, size: 18),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _editQuote(quote),
                        child: Icon(Icons.edit, size: 18, color: Colors.orange),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _emailQuote(quote),
                        child: Icon(Icons.email, size: 18),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _exportQuote(quote, 'pdf'),
                        child: Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
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
                            onPressed: () => _duplicateQuote(quote),
                            icon: Icon(Icons.copy, size: isTablet ? 14 : 16),
                            label: Text('Copy', style: TextStyle(fontSize: isTablet ? 12 : 14)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 8),
                              minimumSize: Size(0, isTablet ? 32 : 36),
                              foregroundColor: Colors.blue,
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
    final sendPDF = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            const CheckboxListTile(
              title: Text('Attach PDF'),
              subtitle: Text('Include quote as PDF attachment'),
              value: true,
              onChanged: null, // Always include PDF
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (sendPDF != true) return;
    
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
          builder: (dialogContext) => WillPopScope(
            onWillPop: () async => false,
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
      Uint8List pdfBytes;
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
      
      // Send email with PDF attachment with timeout
      final emailService = EmailService();
      bool success = false;
      
      try {
        // Add timeout to prevent hanging
        success = await emailService.sendQuoteWithPDFBytes(
          recipientEmail: email,
          recipientName: quote.client?.contactName ?? 'Customer',
          quoteNumber: quote.quoteNumber ?? 'N/A',
          pdfBytes: pdfBytes,
          userInfo: {
            'name': ref.read(currentUserProvider)?.displayName ?? 'Sales Representative',
            'email': ref.read(currentUserProvider)?.email ?? '',
            'role': 'Sales',
          },
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Email sending timed out after 30 seconds');
          },
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
          builder: (dialogContext) => WillPopScope(
            onWillPop: () async => false,
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
        
        // Generate Excel export
        try {
          bytes = await _generateQuoteExcel(quote);
          filename = 'Quote_${quote.quoteNumber}_${cleanClientName}_$dateStr.xlsx';
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        } catch (excelError) {
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

      // Download file
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

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

  // Generate Excel file for quote
  Future<Uint8List> _generateQuoteExcel(Quote quote) async {
    final workbook = excel.Excel.createExcel();
    final sheet = workbook['Quote'];
    
    // Helper to create text cell value
    excel.TextCellValue textCell(String text) => excel.TextCellValue(text);
    excel.IntCellValue intCell(int value) => excel.IntCellValue(value);
    excel.DoubleCellValue doubleCell(double value) => excel.DoubleCellValue(value);
    
    // Add headers
    sheet.appendRow([textCell('Quote #${quote.quoteNumber}')]);
    sheet.appendRow([textCell('Date: ${DateFormat('MMMM dd, yyyy').format(quote.createdAt)}')]);
    sheet.appendRow([textCell('')]);
    
    // Client info
    sheet.appendRow([textCell('Client Information')]);
    sheet.appendRow([textCell('Company:'), textCell(quote.client?.company ?? 'N/A')]);
    sheet.appendRow([textCell('Contact:'), textCell(quote.client?.contactName ?? 'N/A')]);
    sheet.appendRow([textCell('Email:'), textCell(quote.client?.email ?? 'N/A')]);
    sheet.appendRow([textCell('Phone:'), textCell(quote.client?.phone ?? 'N/A')]);
    sheet.appendRow([textCell('')]);
    
    // Items header
    sheet.appendRow([
      textCell('Item'),
      textCell('Description'),
      textCell('Quantity'),
      textCell('Unit Price'),
      textCell('Total')
    ]);
    
    // Add items
    for (var item in quote.items) {
      sheet.appendRow([
        textCell(item.productId),
        textCell(item.productName),
        intCell(item.quantity),
        textCell('\$${item.unitPrice.toStringAsFixed(2)}'),
        textCell('\$${item.total.toStringAsFixed(2)}')
      ]);
    }
    
    sheet.appendRow([textCell('')]);
    sheet.appendRow([
      textCell(''),
      textCell(''),
      textCell(''),
      textCell('Subtotal:'),
      textCell('\$${quote.subtotal.toStringAsFixed(2)}')
    ]);
    sheet.appendRow([
      textCell(''),
      textCell(''),
      textCell(''),
      textCell('Tax:'),
      textCell('\$${quote.tax.toStringAsFixed(2)}')
    ]);
    sheet.appendRow([
      textCell(''),
      textCell(''),
      textCell(''),
      textCell('Total:'),
      textCell('\$${quote.total.toStringAsFixed(2)}')
    ]);
    
    // Save and return bytes
    final bytes = workbook.save();
    if (bytes == null) throw Exception('Failed to generate Excel file');
    return Uint8List.fromList(bytes);
  }
}
