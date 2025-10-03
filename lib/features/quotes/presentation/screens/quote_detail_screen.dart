// lib/features/quotes/presentation/screens/quote_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/widgets/simple_image_widget.dart';
import '../../../../core/utils/safe_conversions.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/product_screenshots_popup.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/app_logger.dart';
import 'package:mailer/mailer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/download_helper.dart';

// Helper class for share capabilities
class ShareCapabilities {
  final bool canShareFiles;
  final bool canUseClipboard;

  ShareCapabilities({
    required this.canShareFiles,
    required this.canUseClipboard,
  });
}

// Quote detail provider - StreamProvider.autoDispose.family for real-time updates
final quoteDetailProvider =
    StreamProvider.autoDispose.family<Quote?, String>((ref, quoteId) {
  final dbService = ref.watch(databaseServiceProvider);

  // Helper function to fetch quote with all details
  Future<Quote?> fetchQuoteWithDetails() async {
    try {
      final quoteData = await dbService.getQuote(quoteId);
      if (quoteData == null) return null;

      // Fetch client data
      Map<String, dynamic>? clientData;
      if (quoteData['client_id'] != null) {
        clientData = await dbService.getClient(quoteData['client_id']);
      }

      // Fetch quote items with product details
      final List<QuoteItem> items = [];
      if (quoteData['quote_items'] != null) {
        for (final itemData in quoteData['quote_items']) {
          // Fetch product data for each item
          final productData = await dbService.getProduct(itemData['product_id']);
          items.add(QuoteItem(
            productId: itemData['product_id'] ?? '',
            productName: productData?['name'] ?? 'Unknown Product',
            quantity: itemData['quantity'] ?? 1,
            unitPrice: SafeConversions.toPrice(itemData['unit_price']),
            total: SafeConversions.toPrice(itemData['total_price']),
            product: productData != null ? Product.fromMap(productData) : null,
            addedAt: DateTime.now(),
          ));
        }
      }

      return Quote(
        id: quoteData['id'],
        clientId: quoteData['client_id'],
        quoteNumber: quoteData['quote_number'],
        subtotal: (quoteData['subtotal'] ?? 0).toDouble(),
        tax: (quoteData['tax_amount'] ?? 0).toDouble(),
        total: (quoteData['total_amount'] ?? 0).toDouble(),
        status: quoteData['status'] ?? 'draft',
        archived: quoteData['archived'] ?? false,
        items: items,
        client: clientData != null ? Client.fromMap(clientData) : null,
        createdBy: quoteData['user_id'] ?? '',
        createdAt: quoteData['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(quoteData['created_at'])
            : DateTime.now(),
      );
    } catch (e) {
      AppLogger.error('Error loading quote details', error: e, category: LogCategory.business);
      return null;
    }
  }

  // Create stream with immediate fetch and periodic updates
  return () async* {
    // Initial fetch
    yield await fetchQuoteWithDetails();

    // Then update every 30 seconds
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      yield await fetchQuoteWithDetails();
    }
  }();
});

class QuoteDetailScreen extends ConsumerWidget {
  final String quoteId;

