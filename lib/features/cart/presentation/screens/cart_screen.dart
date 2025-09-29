// lib/features/cart/presentation/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/utils/download_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/widgets/simple_image_widget.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/widgets/searchable_client_dropdown.dart';
import 'package:mailer/mailer.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/price_formatter.dart';

// Selected client provider for cart
final selectedClientProvider = StateProvider<Client?>((ref) => null);

// Cart provider using Realtime Database with real-time updates
final cartProvider = StreamProvider.autoDispose<List<CartItem>>((ref) {
  // Check authentication
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }

  final dbService = ref.watch(databaseServiceProvider);
  final database = FirebaseDatabase.instance;

  // Keep cart synced for real-time updates (skip on web if causing issues)
  try {
    database.ref('cart_items/${user.uid}').keepSynced(true);
  } catch (e) {
    AppLogger.warning('Could not enable keepSynced for cart', error: e);
  }

  return database.ref('cart_items/${user.uid}').onValue
    .timeout(const Duration(seconds: 15))
    .asyncMap((event) async {
    try {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <CartItem>[];
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final items = data.entries.map((e) => {
        ...Map<String, dynamic>.from(e.value),
        'id': e.key,
      }).toList();

      // Fetch product details for each cart item with timeout
      final List<CartItem> cartItems = [];

      for (final item in items) {
        try {
          final itemType = item['type'] ?? 'product';
          Product? product;
          String productName = '';
          double unitPrice = 0.0;

          if (itemType == 'spare_part') {
            // Handle spare parts with timeout
            final sparePartSnapshot = await database.ref('spareparts/${item['product_id']}')
              .get()
              .timeout(const Duration(seconds: 5));
            if (sparePartSnapshot.exists && sparePartSnapshot.value != null) {
              final sparePartData = Map<String, dynamic>.from(sparePartSnapshot.value as Map);
              productName = item['name'] ?? sparePartData['name'] ?? '';
              unitPrice = item['price']?.toDouble() ?? sparePartData['price']?.toDouble() ?? 0.0;
              // Create a minimal product object for spare parts
              product = Product(
                id: item['product_id'],
                sku: item['sku'] ?? item['product_id'],
                model: item['sku'] ?? item['product_id'],
                displayName: productName,
                name: productName,
                description: productName,
                price: unitPrice,
                category: 'Spare Parts',
                stock: sparePartData['stock'] ?? 0,
                createdAt: DateTime.now(),
              );
            } else {
              // Use data from cart item if spare part not found
              productName = item['name'] ?? 'Spare Part';
              unitPrice = item['price']?.toDouble() ?? 0.0;
            }
          } else {
            // Handle regular products with timeout
            try {
              final productData = await Future.value(dbService.getProduct(item['product_id']))
                .timeout(const Duration(seconds: 5));
              product = productData != null ? Product.fromMap(productData) : null;
              productName = product?.description ?? item['product_name'] ?? '';
              unitPrice = product?.price ?? item['unit_price']?.toDouble() ?? 0.0;
            } catch (e) {
              // Fallback to cart item data if product fetch fails
              productName = item['product_name'] ?? 'Product';
              unitPrice = item['unit_price']?.toDouble() ?? 0.0;
              AppLogger.warning('Failed to fetch product ${item['product_id']}, using cart data', error: e);
            }
          }

          final quantity = item['quantity'] ?? 1;

          cartItems.add(CartItem(
            id: item['id'],
            userId: item['user_id'] ?? user.uid,
            productId: item['product_id'],
            productName: productName,
            quantity: quantity,
            unitPrice: unitPrice,
            total: unitPrice * quantity,
            product: product,
            addedAt: item['added_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(item['added_at'])
                : item['created_at'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(item['created_at'])
                    : DateTime.now(),
            discount: (item['discount'] ?? 0).toDouble(),
            note: item['note'],
            sequenceNumber: item['sequence_number'] ?? item['sequenceNumber'],
          ));
        } catch (e) {
          AppLogger.warning('Failed to process cart item ${item['id']}', error: e);
          // Continue with other items instead of failing the entire cart
          continue;
        }
      }

      return cartItems;
    } catch (e) {
      AppLogger.error('Error loading cart items', error: e);
      return <CartItem>[];
    }
  })
  .handleError((error) {
    AppLogger.error('Cart stream error', error: error);
    return <CartItem>[];
  });
});

// Clients provider with real-time updates - fixed to prevent infinite loading
final clientsStreamProvider = StreamProvider.autoDispose<List<Client>>((ref) {
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

class _CartScreenState extends ConsumerState<CartScreen> with AutomaticKeepAliveClientMixin {
  final _taxRateController = TextEditingController(text: '8.0');
  final _discountController = TextEditingController(text: '0');
  final _commentController = TextEditingController();
  final _projectNameController = TextEditingController();
  bool _isDiscountPercentage = true; // true for percentage, false for fixed amount
  bool _includeCommentInEmail = false;
  bool _isCreatingQuote = false;
  bool _isOrderSummaryExpanded = false; // Start collapsed
  bool _isCommentsExpanded = false; // Start collapsed
  bool _isProjectExpanded = false; // Start collapsed
  String? _selectedProjectId;
  bool _createNewProject = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _taxRateController.dispose();
    _discountController.dispose();
    _commentController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Add comprehensive error handling to catch grey screen issues
    try {
      AppLogger.info('Cart screen build started', category: LogCategory.business);
      final cartAsync = ref.watch(cartProvider);
      AppLogger.info('Cart provider watched successfully', category: LogCategory.business);

      // Watch both providers and sync them
      final cartClient = ref.watch(cartClientProvider);
      final clientsScreenClient = ref.watch(selectedClientProvider);
      AppLogger.info('Client providers watched successfully', category: LogCategory.business);

      // Sync if they're different (but only if cart client is null to prevent loops)
      if (clientsScreenClient != null && cartClient == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(cartClientProvider.notifier).state = clientsScreenClient;
          }
        });
      }

      final selectedClient = cartClient ?? clientsScreenClient;
      final activeClient = selectedClient; // Alias for header display
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
                    size: ResponsiveHelper.getIconSize(
                      context,
                      baseSize: 100,
                    ),
                    color: theme.disabledColor,
                  ),
                  SizedBox(
                    height: ResponsiveHelper.getSpacing(context, large: 16),
                  ),
                  Text(
                    'Your cart is empty',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        baseFontSize: 24,
                        minFontSize: 20,
                        maxFontSize: 28,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveHelper.getSpacing(context, medium: 8),
                  ),
                  Text(
                    'Add products to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.disabledColor,
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

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                          skipLoadingOnReload: true,
                          skipLoadingOnRefresh: true,
                          data: (clients) => SearchableClientDropdown(
                            clients: clients,
                            selectedClient: selectedClient,
                            onClientSelected: (client) {
                              ref.read(cartClientProvider.notifier).state = client;
                            },
                            hintText: 'Search by company, contact, email, or phone...',
                            showAddButton: true,
                            onAddClient: _addNewClient,
                          ),
                          loading: () => const SizedBox(
                            height: 56,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (error, stack) => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: theme.colorScheme.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Unable to load clients. Tap to retry.',
                                    style: TextStyle(color: theme.colorScheme.error),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () => ref.invalidate(clientsStreamProvider),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Cart Items
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5, // Take up to 50% of screen height
                ),
                child: ListView.builder(
                  shrinkWrap: true,
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
                              padding: EdgeInsets.all(
                                ResponsiveHelper.getSpacing(context, medium: 8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Image with white background
                                      if (product != null)
                                        Container(
                                          width: ResponsiveHelper.getResponsiveSize(
                                            context,
                                            mobile: 50,
                                            tablet: 60,
                                            desktop: 70,
                                          ),
                                          height: ResponsiveHelper.getResponsiveSize(
                                            context,
                                            mobile: 50,
                                            tablet: 60,
                                            desktop: 70,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              ResponsiveHelper.getBorderRadius(context, baseRadius: 4),
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              ResponsiveHelper.getBorderRadius(context, baseRadius: 3),
                                            ),
                                            child: SimpleImageWidget(
                                              sku: product.sku ?? product.model ?? '',
                                              useThumbnail: true,
                                              fit: BoxFit.contain,
                                              imageUrl: product.thumbnailUrl ?? product.imageUrl,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: ResponsiveHelper.getResponsiveSize(
                                            context,
                                            mobile: 50,
                                            tablet: 60,
                                            desktop: 70,
                                          ),
                                          height: ResponsiveHelper.getResponsiveSize(
                                            context,
                                            mobile: 50,
                                            tablet: 60,
                                            desktop: 70,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.disabledColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              ResponsiveHelper.getBorderRadius(context, baseRadius: 4),
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            product?.category == 'Spare Parts' ? Icons.build : Icons.inventory_2,
                                            size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                                          ),
                                        ),
                                      SizedBox(
                                        width: ResponsiveHelper.getSpacing(context, medium: 12),
                                      ),
                                      // Product info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product?.sku ?? product?.model ?? 'Unknown Product',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: ResponsiveHelper.getResponsiveFontSize(
                                                  context,
                                                  baseFontSize: 14,
                                                  minFontSize: 12,
                                                  maxFontSize: 16,
                                                ),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(
                                              height: ResponsiveHelper.getSpacing(context, small: 4),
                                            ),
                                            Text(
                                              _formatPrice(_calculateItemTotal(item, product)),
                                              style: TextStyle(
                                                color: theme.primaryColor,
                                                fontWeight: FontWeight.bold,
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
                                      // Delete button
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                                        ),
                                        onPressed: () => _removeItem(item),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: ResponsiveHelper.getSpacing(context, medium: 8),
                                  ),
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
                                  ? Container(
                                      width: isMobile ? 50 : 60,
                                      height: isMobile ? 50 : 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: SimpleImageWidget(
                                          sku: product.sku ?? product.model ?? '',
                                          useThumbnail: true,
                                          fit: BoxFit.contain,
                                          imageUrl: product.thumbnailUrl ?? product.imageUrl,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: isMobile ? 50 : 60,
                                      height: isMobile ? 50 : 60,
                                      decoration: BoxDecoration(
                                        color: theme.disabledColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2,
                                        size: ResponsiveHelper.getIconSize(context, baseSize: 24),
                                      ),
                                    ),
                              title: Row(
                                children: [
                                  // Sequence number display - Always show with default if not set
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: (item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty)
                                          ? theme.primaryColor.withOpacity(0.1)
                                          : theme.cardColor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: (item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty)
                                            ? theme.primaryColor.withOpacity(0.3)
                                            : theme.cardColor,
                                      ),
                                    ),
                                    child: Text(
                                      item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty
                                          ? '#${item.sequenceNumber}'
                                          : '#${(index + 1).toString().padLeft(3, '0')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: (item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty)
                                            ? theme.primaryColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        // Spare parts icon
                                        if (product?.category.toLowerCase().contains('spare') == true ||
                                            item.productName.toLowerCase().contains('spare') ||
                                            (product?.productType?.toLowerCase().contains('spare') == true))
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Icon(
                                              Icons.build,
                                              color: theme.primaryColor,
                                              size: 16,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
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
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show original price, with strikethrough if discounted
                                  Text(
                                    '${_formatPrice(product?.price ?? 0)} per unit',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getValue(
                                        context,
                                        mobile: 12,
                                        tablet: 13,
                                        desktop: 13,
                                      ),
                                      color: item.discount > 0 ? Colors.grey : theme.textTheme.bodySmall?.color,
                                      decoration: item.discount > 0 ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  // Show discount if applied
                                  if (item.discount > 0) ...[
                                    Text(
                                      'Discount: ${item.discount.toStringAsFixed(1)}% - Save ${_formatPrice(((product?.price ?? 0) * item.quantity) * (item.discount / 100))}',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getValue(
                                          context,
                                          mobile: 12,
                                          tablet: 13,
                                          desktop: 13,
                                        ),
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Discounted: ${_formatPrice(((product?.price ?? 0) - ((product?.price ?? 0) * (item.discount / 100))))} per unit',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getValue(
                                          context,
                                          mobile: 12,
                                          tablet: 13,
                                          desktop: 13,
                                        ),
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  Text(
                                    'Total: ${_formatPrice(_calculateItemTotal(item, product))}',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getValue(
                                        context,
                                        mobile: 13,
                                        tablet: 14,
                                        desktop: 14,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: item.discount > 0 ? Colors.green : null,
                                    ),
                                  ),
                                  // Show note if exists
                                  if (item.note != null && item.note!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.note_alt_outlined, 
                                            size: 14, 
                                            color: theme.textTheme.bodySmall?.color),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.note!,
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.getValue(
                                                  context,
                                                  mobile: 11,
                                                  tablet: 12,
                                                  desktop: 12,
                                                ),
                                                color: theme.textTheme.bodySmall?.color,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Add action buttons for discount, note, and numbering
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        // Numbering button
                                        TextButton.icon(
                                          icon: const Icon(Icons.tag, size: 16),
                                          label: Text(item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty 
                                            ? 'Edit #${item.sequenceNumber}' 
                                            : 'Set #${(index + 1).toString().padLeft(3, '0')}'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () => _showSequenceNumberDialog(item, index + 1),
                                        ),
                                        // Discount button
                                        TextButton.icon(
                                          icon: const Icon(Icons.percent, size: 16),
                                          label: Text(item.discount > 0 ? 'Edit Discount' : 'Add Discount'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () => _showDiscountDialog(item),
                                        ),
                                        // Note button
                                        TextButton.icon(
                                          icon: const Icon(Icons.note_add, size: 16),
                                          label: Text(item.note != null && item.note!.isNotEmpty ? 'Edit Note' : 'Add Note'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () => _showNoteDialog(item),
                                        ),
                                      ],
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
                            // Discount Input
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
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
                                        border: OutlineInputBorder(),
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
                            ),
                            // Tax Rate Input
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
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
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 12),
                            // Items breakdown with individual discounts
                            ...items.map((item) {
                              final basePrice = (item.product?.price ?? 0) * item.quantity;
                              final itemDiscount = item.discount > 0 ? basePrice * (item.discount / 100) : 0;
                              final itemTotal = basePrice - itemDiscount;
                              final hasNote = item.note != null && item.note!.isNotEmpty;
                              
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      margin: const EdgeInsets.only(right: 4),
                                                      decoration: BoxDecoration(
                                                        color: theme.primaryColor.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                      child: Text(
                                                        '#${item.sequenceNumber}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: theme.primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                  Expanded(
                                                    child: Text(
                                                      '${item.quantity}x ${item.product?.sku ?? item.product?.model ?? item.productName}',
                                                      style: theme.textTheme.bodySmall,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (hasNote)
                                                    Icon(
                                                      Icons.note,
                                                      size: 12,
                                                      color: theme.primaryColor.withOpacity(0.7),
                                                    ),
                                                ],
                                              ),
                                              // Note dropdown
                                              if (hasNote)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Theme(
                                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                    child: ExpansionTile(
                                                      title: Text(
                                                        'View Note',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: theme.primaryColor,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                      tilePadding: EdgeInsets.zero,
                                                      childrenPadding: const EdgeInsets.only(top: 2, bottom: 2),
                                                      dense: true,
                                                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(6),
                                                          decoration: BoxDecoration(
                                                            color: theme.primaryColor.withOpacity(0.05),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Icon(Icons.note_alt_outlined, 
                                                                size: 12, 
                                                                color: theme.primaryColor.withOpacity(0.7)),
                                                              const SizedBox(width: 4),
                                                              Expanded(
                                                                child: Text(
                                                                  item.note!,
                                                                  style: TextStyle(
                                                                    fontSize: 10,
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
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatPrice(basePrice),
                                          style: TextStyle(
                                            fontSize: 12,
                                            decoration: item.discount > 0 ? TextDecoration.lineThrough : null,
                                            color: item.discount > 0 ? Colors.grey : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item.discount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, bottom: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '  Discount (${item.discount.toStringAsFixed(1)}%) - Save ${_formatPrice(itemDiscount.toDouble())}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          Text(
                                            _formatPrice(itemTotal),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
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
                    // Project Section - Collapsible
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
                            'Project',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(
                            _isProjectExpanded ? Icons.expand_less : Icons.expand_more,
                            color: theme.primaryColor,
                          ),
                          initiallyExpanded: _isProjectExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isProjectExpanded = expanded;
                            });
                          },
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            // Toggle between existing and new project
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<bool>(
                                    title: const Text('Select Existing'),
                                    value: false,
                                    groupValue: _createNewProject,
                                    onChanged: (value) {
                                      setState(() {
                                        _createNewProject = value ?? false;
                                        _projectNameController.clear();
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<bool>(
                                    title: const Text('Create New'),
                                    value: true,
                                    groupValue: _createNewProject,
                                    onChanged: (value) {
                                      setState(() {
                                        _createNewProject = value ?? true;
                                        _selectedProjectId = null;
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_createNewProject)
                              // New project name input
                              TextField(
                                controller: _projectNameController,
                                decoration: const InputDecoration(
                                  labelText: 'New Project Name',
                                  hintText: 'Enter project name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.create_new_folder),
                                ),
                              )
                            else
                              // Existing projects dropdown
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _loadProjects(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const LinearProgressIndicator();
                                  }
                                  
                                  final projects = snapshot.data ?? [];
                                  
                                  if (projects.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                          SizedBox(width: 8),
                                          Text('No projects available', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    );
                                  }
                                  
                                  return DropdownButtonFormField<String>(
                                    value: _selectedProjectId,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Project',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.folder),
                                    ),
                                    items: projects.map((project) {
                                      return DropdownMenuItem<String>(
                                        value: project['id'],
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                project['name'] ?? 'Unnamed Project',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getProjectStatusColor(project['status']).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                project['status'] ?? 'active',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _getProjectStatusColor(project['status']),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedProjectId = value;
                                      });
                                    },
                                  );
                                },
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
          ),
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

    } catch (error, stackTrace) {
      // Comprehensive error handling to prevent grey screen
      AppLogger.error('Cart screen build error', error: error, stackTrace: stackTrace, category: LogCategory.business);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Cart Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Cart Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'An error occurred while loading the cart: ${error.toString()}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Invalidate providers to force refresh
                  ref.invalidate(cartProvider);
                  ref.invalidate(currentUserProvider);
                  ref.invalidate(cartClientProvider);
                  ref.invalidate(selectedClientProvider);
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
  }

  double _calculateSubtotal(List<CartItem> items) {
    return items.fold(0, (sum, item) {
      final basePrice = (item.product?.price ?? 0) * item.quantity;
      final itemDiscount = item.discount > 0 ? basePrice * (item.discount / 100) : 0;
      return sum + (basePrice - itemDiscount);
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
    await dbService.updateCartItem(item.id ?? '', quantity: newQuantity);
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
                        imageUrl: product.imageUrl ?? product.thumbnailUrl,
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
    if (client.id == null || client.id?.isEmpty == true) {
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
      final user = ref.read(currentUserProvider);
      final subtotal = _calculateSubtotal(items);
      final discountValue = double.tryParse(_discountController.text) ?? 0;
      final discountAmount = _isDiscountPercentage 
          ? subtotal * (discountValue / 100)
          : discountValue;
      final subtotalAfterDiscount = subtotal - discountAmount;
      final taxRate = double.tryParse(_taxRateController.text) ?? 0;
      final taxAmount = subtotalAfterDiscount * (taxRate / 100);
      final total = subtotalAfterDiscount + taxAmount;

      // Handle project creation or selection
      String? projectId = _selectedProjectId;
      String? projectName;
      
      if (_createNewProject && _projectNameController.text.isNotEmpty) {
        // Create new project
        final database = FirebaseDatabase.instance;
        final newProjectRef = database.ref('projects/${user?.uid}').push();
        projectId = newProjectRef.key;
        projectName = _projectNameController.text;
        
        await newProjectRef.set({
          'name': projectName,
          'description': '',
          'clientId': client.id,
          'status': 'active',
          'createdAt': ServerValue.timestamp,
          'updatedAt': ServerValue.timestamp,
        });
        
        AppLogger.info('Created new project: $projectName', category: LogCategory.business);
      } else if (projectId != null) {
        // Get project name from existing project
        final database = FirebaseDatabase.instance;
        final projectSnapshot = await database.ref('projects/${user?.uid}/$projectId').get();
        if (projectSnapshot.exists) {
          final projectData = Map<String, dynamic>.from(projectSnapshot.value as Map);
          projectName = projectData['name'];
        }
      }

      // Prepare quote items with sequence numbers, discounts, and notes
      final quoteItems = items.asMap().entries
          .map((entry) => {
                'product_id': entry.value.productId,
                'quantity': entry.value.quantity,
                'unit_price': entry.value.product?.price ?? 0,
                'total_price': _calculateItemTotal(entry.value, entry.value.product),
                'sequence_number': entry.value.sequenceNumber ?? (entry.key + 1).toString().padLeft(3, '0'),
                'discount': entry.value.discount,
                'note': entry.value.note,
              })
          .toList();

      // Create quote with discount, comments, and project info
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
        projectId: projectId,
        projectName: projectName,
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
                  context.go('/quotes/$quoteId');
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
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quick Add Client'),
        content: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email*',
                  hintText: 'Enter email address',
                  prefixIcon: Icon(Icons.email),
                  helperText: 'Required for sending quotes',
                  helperStyle: TextStyle(color: Colors.blue),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: true,
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
              // Validate required fields
              if (companyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Company name is required'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              if (contactNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact person name is required'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              if (emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email address is required'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              // Basic email validation
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(emailController.text.trim())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email address'),
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
                  'email': emailController.text.trim(),
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
                    email: emailController.text.trim(),
                    phone: '',
                    createdAt: DateTime.now(),
                  ),
                );
                
                // Select the new client
                ref.read(cartClientProvider.notifier).state = newClient;
                
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
    final formKey = GlobalKey<FormState>();
    bool attachPDF = true;
    bool attachExcel = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Quote via Email'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Email *',
                    hintText: 'Enter email address',
                    prefixIcon: Icon(Icons.email),
                    helperText: 'Required field',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    // Email validation regex
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                      // Validate form first
                      if (formKey.currentState?.validate() != true) {
                        return;
                      }
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
                        
                        // Send email via SMTP
                        final emailService = EmailService();
                        
                        // Generate HTML content for email
                        final htmlContent = '''
                        <h2>Quote #Q${DateTime.now().millisecondsSinceEpoch}</h2>
                        <p>Dear ${client.contactName ?? 'Customer'},</p>
                        <p>Thank you for your interest. Please find attached your quote details.</p>
                        
                        <h3>Customer Information:</h3>
                        <p>
                          <strong>Company:</strong> ${client.company}<br>
                          <strong>Contact:</strong> ${client.contactName ?? 'N/A'}<br>
                          <strong>Email:</strong> ${client.email ?? 'N/A'}<br>
                          <strong>Phone:</strong> ${client.phone ?? 'N/A'}
                        </p>
                        
                        <h3>Products:</h3>
                        <table border="1" cellpadding="5" cellspacing="0">
                          <tr>
                            <th>Product</th>
                            <th>SKU</th>
                            <th>Quantity</th>
                            <th>Unit Price</th>
                            <th>Total</th>
                          </tr>
                          ${productsList.map((item) => '''
                          <tr>
                            <td>${item['name']}</td>
                            <td>${item['sku']}</td>
                            <td>${item['quantity']}</td>
                            <td>\$${(item['unitPrice'] as num).toStringAsFixed(2)}</td>
                            <td>\$${((item['unitPrice'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}</td>
                          </tr>
                          ''').join('')}
                        </table>
                        
                        <p><strong>Total Amount: \$${totalAmount.toStringAsFixed(2)}</strong></p>
                        ''';
                        
                        // Prepare attachments
                        List<Attachment>? attachments;
                        if (pdfBytes != null || excelBytes != null) {
                          attachments = [];
                          
                          if (attachPDF && pdfBytes != null) {
                            attachments.add(StreamAttachment(
                              Stream.value(pdfBytes),
                              'application/pdf',
                              fileName: 'Quote_Q${DateTime.now().millisecondsSinceEpoch}.pdf',
                            ));
                          }
                          
                          if (attachExcel && excelBytes != null) {
                            attachments.add(StreamAttachment(
                              Stream.value(excelBytes),
                              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                              fileName: 'Quote_Q${DateTime.now().millisecondsSinceEpoch}.xlsx',
                            ));
                          }
                        }
                        
                        final success = await emailService.sendQuoteEmail(
                          recipientEmail: emailController.text.trim(),
                          recipientName: client.contactName ?? 'Customer',
                          quoteNumber: 'Q${DateTime.now().millisecondsSinceEpoch}',
                          htmlContent: htmlContent,
                          userInfo: {
                            'name': user?.displayName ?? '',
                            'email': user?.email ?? '',
                            'role': 'Sales Representative',
                          },
                          attachments: attachments,
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
                              content: Row(
                                children: [
                                  Expanded(
                                    child: Text('Quote emailed successfully to ${emailController.text}'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // Navigate to the quote detail page
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      context.go('/quotes/$quoteId');
                                    },
                                    child: const Text(
                                      'VIEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 5),
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

  // Calculate item total with discount
  double _calculateItemTotal(CartItem item, Product? product) {
    final basePrice = (product?.price ?? 0) * item.quantity;
    if (item.discount > 0) {
      final discountAmount = basePrice * (item.discount / 100);
      return basePrice - discountAmount;
    }
    return basePrice;
  }

  // Load projects for the current client
  Future<List<Map<String, dynamic>>> _loadProjects() async {
    try {
      final selectedClient = ref.read(cartClientProvider) ?? ref.read(selectedClientProvider);
      if (selectedClient?.id == null) return [];

      final dbService = ref.read(databaseServiceProvider);
      final user = ref.read(currentUserProvider);
      if (user == null) return [];

      // Get projects for this client
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('projects/${user.uid}').orderByChild('clientId').equalTo(selectedClient?.id ?? '').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final projectsMap = Map<String, dynamic>.from(snapshot.value as Map);
        final projects = <Map<String, dynamic>>[];
        
        projectsMap.forEach((key, value) {
          final project = Map<String, dynamic>.from(value);
          project['id'] = key;
          // Only add active projects
          if (project['status'] == null || project['status'] == 'active') {
            projects.add(project);
          }
        });
        
        // Sort by created date (most recent first)
        projects.sort((a, b) {
          final aDate = a['createdAt'] ?? 0;
          final bDate = b['createdAt'] ?? 0;
          return bDate.compareTo(aDate);
        });
        
        return projects;
      }
      
      return [];
    } catch (e) {
      AppLogger.error('Error loading projects', error: e);
      return [];
    }
  }

  // Get color for project status
  Color _getProjectStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'on-hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Show discount dialog for individual item
  void _showDiscountDialog(CartItem item) {
    final discountController = TextEditingController(
      text: item.discount > 0 ? item.discount.toStringAsFixed(2) : '',
    );
    bool isPercentage = true;
    final unitPrice = item.product?.price ?? item.unitPrice;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Item Discount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Product: ${item.product?.sku ?? item.productName}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Unit Price: ${_formatPrice(unitPrice)}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: discountController,
                      decoration: InputDecoration(
                        labelText: isPercentage ? 'Discount Percentage' : 'Discount Amount',
                        hintText: isPercentage ? 'Enter 0-100' : 'Enter amount',
                        prefixIcon: Icon(isPercentage ? Icons.percent : Icons.attach_money),
                        suffixText: isPercentage ? '%' : '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,2}')),
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [isPercentage, !isPercentage],
                    onPressed: (index) {
                      setDialogState(() {
                        isPercentage = index == 0;
                        discountController.clear();
                      });
                    },
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
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
              // Show preview of discounted price
              if (discountController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Builder(
                    builder: (context) {
                      final discountValue = double.tryParse(discountController.text) ?? 0;
                      double discountAmount = 0;
                      
                      if (isPercentage) {
                        discountAmount = unitPrice * (discountValue / 100);
                      } else {
                        discountAmount = discountValue;
                      }
                      
                      final newPrice = unitPrice - discountAmount;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Original:', style: TextStyle(fontSize: 12)),
                              Text(_formatPrice(unitPrice), style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount:', style: TextStyle(fontSize: 12, color: Colors.green)),
                              Text('-${_formatPrice(discountAmount)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('New Price:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(_formatPrice(newPrice), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ],
                      );
                    }
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (item.discount > 0)
              TextButton(
                onPressed: () async {
                  // Remove discount
                  final dbService = ref.read(databaseServiceProvider);
                  if (item.id != null) {
                    await dbService.updateCartItem(
                      item.id!,
                      discount: 0,
                    );
                  }
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Discount removed'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                child: const Text('Remove'),
              ),
            ElevatedButton(
              onPressed: () async {
                final discountValue = double.tryParse(discountController.text) ?? 0;
                double finalDiscountPercentage = 0;
                
                if (isPercentage) {
                  if (discountValue < 0 || discountValue > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Percentage must be between 0 and 100'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  finalDiscountPercentage = discountValue;
                } else {
                  // Convert dollar amount to percentage
                  if (discountValue < 0 || discountValue > unitPrice) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Amount must be between \$0 and ${_formatPrice(unitPrice)}'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  finalDiscountPercentage = (discountValue / unitPrice) * 100;
                }
                
                final dbService = ref.read(databaseServiceProvider);
                if (item.id != null) {
                  await dbService.updateCartItem(
                    item.id!,
                    discount: finalDiscountPercentage,
                  );
                }
                
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Discount ${finalDiscountPercentage > 0 ? "applied" : "removed"}'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // Show sequence number dialog for individual item
  void _showSequenceNumberDialog(CartItem item, int defaultNumber) {
    final sequenceController = TextEditingController(
      text: item.sequenceNumber ?? defaultNumber.toString().padLeft(3, '0'),
    );
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Item Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Product: ${item.product?.sku ?? item.productName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sequenceController,
              decoration: const InputDecoration(
                labelText: 'Sequence Number',
                hintText: 'e.g., 001, 002, A1, etc.',
                prefixIcon: Icon(Icons.tag),
                helperText: 'Custom numbering for quote organization',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: Use numbers (001, 002) or alphanumeric (A1, B2) for easy reference',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
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
          if (item.sequenceNumber != null && item.sequenceNumber!.isNotEmpty)
            TextButton(
              onPressed: () async {
                // Remove sequence number
                final dbService = ref.read(databaseServiceProvider);
                if (item.id != null) {
                  await dbService.updateCartItem(
                    item.id!,
                    sequenceNumber: '',
                  );
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item number removed'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Remove'),
            ),
          ElevatedButton(
            onPressed: () async {
              final sequenceNumber = sequenceController.text.trim();
              
              final dbService = ref.read(databaseServiceProvider);
              if (item.id != null) {
                await dbService.updateCartItem(
                  item.id!,
                  sequenceNumber: sequenceNumber,
                );
              }
              
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(sequenceNumber.isEmpty 
                    ? 'Item number removed' 
                    : 'Item number set to #$sequenceNumber'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Show note dialog for individual item
  void _showNoteDialog(CartItem item) {
    final noteController = TextEditingController(text: item.note ?? '');
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Item Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Product: ${item.product?.sku ?? item.productName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Enter note for this item',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (item.note != null && item.note!.isNotEmpty)
            TextButton(
              onPressed: () async {
                // Remove note
                final dbService = ref.read(databaseServiceProvider);
                if (item.id != null) {
                  await dbService.updateCartItem(
                    item.id!,
                    note: null,
                  );
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note removed'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Remove'),
            ),
          ElevatedButton(
            onPressed: () async {
              final note = noteController.text.trim();
              
              final dbService = ref.read(databaseServiceProvider);
              if (item.id != null) {
                await dbService.updateCartItem(
                  item.id!,
                  note: note.isEmpty ? null : note,
                );
              }
              
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(note.isEmpty ? 'Note removed' : 'Note saved'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
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
                                _error ?? 'Unknown error',
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
