// lib/features/quotes/presentation/screens/quote_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/widgets/simple_image_widget.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/product_screenshots_popup.dart';

// Quote detail provider
final quoteDetailProvider =
    FutureProvider.family<Quote?, String>((ref, quoteId) async {
  final dbService = ref.watch(databaseServiceProvider);
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
        unitPrice: (itemData['unit_price'] ?? 0).toDouble(),
        total: (itemData['total_price'] ?? 0).toDouble(),
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
    items: items,
    client: clientData != null ? Client.fromMap(clientData) : null,
    createdBy: quoteData['user_id'] ?? '',
    createdAt: quoteData['created_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(quoteData['created_at'])
        : DateTime.now(),
  );
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
              const PopupMenuItem<String>(
                value: 'email',
                child: Row(
                  children: [
                    Icon(Icons.email),
                    SizedBox(width: 8),
                    Text('Send Email'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Export PDF'),
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
              // Handle menu actions
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$value action coming soon')),
              );
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
                            _buildStatusChip(quote.status, theme),
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
                          if (quote.client != null) {
                            // Navigate to cart with the client pre-selected
                            context.go('/cart', extra: {'client': quote.client});
                          } else {
                            context.go('/cart');
                          }
                          
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
                        onPressed: () {
                          // Handle send
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Send functionality coming soon')),
                          );
                        },
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

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color color;
    switch (status.toLowerCase()) {
      case 'draft':
        color = Colors.grey;
        break;
      case 'sent':
        color = Colors.blue;
        break;
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
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
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(0.3),
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
                if (item.note != null && item.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.note_alt_outlined, 
                          size: 12, 
                          color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.note!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFF20429C) : null,
          ),
        ),
      ],
    );
  }
}