  const QuoteDetailScreen({
    super.key,
    required this.quoteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(quoteDetailProvider(quoteId));
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Quote Details',
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'email',
                child: Row(
                  children: [
                    Icon(
                      Icons.email,
                      size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                    ),
                    SizedBox(
                      width: ResponsiveHelper.getSpacing(context, medium: 8),
                    ),
                    Text(
                      'Send Email',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          baseFontSize: 14,
                          minFontSize: 12,
                          maxFontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                      size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                    ),
                    SizedBox(
                      width: ResponsiveHelper.getSpacing(context, medium: 8),
                    ),
                    Text(
                      'Export PDF',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          baseFontSize: 14,
                          minFontSize: 12,
                          maxFontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export Excel'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print),
                    SizedBox(width: 8),
                    Text('Print'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Duplicate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Archive', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              quoteAsync.whenData((quote) {
                if (quote != null) {
                  _handleMenuAction(context, ref, quote, value);
                }
              });
            },
          ),
        ],
      ),
      body: quoteAsync.when(
        data: (quote) {
          if (quote == null) {
            return const Center(child: Text('Quote not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quote header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quote #${quote.quoteNumber}',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormat.format(quote.createdAt),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            _buildStatusDropdown(context, quote, theme, ref),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Client information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.business, color: theme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Client Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (quote.client != null) ...[
                          _buildInfoRow(
                              'Company', quote.client!.company),
                          if (quote.client!.contactName.isNotEmpty)
                            _buildInfoRow(
                                'Contact', quote.client!.contactName),
                          if (quote.client!.email.isNotEmpty)
                            _buildInfoRow('Email', quote.client!.email),
                          if (quote.client!.phone.isNotEmpty)
                            _buildInfoRow('Phone', quote.client!.phone),
                          if (quote.client!.address != null && quote.client!.address!.isNotEmpty)
                            _buildInfoRow('Address', quote.client!.address!),
                        ] else
                          const Text('No client information'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quote items
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2, color: theme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Items (${quote.items.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (quote.items.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No items in this quote'),
                            ),
                          )
                        else
                          ...quote.items
                              .map((item) => _buildItemRow(item, theme, context)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Totals
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildTotalRow(
                            'Subtotal', currencyFormat.format(quote.subtotal)),
                        if (quote.discountAmount > 0) ...[
                          const SizedBox(height: 8),
                          _buildTotalRow(
                            quote.discountType == 'percentage'
                                ? 'Discount (${quote.discountValue}%)'
                                : 'Discount',
                            '-${currencyFormat.format(quote.discountAmount)}',
                            isDiscount: true,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildTotalRow(
                          'Tax',
                          currencyFormat.format(quote.tax),
                        ),
                        const Divider(height: 24),
                        _buildTotalRow(
                          'Total',
                          currencyFormat.format(quote.totalAmount),
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Load quote items into cart for editing
                          final dbService = ref.read(databaseServiceProvider);
                          
                          // Clear existing cart
                          await dbService.clearCart();
                          
                          // Add quote items to cart
                          for (final item in quote.items) {
                            await dbService.addToCart(
                              item.productId,
                              item.quantity,
                            );
                          }
                          
                          // Set the client in cart
                          if (!context.mounted) return;
                          if (quote.client != null) {
                            // Navigate to cart with the client pre-selected
                            context.go('/cart', extra: {'client': quote.client});
                          } else {
                            context.go('/cart');
                          }

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Quote loaded into cart for editing'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Quote'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendQuoteEmail(context, ref, quote),
                        icon: const Icon(Icons.send),
                        label: const Text('Send Quote'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(quoteDetailProvider(quoteId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendQuoteEmail(BuildContext context, WidgetRef ref, Quote quote) async {
    // Show dialog to get recipient email
    final emailController = TextEditingController(text: quote.client?.email ?? '');
    final messageController = TextEditingController();
    bool attachPdf = true;
    bool attachExcel = false;
    bool attachSpecSheets = false;
    bool attachManuals = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Quote via Email'),
          content: SingleChildScrollView(
            child: Column(
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
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Message (Optional)',
                    hintText: 'Add a personal message...',
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Attachments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Quote PDF'),
                  subtitle: const Text('Professional quote document'),
                  value: attachPdf,
                  onChanged: (value) => setState(() => attachPdf = value ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Excel Spreadsheet'),
                  subtitle: const Text('Detailed breakdown with formulas'),
                  value: attachExcel,
                  onChanged: (value) => setState(() => attachExcel = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Product Spec Sheets'),
                  subtitle: const Text('Technical specifications for all products'),
                  value: attachSpecSheets,
                  onChanged: (value) => setState(() => attachSpecSheets = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Product Manuals'),
                  subtitle: const Text('User guides and installation manuals'),
                  value: attachManuals,
                  onChanged: (value) => setState(() => attachManuals = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'email': emailController.text,
                'message': messageController.text,
                'attachPdf': attachPdf,
                'attachExcel': attachExcel,
                'attachSpecSheets': attachSpecSheets,
                'attachManuals': attachManuals,
              }),
              child: const Text('Send Email'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    final email = result['email'] as String;
    final customMessage = result['message'] as String?;
    final sendPDF = result['attachPdf'] as bool;
    final sendExcel = result['attachExcel'] as bool;
    final sendSpecSheets = result['attachSpecSheets'] as bool;
    final sendManuals = result['attachManuals'] as bool;
    
    // Validate email
    if (email.isEmpty || !email.contains('@')) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
    if (!context.mounted) return;
    bool isLoadingDialogShowing = true;
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
    
    try {
      final emailService = EmailService();
      final user = ref.read(currentUserProvider);
      
      // Generate HTML content for email body
      final dateFormat = DateFormat('MMMM dd, yyyy');
      final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

      // Add custom message if provided
      String customMessageHtml = '';
      if (customMessage != null && customMessage.isNotEmpty) {
        customMessageHtml = '''
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px;">
            <p style="margin: 0; color: #333;">${customMessage.replaceAll('\n', '<br/>')}</p>
          </div>
        ''';
      }

      String htmlContent = '''
        <h2>Quote #${quote.quoteNumber}</h2>
        <p>Date: ${dateFormat.format(quote.createdAt)}</p>

        $customMessageHtml

        <h3>Client Information</h3>
        <p>
          ${quote.client?.company ?? 'N/A'}<br/>
          ${quote.client?.contactName ?? ''}<br/>
          ${quote.client?.email ?? ''}<br/>
          ${quote.client?.phone ?? ''}
        </p>
        
        <h3>Quote Items</h3>
        <table border="1" style="border-collapse: collapse; width: 100%;">
          <tr>
            <th style="padding: 8px;">Item</th>
            <th style="padding: 8px;">Qty</th>
            <th style="padding: 8px;">Price</th>
            <th style="padding: 8px;">Total</th>
          </tr>
      ''';
      
      for (final item in quote.items) {
        final itemDiscountText = item.discount > 0 
            ? '<br/><small style="color: green;">Discount: ${item.discount}%</small>' 
            : '';
        htmlContent += '''
          <tr>
            <td style="padding: 8px;">${item.productName}$itemDiscountText</td>
            <td style="padding: 8px; text-align: center;">${item.quantity}</td>
            <td style="padding: 8px; text-align: right;">${currencyFormat.format(item.unitPrice)}</td>
            <td style="padding: 8px; text-align: right;">${currencyFormat.format(item.total)}</td>
          </tr>
        ''';
      }
      
      htmlContent += '''
        </table>
        
        <h3>Total</h3>
        <p>
          Subtotal: ${currencyFormat.format(quote.subtotal)}<br/>
      ''';
      
      if (quote.discountAmount > 0) {
        htmlContent += quote.discountType == 'percentage'
            ? 'Discount (${quote.discountValue}%): -${currencyFormat.format(quote.discountAmount)}<br/>'
            : 'Discount: -${currencyFormat.format(quote.discountAmount)}<br/>';
      }
      
      htmlContent += '''
          Tax: ${currencyFormat.format(quote.tax)}<br/>
          <strong>Total: ${currencyFormat.format(quote.totalAmount)}</strong>
        </p>
      ''';

      // Add attachment notes if spec sheets or manuals are requested
      if (sendSpecSheets || sendManuals) {
        htmlContent += '<hr/>';

        if (sendSpecSheets) {
          // List products with available spec sheets
          final productsWithSpecs = quote.items
              .where((item) => item.product?.pdfUrl != null && item.product!.pdfUrl!.isNotEmpty)
              .map((item) => item.product!)
              .toSet();

          if (productsWithSpecs.isNotEmpty) {
            htmlContent += '''
              <h3>Available Specification Sheets</h3>
              <p style="color: #666;">The following specification sheets are available for download:</p>
              <ul>
            ''';

            for (final product in productsWithSpecs) {
              final sku = product.sku ?? product.model;
              final url = product.pdfUrl!;
              htmlContent += '''
                <li>
                  <strong>$sku - ${product.displayName}</strong><br/>
                  <a href="$url" style="color: #1976d2;">Download Specification Sheet</a>
                </li>
              ''';
            }

            htmlContent += '</ul>';
          }
        }

        if (sendManuals) {
          htmlContent += '''
            <p style="color: #666; font-style: italic;">
              Note: Product user manuals will be available soon. Please contact sales for immediate assistance.
            </p>
          ''';
        }
      }
      
      // Prepare attachments
      List<Attachment>? attachments;
      if (sendPDF || sendExcel || sendSpecSheets || sendManuals) {
        attachments = [];

        if (sendPDF) {
          try {
            final pdfBytes = await ExportService.generateQuotePDF(quote.id ?? '');
            attachments.add(StreamAttachment(
              Stream.value(pdfBytes),
              'application/pdf',
              fileName: 'Quote_${quote.quoteNumber}.pdf',
            ));
          } catch (e) {
            AppLogger.error('Failed to generate PDF', error: e, category: LogCategory.business);
          }
        }

        if (sendExcel) {
          try {
            final excelBytes = await ExportService.generateQuoteExcel(quote.id ?? '');
            attachments.add(StreamAttachment(
              Stream.value(excelBytes),
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              fileName: 'Quote_${quote.quoteNumber}.xlsx',
            ));
          } catch (e) {
            AppLogger.error('Failed to generate Excel', error: e, category: LogCategory.business);
          }
        }

        // Attach spec sheets for products with PDF URLs
        if (sendSpecSheets) {
          final productsWithSpecs = quote.items
              .where((item) => item.product?.pdfUrl != null && item.product!.pdfUrl!.isNotEmpty)
              .map((item) => item.product!)
              .toSet(); // Use Set to avoid duplicates

          for (final product in productsWithSpecs) {
            try {
              // For now, we'll add a note about spec sheets in the email
              // In a real implementation, you would download the PDF from the URL
              // and attach it to the email
              AppLogger.info('Would attach spec sheet for ${product.sku}: ${product.pdfUrl}',
                category: LogCategory.business);
            } catch (e) {
              AppLogger.error('Failed to attach spec sheet for ${product.sku}',
                error: e, category: LogCategory.business);
            }
          }
        }

        // Attach manuals (placeholder for future implementation)
        if (sendManuals) {
          // When manualUrl is added to Product model, similar logic to spec sheets
          AppLogger.info('Manual attachments requested but not yet implemented',
            category: LogCategory.business);
        }
      }
      
      // Send email
      final success = await emailService.sendQuoteEmail(
        recipientEmail: email,
        recipientName: quote.client?.contactName ?? 'Customer',
        quoteNumber: quote.quoteNumber ?? 'N/A',
        htmlContent: htmlContent,
        userInfo: {
          'name': user?.displayName ?? '',
          'email': user?.email ?? '',
          'role': 'Sales Representative',
        },
        attachments: attachments,
      );
      
      // Close loading dialog
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingDialogShowing = false;
      }
      
      if (success) {
        // Update quote status if needed
        if (quote.status == 'draft') {
          try {
            final dbService = ref.read(databaseServiceProvider);
            await dbService.updateQuoteStatus(quote.id ?? '', 'sent');
            ref.invalidate(quoteDetailProvider(quote.id ?? ''));
          } catch (_) {
            // Continue even if status update fails
          }
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quote sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send email. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusDropdown(BuildContext context, Quote quote, ThemeData theme, WidgetRef ref) {
    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
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

    final currentColor = getStatusColor(quote.status);
    final statuses = ['draft', 'sent', 'accepted', 'rejected'];

    return PopupMenuButton<String>(
      initialValue: quote.status.toLowerCase(),
      onSelected: (String newStatus) async {
        if (newStatus != quote.status.toLowerCase()) {
          // Show confirmation dialog
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Update Status'),
              content: Text('Change quote status from ${quote.status.toUpperCase()} to ${newStatus.toUpperCase()}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Update'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              final dbService = ref.read(databaseServiceProvider);
              await dbService.updateQuoteStatus(quote.id ?? '', newStatus);
              ref.invalidate(quoteDetailProvider(quote.id ?? ''));
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Quote status updated to ${newStatus.toUpperCase()}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating status: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        }
      },
      itemBuilder: (context) => statuses.map((status) {
        final color = getStatusColor(status);
        return PopupMenuItem<String>(
          value: status,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: status == quote.status.toLowerCase() ? color : null,
                  fontWeight: status == quote.status.toLowerCase() ? FontWeight.bold : null,
                ),
              ),
              if (status == quote.status.toLowerCase())
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 16),
                ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: currentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: currentColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              quote.status.toUpperCase(),
              style: TextStyle(
                color: currentColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: currentColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(QuoteItem item, ThemeData theme, BuildContext context) {
    return InkWell(
      onTap: () {
        final sku = item.product?.sku ?? item.product?.model ?? item.productId;
        final productName = item.product?.name ?? item.productName;
        ProductScreenshotsPopup.show(context, sku, productName);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Row(
          children: [
            // Product image thumbnail with white background
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SimpleImageWidget(
                  sku: item.product?.sku ?? item.product?.model ?? item.productId,
                  useThumbnail: true,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  imageUrl: item.product?.thumbnailUrl ?? item.product?.imageUrl,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Sequence number if exists
                    if (item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '#${item.sequenceNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        item.product?.sku ?? item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (item.product?.productType != null)
                  Text(
                    item.product!.productType!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                // Show note if exists
                if (item.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Icon(Icons.note_alt_outlined, 
                              size: 12, 
                              color: theme.primaryColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'View Note',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.primaryColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 2, bottom: 4),
                        dense: true,
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.note, 
                                  size: 14, 
                                  color: theme.primaryColor.withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.note,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                  'Unit Price: ${PriceFormatter.formatPrice(item.unitPrice)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                // Show discount if exists
                if (item.discount > 0)
                  Text(
                    'Discount: ${item.discount}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          // Quantity and price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Qty: ${item.quantity}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                PriceFormatter.formatPrice(item.totalPrice),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, WidgetRef ref, Quote? quote, String action) async {
    if (quote == null) return;

    try {
      switch (action) {
        case 'email':
          await _sendQuoteEmail(context, ref, quote);
          break;
        case 'pdf':
          await _exportQuotePDF(context, ref, quote);
          break;
        case 'excel':
          await _exportQuoteExcel(context, ref, quote);
          break;
        case 'share':
          await _shareQuote(context, ref, quote);
          break;
        case 'print':
          await _printQuote(context, ref, quote);
          break;
        case 'duplicate':
          await _duplicateQuote(context, ref, quote);
          break;
        case 'archive':
          await _archiveQuote(context, ref, quote);
          break;
        case 'delete':
          await _deleteQuote(context, ref, quote);
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unknown action: $action')),
          );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportQuotePDF(BuildContext context, WidgetRef ref, Quote quote) async {
    bool isLoadingDialogShowing = true;

    // Show loading dialog
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
                  Text('Generating PDF...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final pdfBytes = await ExportService.generateQuotePDF(quote.id ?? '');

      // Close loading dialog
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingDialogShowing = false;
      }

      // Download the PDF
      final fileName = 'Quote_${quote.quoteNumber ?? 'Unknown'}.pdf';
      await DownloadHelper.downloadFile(
        bytes: pdfBytes,
        filename: fileName,
        mimeType: 'application/pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      AppLogger.error('Failed to export quote PDF', error: e, category: LogCategory.business);
    }
  }

  Future<void> _exportQuoteExcel(BuildContext context, WidgetRef ref, Quote quote) async {
    bool isLoadingDialogShowing = true;

    // Show loading dialog
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
                  Text('Generating Excel...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final excelBytes = await ExportService.generateQuoteExcel(quote.id ?? '');

      // Close loading dialog
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingDialogShowing = false;
      }

      // Download the Excel file
      final fileName = 'Quote_${quote.quoteNumber ?? 'Unknown'}.xlsx';
      await DownloadHelper.downloadFile(
        bytes: excelBytes,
        filename: fileName,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel exported: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      AppLogger.error('Failed to export quote Excel', error: e, category: LogCategory.business);
    }
  }

  Future<void> _shareQuote(BuildContext context, WidgetRef ref, Quote quote) async {
    try {
      // Check platform capabilities
      final platform = Theme.of(context).platform;
      final canShareFiles = platform == TargetPlatform.iOS ||
                           platform == TargetPlatform.android;

      if (canShareFiles) {
        await _shareQuoteWithFile(context, quote);
      } else {
        await _shareQuoteToClipboard(context, quote);
      }
    } catch (e) {
      // Fallback to clipboard for web/desktop
      if (!context.mounted) return;
      await _shareQuoteToClipboard(context, quote);
      AppLogger.error('Error sharing quote', error: e, category: LogCategory.business);
    }
  }

  Future<void> _shareQuoteWithFile(BuildContext context, Quote quote) async {
    try {
      final shareText = _generateShareText(quote);

      // Show loading dialog
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
                  Text('Preparing to share...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Generate PDF for sharing
      final pdfBytes = await ExportService.generateQuotePDF(quote.id ?? '');
      final fileName = 'Quote_${quote.quoteNumber ?? 'Unknown'}.pdf';

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Share with files using share_plus
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf')],
          text: shareText,
          subject: 'Quote #${quote.quoteNumber}',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (!context.mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Fallback to text-only sharing
      if (!context.mounted) return;
      await _shareQuoteText(context, quote);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shared quote (text only - PDF generation failed)'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _shareQuoteText(BuildContext context, Quote quote) async {
    try {
      final shareText = _generateShareText(quote);

      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: 'Quote #${quote.quoteNumber}'),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote details shared!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      // If native sharing fails, fall back to clipboard
      if (!context.mounted) return;
      await _shareQuoteToClipboard(context, quote);
    }
  }

  Future<void> _shareQuoteToClipboard(BuildContext context, Quote quote) async {
    try {
      final shareText = _generateShareText(quote);

      await Clipboard.setData(ClipboardData(text: shareText));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote details copied to clipboard!'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share quote: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateShareText(Quote quote) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    String shareText = '📋 Quote #${quote.quoteNumber}\n';
    shareText += '📅 Date: ${dateFormat.format(quote.createdAt)}\n\n';

    // Client information
    if (quote.client != null) {
      shareText += '🏢 Client Information:\n';
      shareText += '• Company: ${quote.client!.company}\n';
      if (quote.client!.contactName.isNotEmpty) {
        shareText += '• Contact: ${quote.client!.contactName}\n';
      }
      if (quote.client!.email.isNotEmpty) {
        shareText += '• Email: ${quote.client!.email}\n';
      }
      if (quote.client!.phone.isNotEmpty) {
        shareText += '• Phone: ${quote.client!.phone}\n';
      }
      shareText += '\n';
    }

    // Items
    shareText += '📦 Items (${quote.items.length}):\n';
    for (var item in quote.items) {
      shareText += '• ${item.productName}\n';
      shareText += '  Qty: ${item.quantity} × ${currencyFormat.format(item.unitPrice)}';
      if (item.discount > 0) {
        shareText += ' (${item.discount}% discount)';
      }
      shareText += ' = ${currencyFormat.format(item.total)}\n';
    }

    // Totals
    shareText += '\n💰 Summary:\n';
    shareText += '• Subtotal: ${currencyFormat.format(quote.subtotal)}\n';
    if (quote.discountAmount > 0) {
      final discountLabel = quote.discountType == 'percentage'
          ? 'Discount (${quote.discountValue}%)'
          : 'Discount';
      shareText += '• $discountLabel: -${currencyFormat.format(quote.discountAmount)}\n';
    }
    shareText += '• Tax: ${currencyFormat.format(quote.tax)}\n';
    shareText += '• **Total: ${currencyFormat.format(quote.totalAmount)}**\n\n';

    shareText += '---\nGenerated by Turbo Air Quotes (TAQ)\n';
    shareText += 'Professional B2B Quote Management System';

    return shareText;
  }

  Future<void> _printQuote(BuildContext context, WidgetRef ref, Quote quote) async {
    try {
      // Generate PDF for printing
      final pdfBytes = await ExportService.generateQuotePDF(quote.id ?? '');

      // For web platform, download the PDF instead of opening for print
      final fileName = 'Quote_${quote.quoteNumber ?? 'Unknown'}_Print.pdf';
      await DownloadHelper.downloadFile(
        bytes: pdfBytes,
        filename: fileName,
        mimeType: 'application/pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded: $fileName\\nOpen the file to print'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PDF for printing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      AppLogger.error('Failed to print quote', error: e, category: LogCategory.business);
    }
  }

  Future<void> _duplicateQuote(BuildContext context, WidgetRef ref, Quote quote) async {
    bool isLoadingDialogShowing = true;

    // Show loading dialog
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
                  Text('Duplicating quote...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final dbService = ref.read(databaseServiceProvider);

      // Prepare quote items for duplication
      final List<Map<String, dynamic>> duplicateItems = quote.items.map((item) => {
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.total,
        'discount': item.discount,
        'note': item.note,
        'sequence_number': item.sequenceNumber,
      }).toList();

      // Create the duplicate quote
      final newQuoteId = await dbService.createQuote(
        clientId: quote.clientId,
        items: duplicateItems,
        subtotal: quote.subtotal,
        taxRate: 8.0, // Standard tax rate
        taxAmount: quote.tax,
        totalAmount: quote.totalAmount,
        discountAmount: quote.discountAmount,
        discountType: quote.discountType,
        discountValue: quote.discountValue,
        comments: 'Duplicated from Quote #${quote.quoteNumber}',
      );

      // Close loading dialog
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoadingDialogShowing = false;
      }

      // Navigate to the new quote
      if (context.mounted) {
        context.go('/quote-detail/$newQuoteId');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote duplicated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (isLoadingDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate quote: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      AppLogger.error('Failed to duplicate quote', error: e, category: LogCategory.business);
    }
  }

  Future<void> _archiveQuote(BuildContext context, WidgetRef ref, Quote quote) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Quote'),
        content: Text('Are you sure you want to archive Quote #${quote.quoteNumber}?\n\nArchived quotes will be hidden from the main quotes list but can still be accessed from the archived quotes view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = ref.read(databaseServiceProvider);
        await dbService.archiveQuote(quote.id ?? '');

        if (context.mounted) {
          // Navigate back to quotes list
          context.go('/quotes');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quote archived successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive quote: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        AppLogger.error('Failed to archive quote', error: e, category: LogCategory.business);
      }
    }
  }

  Future<void> _deleteQuote(BuildContext context, WidgetRef ref, Quote quote) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote'),
        content: Text('Are you sure you want to delete Quote #${quote.quoteNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = ref.read(databaseServiceProvider);
        await dbService.deleteQuote(quote.id ?? '');

        if (context.mounted) {
          // Navigate back to quotes list
          context.go('/quotes');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quote deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete quote: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        AppLogger.error('Failed to delete quote', error: e, category: LogCategory.business);
      }
    }
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? Colors.green : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFF20429C) : isDiscount ? Colors.green : null,
          ),
        ),
      ],
    );
  }
}
