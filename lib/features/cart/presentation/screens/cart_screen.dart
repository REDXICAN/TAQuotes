// lib/features/cart/presentation/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'dart:async';
import '../../../../core/utils/download_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/widgets/simple_image_widget.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/firebase_email_service.dart';
import '../../../../core/widgets/searchable_client_dropdown.dart';
import '../../../../core/services/app_logger.dart';
import '../../../clients/presentation/screens/clients_screen.dart'; // Import for selectedClientProvider
import '../../../../core/utils/price_formatter.dart';

// Selected client provider for cart
final selectedClientProvider = StateProvider<Client?>((ref) => null);

// Cart provider using Realtime Database with real-time updates
final cartProvider = StreamProvider<List<CartItem>>((ref) {
  // Check authentication
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }
  
  final dbService = ref.watch(databaseServiceProvider);
  final database = FirebaseDatabase.instance;
  
  return database.ref('cart_items/${user.uid}').onValue.asyncMap((event) async {
    try {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <CartItem>[];
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final items = data.entries.map((e) => {
        ...Map<String, dynamic>.from(e.value),
        'id': e.key,
      }).toList();
      
      // Fetch product details for each cart item
      final List<CartItem> cartItems = [];

      for (final item in items) {
        final productData = await dbService.getProduct(item['product_id']);

        final product = productData != null ? Product.fromMap(productData) : null;
        final unitPrice = product?.price ?? item['unit_price']?.toDouble() ?? 0.0;
        final quantity = item['quantity'] ?? 1;
        
        cartItems.add(CartItem(
          id: item['id'],
          userId: item['user_id'] ?? user.uid,
          productId: item['product_id'],
          productName: product?.description ?? item['product_name'] ?? '',
          quantity: quantity,
          unitPrice: unitPrice,
          total: unitPrice * quantity,
          product: product,
          addedAt: item['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(item['created_at'])
              : DateTime.now(),
        ));
      }

      return cartItems;
    } catch (e) {
      AppLogger.error('Error loading cart', error: e);
      return <CartItem>[];
    }
  });
});

// Clients provider with real-time updates - fixed to prevent infinite loading
final clientsStreamProvider = StreamProvider<List<Client>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }
  
  final database = FirebaseDatabase.instance;
  return database.ref('clients/${user.uid}').onValue
    .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <Client>[];
      }
      
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return data.entries.map((e) {
          final clientMap = Map<String, dynamic>.from(e.value);
          clientMap['id'] = e.key;
          return Client.fromMap(clientMap);
        }).toList()..sort((a, b) => a.company.compareTo(b.company));
      } catch (e) {
        AppLogger.error('Error parsing clients', error: e);
        return <Client>[];
      }
    })
    .handleError((error) {
      AppLogger.error('Stream error loading clients', error: error);
      return <Client>[];
    });
});

// Keep backward compatibility
final clientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  return ref.watch(clientsStreamProvider);
});

// Cart client provider - separate but will sync with selectedClientProvider
final cartClientProvider = StateProvider<Client?>((ref) => null);

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _taxRateController = TextEditingController(text: '8.0');
  final _discountController = TextEditingController(text: '0');
  final _commentController = TextEditingController();
  bool _isDiscountPercentage = true; // true for percentage, false for fixed amount
  bool _includeCommentInEmail = false;
  bool _isCreatingQuote = false;
  bool _isOrderSummaryExpanded = false; // Start collapsed
  bool _isCommentsExpanded = false; // Start collapsed

  @override
  void dispose() {
    _taxRateController.dispose();
    _discountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    // Watch both providers and sync them
    final cartClient = ref.watch(cartClientProvider);
    final clientsScreenClient = ref.watch(selectedClientProvider);
    
    // Sync if they're different
    if (clientsScreenClient != null && cartClient?.id != clientsScreenClient.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(cartClientProvider.notifier).state = clientsScreenClient;
      });
    }
    
    final selectedClient = cartClient ?? clientsScreenClient;
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Custom header without AppBar
          Container(
            padding: EdgeInsets.all(
              ResponsiveHelper.getValue(context, mobile: 12, tablet: 16, desktop: 16),
            ),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Text(
                    'Cart',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveHelper.getValue(
                        context,
                        mobile: 20,
                        tablet: 24,
                        desktop: 24,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Show selected client in header
                  if (activeClient != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.business,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              activeClient.company,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: ResponsiveHelper.getIconSize(context),
                    ),
                    onPressed: cartAsync.when(
                      data: (items) => items.isNotEmpty ? () => _clearCart() : null,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: cartAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add products to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            );
          }

          final subtotal = _calculateSubtotal(items);
          final discountValue = double.tryParse(_discountController.text) ?? 0;
          final discountAmount = _isDiscountPercentage 
              ? subtotal * (discountValue / 100)
              : discountValue;
          final subtotalAfterDiscount = subtotal - discountAmount;
          final taxRate = double.tryParse(_taxRateController.text) ?? 0;
          final taxAmount = subtotalAfterDiscount * (taxRate / 100);
          final total = subtotalAfterDiscount + taxAmount;

          return Column(
            children: [
              // Client Selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Client',
                          style: theme.textTheme.titleMedium,
                        ),
                        if (selectedClient != null)
                          TextButton.icon(
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text('View Details'),
                            onPressed: () => _showClientDetails(selectedClient),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final clientsAsync = ref.watch(clientsStreamProvider);
                        
                        return clientsAsync.when(
                          data: (clients) => SearchableClientDropdown(
                            clients: clients,
                            selectedClient: selectedClient,
                            onClientSelected: (client) {
                              ref.read(cartClientProvider.notifier).state = client;
                              // Also sync with clients screen
                              ref.read(selectedClientProvider.notifier).state = client;
                            },
                            hintText: 'Search by company, contact, email, or phone...',
                            showAddButton: true,
                            onAddClient: _addNewClient,
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (error, stack) => Text(
                            'Error loading clients: $error',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Cart Items
              Expanded(
                child: ListView.builder(
                  padding: ResponsiveHelper.getScreenPadding(context),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final product = item.product;
                    final isCompact = ResponsiveHelper.useCompactLayout(context);
                    final isMobile = ResponsiveHelper.isMobile(context);

                    return Card(
                      margin: EdgeInsets.only(
                        bottom: ResponsiveHelper.getValue(context, mobile: 8, tablet: 10, desktop: 12),
                      ),
                      child: isCompact
                          ? // Compact layout for very small screens
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Image
                                      if (product != null)
                                        SizedBox(
                                          width: 60,
                                          height: 60,
                                          child: SimpleImageWidget(
                                            sku: product.sku ?? product.model ?? '',
                                            useThumbnail: true,
                                            fit: BoxFit.contain,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 60,
                                          height: 60,
                                          color: theme.disabledColor.withOpacity(0.1),
                                          child: const Icon(Icons.inventory_2, size: 20),
                                        ),
                                      const SizedBox(width: 12),
                                      // Product info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product?.sku ?? product?.model ?? 'Unknown Product',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatPrice((product?.price ?? 0) * item.quantity),
                                              style: TextStyle(
                                                color: theme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Delete button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        onPressed: () => _removeItem(item),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Quantity controls
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 20),
                                        onPressed: () => _updateQuantity(item, -1),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          item.quantity.toString(),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 20),
                                        onPressed: () => _updateQuantity(item, 1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : // Normal layout
                            ListTile(
                              leading: product != null
                                  ? SizedBox(
                                      width: isMobile ? 50 : 60,
                                      height: isMobile ? 50 : 60,
                                      child: SimpleImageWidget(
                                        sku: product.sku ?? product.model ?? '',
                                        useThumbnail: true,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Container(
                                      width: isMobile ? 50 : 60,
                                      height: isMobile ? 50 : 60,
                                      color: theme.disabledColor.withOpacity(0.1),
                                      child: Icon(
                                        Icons.inventory_2,
                                        size: ResponsiveHelper.getIconSize(context, baseSize: 24),
                                      ),
                                    ),
                              title: Text(
                                product?.sku ?? product?.model ?? 'Unknown Product',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getValue(
                                    context,
                                    mobile: 14,
                                    tablet: 16,
                                    desktop: 16,
                                  ),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_formatPrice(product?.price ?? 0)} per unit',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getValue(
                                        context,
                                        mobile: 12,
                                        tablet: 13,
                                        desktop: 13,
                                      ),
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                  Text(
                                    'Total: ${_formatPrice((product?.price ?? 0) * item.quantity)}',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getValue(
                                        context,
                                        mobile: 13,
                                        tablet: 14,
                                        desktop: 14,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: product != null ? () => _showProductSpecs(product, context, theme) : null,
                              trailing: isMobile
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.remove,
                                                size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _updateQuantity(item, -1),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Text(
                                                item.quantity.toString(),
                                                style: theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.add,
                                                size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _updateQuantity(item, 1),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _removeItem(item),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: () => _updateQuantity(item, -1),
                                        ),
                                        Text(
                                          item.quantity.toString(),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () => _updateQuantity(item, 1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () => _removeItem(item),
                                        ),
                                      ],
                                    ),
                            ),
                    );
                  },
                ),
              ),

              // Summary and Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Tax Rate Input
                    Row(
                      children: [
                        Text('Tax Rate (%)', style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _taxRateController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Discount Input
                    Row(
                      children: [
                        Text('Discount', style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ToggleButtons(
                          isSelected: [_isDiscountPercentage, !_isDiscountPercentage],
                          onPressed: (index) {
                            setState(() {
                              _isDiscountPercentage = index == 0;
                            });
                          },
                          constraints: const BoxConstraints(
                            minHeight: 32,
                            minWidth: 40,
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('%'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('\$'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Detailed Breakdown - Collapsible
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(
                            'Order Summary',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(
                            _isOrderSummaryExpanded ? Icons.expand_less : Icons.expand_more,
                            color: theme.primaryColor,
                          ),
                          initiallyExpanded: _isOrderSummaryExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isOrderSummaryExpanded = expanded;
                            });
                          },
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            // Items breakdown
                            ...items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantity}x ${item.product?.sku ?? item.product?.model ?? item.productName}',
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatPrice((item.product?.price ?? 0) * item.quantity),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            )).toList(),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal', style: theme.textTheme.bodyMedium),
                                Text(_formatPrice(subtotal), style: theme.textTheme.bodyMedium),
                              ],
                            ),
                            if (discountAmount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isDiscountPercentage 
                                      ? 'Discount ($discountValue%)' 
                                      : 'Discount',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green),
                                  ),
                                  Text(
                                    '-${_formatPrice(discountAmount)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tax ($taxRate%)', style: theme.textTheme.bodyMedium),
                                Text(_formatPrice(taxAmount), style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Comment Section - Collapsible
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(
                            'Comments',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(
                            _isCommentsExpanded ? Icons.expand_less : Icons.expand_more,
                            color: theme.primaryColor,
                          ),
                          initiallyExpanded: _isCommentsExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isCommentsExpanded = expanded;
                            });
                          },
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            TextField(
                              controller: _commentController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Add any notes or special instructions...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              title: const Text('Include comments in email'),
                              value: _includeCommentInEmail,
                              onChanged: (value) => setState(() => _includeCommentInEmail = value ?? false),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: theme.textTheme.titleLarge),
                        Text(
                          _formatPrice(total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                selectedClient != null && !_isCreatingQuote
                                    ? () => _createQuote(items, selectedClient)
                                    : null,
                            icon: _isCreatingQuote
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.receipt_long),
                            label: Text(_isCreatingQuote
                                ? 'Creating...'
                                : 'Create Quote'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading cart: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(cartProvider),
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

  double _calculateSubtotal(List<CartItem> items) {
    return items.fold(0, (sum, item) {
      return sum + ((item.product?.price ?? 0) * item.quantity);
    });
  }
  
  String _formatPrice(double price) {
    return PriceFormatter.formatPrice(price);
  }

  Future<void> _selectClient() async {
    // Show the client selector dialog
    final client = await showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ClientSelectorSheet(
          scrollController: scrollController,
        ),
      ),
    );

    if (client != null && mounted) {
      ref.read(cartClientProvider.notifier).state = client;
      // Sync with clients screen toggle
      ref.read(selectedClientProvider.notifier).state = client;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected client: ${client.company}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updateQuantity(CartItem item, int change) async {
    final newQuantity = item.quantity + change;
    if (newQuantity <= 0) {
      await _removeItem(item);
      return;
    }

    final dbService = ref.read(databaseServiceProvider);
    await dbService.updateCartItem(item.id ?? '', newQuantity);
    // No need to invalidate as we use StreamProvider for real-time updates
    
    // Show notification when quantity is reduced
    if (change < 0 && mounted) {
      final sku = item.product?.sku ?? item.product?.model ?? 'Item';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$sku quantity reduced to $newQuantity'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeItem(CartItem item) async {
    final dbService = ref.read(databaseServiceProvider);
    await dbService.removeFromCart(item.id ?? '');
    // No need to invalidate as we use StreamProvider for real-time updates

    if (mounted) {
      final sku = item.product?.sku ?? item.product?.model ?? 'Item';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$sku removed from cart'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
            'Are you sure you want to clear all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final dbService = ref.read(databaseServiceProvider);
    await dbService.clearCart();
    // No need to invalidate as we use StreamProvider for real-time updates

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart cleared')),
      );
    }
  }

  void _showProductSpecs(Product product, BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            product.sku ?? product.model,
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Product Image
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.disabledColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SimpleImageWidget(
                        sku: product.sku ?? product.model ?? '',
                        useThumbnail: false,  // Use full screenshot in popup
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Right side - Product Specifications
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSpecRow('SKU', product.sku ?? product.model, theme),
                        _buildSpecRow('Price', _formatPrice(product.price), theme),
                        _buildSpecRow('Category', product.category, theme),
                        if (product.subcategory != null && product.subcategory!.isNotEmpty)
                          _buildSpecRow('Subcategory', product.subcategory!, theme),
                        _buildSpecRow('Description', product.description, theme),
                        if (product.dimensions != null && product.dimensions!.isNotEmpty)
                          _buildSpecRow('Dimensions', product.dimensions!, theme),
                        if (product.weight != null && product.weight!.isNotEmpty)
                          _buildSpecRow('Weight', product.weight!, theme),
                        if (product.voltage != null && product.voltage!.isNotEmpty)
                          _buildSpecRow('Voltage', product.voltage!, theme),
                        if (product.amperage != null && product.amperage!.isNotEmpty)
                          _buildSpecRow('Amperage', product.amperage!, theme),
                        if (product.phase != null && product.phase!.isNotEmpty)
                          _buildSpecRow('Phase', product.phase!, theme),
                        if (product.frequency != null && product.frequency!.isNotEmpty)
                          _buildSpecRow('Frequency', product.frequency!, theme),
                        if (product.plugType != null && product.plugType!.isNotEmpty)
                          _buildSpecRow('Plug Type', product.plugType!, theme),
                        if (product.temperatureRange != null && product.temperatureRange!.isNotEmpty)
                          _buildSpecRow('Temperature Range', product.temperatureRange!, theme),
                        if (product.refrigerant != null && product.refrigerant!.isNotEmpty)
                          _buildSpecRow('Refrigerant', product.refrigerant!, theme),
                        if (product.compressor != null && product.compressor!.isNotEmpty)
                          _buildSpecRow('Compressor', product.compressor!, theme),
                        if (product.capacity != null && product.capacity!.isNotEmpty)
                          _buildSpecRow('Capacity', product.capacity!, theme),
                        if (product.doors != null && product.doors! > 0)
                          _buildSpecRow('Doors', product.doors.toString(), theme),
                        if (product.shelves != null && product.shelves! > 0)
                          _buildSpecRow('Shelves', product.shelves.toString(), theme),
                        if (product.dimensionsMetric != null && product.dimensionsMetric!.isNotEmpty)
                          _buildSpecRow('Dimensions (Metric)', product.dimensionsMetric!, theme),
                        if (product.weightMetric != null && product.weightMetric!.isNotEmpty)
                          _buildSpecRow('Weight (Metric)', product.weightMetric!, theme),
                        if (product.temperatureRangeMetric != null && product.temperatureRangeMetric!.isNotEmpty)
                          _buildSpecRow('Temp Range (Metric)', product.temperatureRangeMetric!, theme),
                        if (product.features != null && product.features!.isNotEmpty)
                          _buildSpecRow('Features', product.features!, theme),
                        if (product.certifications != null && product.certifications!.isNotEmpty)
                          _buildSpecRow('Certifications', product.certifications!, theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpecRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createQuote(List<CartItem> items, Client client) async {
    // Validate client ID
    if (client.id == null || client.id!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Invalid client selected. Please select a valid client.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() => _isCreatingQuote = true);

    try {
      final dbService = ref.read(databaseServiceProvider);
      final subtotal = _calculateSubtotal(items);
      final discountValue = double.tryParse(_discountController.text) ?? 0;
      final discountAmount = _isDiscountPercentage 
          ? subtotal * (discountValue / 100)
          : discountValue;
      final subtotalAfterDiscount = subtotal - discountAmount;
      final taxRate = double.tryParse(_taxRateController.text) ?? 0;
      final taxAmount = subtotalAfterDiscount * (taxRate / 100);
      final total = subtotalAfterDiscount + taxAmount;

      // Prepare quote items
      final quoteItems = items
          .map((item) => {
                'product_id': item.productId,
                'quantity': item.quantity,
                'unit_price': item.product?.price ?? 0,
                'total_price': (item.product?.price ?? 0) * item.quantity,
              })
          .toList();

      // Create quote with discount and comments
      final quoteId = await dbService.createQuote(
        clientId: client.id!,  // Now we know it's not null
        items: quoteItems,
        subtotal: subtotal,
        taxRate: taxRate,
        taxAmount: taxAmount,
        totalAmount: total,
        discountAmount: discountAmount,
        discountType: _isDiscountPercentage ? 'percentage' : 'fixed',
        discountValue: discountValue,
        comments: _commentController.text,
        includeCommentInEmail: _includeCommentInEmail,
      );

      // Clear cart after creating quote
      await dbService.clearCart();
      // No need to invalidate as we use StreamProvider for real-time updates

      if (mounted) {
        // Show success dialog with options
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
            title: const Text('Quote Created Successfully!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Quote #${DateTime.now().millisecondsSinceEpoch} has been created'),
                const SizedBox(height: 16),
                const Text('What would you like to do next?'),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushReplacementNamed(context, '/quotes/$quoteId');
                },
                icon: const Icon(Icons.visibility),
                label: const Text('View Quote'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  // Download PDF
                  try {
                    final pdfBytes = await ExportService.generateQuotePDF(quoteId);
                    // Download the PDF using cross-platform helper
                    await DownloadHelper.downloadFile(
                      bytes: pdfBytes, 
                      filename: 'Quote_${DateTime.now().millisecondsSinceEpoch}.pdf',
                      mimeType: 'application/pdf'
                    );
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Quote PDF downloaded successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error downloading PDF: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Download PDF'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Show email dialog
                  _showEmailQuoteDialog(quoteId, client);
                },
                icon: const Icon(Icons.email),
                label: const Text('Send via Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating quote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCreatingQuote = false);
    }
  }

  void _showClientDetails(Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client.company),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (client.contactName.isNotEmpty)
              _buildDetailRow('Contact', client.contactName),
            if (client.email.isNotEmpty)
              _buildDetailRow('Email', client.email),
            if (client.phone.isNotEmpty)
              _buildDetailRow('Phone', client.phone),
            if (client.address != null && client.address!.isNotEmpty)
              _buildDetailRow('Address', client.address!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _addNewClient() {
    // Show quick add dialog
    final companyController = TextEditingController();
    final contactNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quick Add Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: companyController,
              decoration: const InputDecoration(
                labelText: 'Company Name*',
                hintText: 'Enter company name',
                prefixIcon: Icon(Icons.business),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contactNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Person*',
                hintText: 'Enter contact name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can add more details later',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Client'),
            onPressed: () async {
              if (companyController.text.isEmpty || contactNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter both company name and contact person'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              try {
                final dbService = ref.read(databaseServiceProvider);
                final clientId = await dbService.addClient({
                  'company': companyController.text.trim(),
                  'contact_name': contactNameController.text.trim(),
                  'name': contactNameController.text.trim(),
                  'email': '', // Can be added later
                  'phone': '', // Can be added later
                });
                
                // Refresh clients list
                ref.invalidate(clientsStreamProvider);
                
                // Get the newly created client
                final clientsAsync = await ref.read(clientsStreamProvider.future);
                final newClient = clientsAsync.firstWhere(
                  (c) => c.id == clientId,
                  orElse: () => Client(
                    id: clientId,
                    company: companyController.text.trim(),
                    contactName: contactNameController.text.trim(),
                    name: contactNameController.text.trim(),
                    email: '',
                    phone: '',
                    createdAt: DateTime.now(),
                  ),
                );
                
                // Select the new client
                ref.read(cartClientProvider.notifier).state = newClient;
                ref.read(selectedClientProvider.notifier).state = newClient;
                
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Client "${companyController.text}" added and selected'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding client: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEmailQuoteDialog(String quoteId, Client client) {
    final emailController = TextEditingController(text: client.email ?? '');
    bool attachPDF = true;
    bool attachExcel = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                value: attachPDF,
                onChanged: (value) {
                  setDialogState(() {
                    attachPDF = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Attach Excel'),
                subtitle: const Text('Include quote as Excel attachment'),
                value: attachExcel,
                onChanged: (value) {
                  setDialogState(() {
                    attachExcel = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: emailController.text.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      
                      // Show loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const AlertDialog(
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
                      );
                      
                      try {
                        AppLogger.info('Starting email send from cart', category: LogCategory.business);
                        
                        // Generate PDF if needed
                        Uint8List? pdfBytes;
                        if (attachPDF) {
                          AppLogger.info('Generating PDF for quote $quoteId', category: LogCategory.business);
                          pdfBytes = await ExportService.generateQuotePDF(quoteId);
                          AppLogger.info('PDF generated: ${pdfBytes.length} bytes', category: LogCategory.business);
                        }
                        
                        // Generate Excel if needed
                        Uint8List? excelBytes;
                        if (attachExcel) {
                          AppLogger.info('Generating Excel for quote $quoteId', category: LogCategory.business);
                          excelBytes = await ExportService.generateQuoteExcel(quoteId);
                          AppLogger.info('Excel generated: ${excelBytes.length} bytes', category: LogCategory.business);
                        }
                        
                        // Get quote data to get the actual total and products
                        // Since cart is already cleared, we need to get the quote from database
                        final database = FirebaseDatabase.instance;
                        final user = ref.read(currentUserProvider);
                        double totalAmount = 0;
                        List<Map<String, dynamic>> productsList = [];
                        
                        if (user != null) {
                          try {
                            final quoteSnapshot = await database.ref('quotes/${user.uid}/$quoteId').get();
                            if (quoteSnapshot.exists) {
                              final quoteData = Map<String, dynamic>.from(quoteSnapshot.value as Map);
                              totalAmount = (quoteData['total_amount'] ?? quoteData['total'] ?? 0).toDouble();
                              
                              // Get products from quote items
                              if (quoteData['quote_items'] != null) {
                                final items = quoteData['quote_items'] is List 
                                  ? quoteData['quote_items'] as List
                                  : (quoteData['quote_items'] as Map).values.toList();
                                  
                                for (var item in items) {
                                  if (item != null && item is Map) {
                                    // Get product details
                                    String productName = 'Unknown Product';
                                    String productSku = 'N/A';
                                    
                                    if (item['product_id'] != null) {
                                      final productSnapshot = await database.ref('products/${item['product_id']}').get();
                                      if (productSnapshot.exists) {
                                        final productData = Map<String, dynamic>.from(productSnapshot.value as Map);
                                        productName = productData['name'] ?? productData['display_name'] ?? 'Unknown Product';
                                        productSku = productData['sku'] ?? productData['model'] ?? 'N/A';
                                      }
                                    }
                                    
                                    productsList.add({
                                      'name': productName,
                                      'sku': productSku,
                                      'quantity': item['quantity'] ?? 1,
                                      'unitPrice': item['unit_price'] ?? 0,
                                    });
                                  }
                                }
                              }
                              
                              AppLogger.info('Got quote data: total=$totalAmount, products=${productsList.length}', 
                                category: LogCategory.business);
                            }
                          } catch (e) {
                            AppLogger.error('Failed to get quote data', error: e, category: LogCategory.business);
                            totalAmount = 0;
                          }
                        }
                        
                        // Send email via Firebase Function
                        final emailService = FirebaseEmailService();
                        final success = await emailService.sendQuoteEmail(
                          recipientEmail: emailController.text.trim(),
                          recipientName: client.contactName ?? 'Customer',
                          quoteNumber: 'Q${DateTime.now().millisecondsSinceEpoch}',
                          totalAmount: totalAmount,
                          pdfBytes: pdfBytes,
                          attachPdf: attachPDF && pdfBytes != null,
                          attachExcel: attachExcel && excelBytes != null,
                          excelBytes: excelBytes,
                          products: productsList,
                        ).timeout(
                          const Duration(seconds: 30),
                          onTimeout: () {
                            throw Exception('Email sending timed out after 30 seconds');
                          },
                        );
                        
                        if (!success) {
                          throw Exception('Failed to send email');
                        }
                        
                        // Hide loading
                        if (mounted) Navigator.pop(context);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Quote emailed successfully to ${emailController.text}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e, stackTrace) {
                        AppLogger.error('Failed to send email from cart', 
                          error: e, 
                          stackTrace: stackTrace,
                          category: LogCategory.business);
                        
                        // Hide loading
                        if (mounted) Navigator.pop(context);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error sending email: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Send Email'),
            ),
          ],
        ),
      ),
    );
  }
}

// Client selector sheet
class ClientSelectorSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  
  const ClientSelectorSheet({
    super.key,
    required this.scrollController,
  });

  @override
  ConsumerState<ClientSelectorSheet> createState() => _ClientSelectorSheetState();
}

class _ClientSelectorSheetState extends ConsumerState<ClientSelectorSheet> {
  List<Client> _clients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        setState(() {
          _error = 'You must be logged in to view clients';
          _isLoading = false;
        });
        return;
      }

      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('clients/${user.uid}').get();
      
      final List<Client> clients = [];
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data.forEach((key, value) {
          try {
            final clientMap = Map<String, dynamic>.from(value);
            clientMap['id'] = key;
            clients.add(Client.fromMap(clientMap));
          } catch (e) {
            AppLogger.error('Error parsing client $key', error: e);
          }
        });
      }
      
      clients.sort((a, b) => a.company.compareTo(b.company));
      
      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading clients: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Select Client',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // Client list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, 
                                size: 64, 
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _error = null;
                                  });
                                  _loadClients();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _clients.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline, 
                                  size: 64, 
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text('No clients found'),
                                const SizedBox(height: 8),
                                Text(
                                  'Add clients from the Clients screen',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: widget.scrollController,
                            itemCount: _clients.length,
                            itemBuilder: (context, index) {
                              final client = _clients[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  child: Text(
                                    client.company.isNotEmpty 
                                        ? client.company[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(
                                  client.company,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(client.contactName),
                                    if (client.email.isNotEmpty)
                                      Text(
                                        client.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: client.email.isNotEmpty,
                                trailing: ElevatedButton(
                                  onPressed: () => Navigator.pop(context, client),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  child: const Text('Select'),
                                ),
                                onTap: () => Navigator.pop(context, client),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
