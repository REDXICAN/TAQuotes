import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/price_formatter.dart';

// Spare part model
class SparePart {
  final String sku;
  final String name;
  final int stock;
  final String? warehouse;
  final double price;

  SparePart({
    required this.sku,
    required this.name,
    required this.stock,
    this.warehouse,
    required this.price,
  });

  factory SparePart.fromMap(String key, Map<String, dynamic> map) {
    return SparePart(
      sku: map['sku'] ?? key,
      name: map['name'] ?? '',
      stock: map['stock'] ?? 0,
      warehouse: map['warehouse'],
      price: PriceFormatter.safeToDouble(map['price']),
    );
  }
}

// Provider for spare parts from Firebase
final sparePartsProvider = StreamProvider.autoDispose<List<SparePart>>((ref) {
  try {
    final database = FirebaseDatabase.instance;

    // Stream spare parts directly from Firebase products that have available warehouse stock
    return database.ref('products').onValue.map((event) {
      final List<SparePart> spareParts = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final productsMap = Map<String, dynamic>.from(event.snapshot.value as Map);

        for (final entry in productsMap.entries) {
          final productData = Map<String, dynamic>.from(entry.value as Map);

          // Check for warehouse stock data
          final warehouseStock = productData['warehouse_stock'] as Map<dynamic, dynamic>?;

          if (warehouseStock != null) {
            // First, check warehouse 999 (reserved/potentially available)
            final warehouse999Stock = warehouseStock['999'] as Map<dynamic, dynamic>?;
            if (warehouse999Stock != null) {
              final available999 = warehouse999Stock['available'] ?? 0;
              final available999Int = (available999 is int ? available999 : 0);

              if (available999Int > 0) {
                spareParts.add(SparePart(
                  sku: productData['sku'] ?? entry.key,
                  name: productData['name'] ?? productData['model'] ?? '',
                  stock: available999Int,
                  warehouse: '999', // Reserved but potentially available
                  price: PriceFormatter.safeToDouble(productData['price']),
                ));
              }
            }

            // Then calculate total available stock across other warehouses
            int totalAvailableStock = 0;
            String primaryWarehouse = '';

            for (final warehouseEntry in warehouseStock.entries) {
              final warehouseId = warehouseEntry.key.toString();

              // Skip warehouse 999 as we handled it separately
              if (warehouseId == '999') continue;

              final stockData = warehouseEntry.value as Map<dynamic, dynamic>?;
              if (stockData != null) {
                final available = stockData['available'] ?? 0;
                final availableInt = (available is int ? available : 0);

                if (availableInt > 0) {
                  totalAvailableStock += availableInt;
                  // Track the warehouse with most stock as primary
                  if (primaryWarehouse.isEmpty || availableInt > totalAvailableStock / 2) {
                    primaryWarehouse = warehouseId;
                  }
                }
              }
            }

            // Add entry for available stock from other warehouses
            if (totalAvailableStock > 0) {
              // Check if we already added this SKU from warehouse 999
              final existing999 = spareParts.any((part) =>
                part.sku == (productData['sku'] ?? entry.key) && part.warehouse == '999');

              // If product exists in 999, add as separate entry to show both
              // If not, add as normal available stock
              spareParts.add(SparePart(
                sku: productData['sku'] ?? entry.key,
                name: productData['name'] ?? productData['model'] ?? '',
                stock: totalAvailableStock,
                warehouse: primaryWarehouse, // Show primary warehouse
                price: PriceFormatter.safeToDouble(productData['price']),
              ));
            }
          }
        }
      }

      // Sort by stock quantity (highest first)
      spareParts.sort((a, b) => b.stock.compareTo(a.stock));

      AppLogger.info('Loaded ${spareParts.length} spare parts with available stock from Firebase');
      return spareParts;
    }).handleError((error) {
      AppLogger.error('Error streaming spare parts from Firebase', error: error);
      return <SparePart>[];
    });
  } catch (e) {
    AppLogger.error('Error setting up spare parts provider', error: e);
    // Return an empty stream on error
    return Stream.value(<SparePart>[]);
  }
});

// Spare parts screen
class SparePartsScreen extends ConsumerStatefulWidget {
  const SparePartsScreen({super.key});

  @override
  ConsumerState<SparePartsScreen> createState() => _SparePartsScreenState();
}

class _SparePartsScreenState extends ConsumerState<SparePartsScreen> {
  String _searchQuery = '';
  String? _selectedWarehouse;
  final Map<String, int> _quantities = {}; // Defaults to 0 if not set
  
  Future<void> _removeFromCart(SparePart part) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final database = FirebaseDatabase.instance;
      final cartRef = database.ref('cart_items/${user.uid}');
      
      // Find and remove the item from cart
      final existingItems = await cartRef.orderByChild('product_id').equalTo(part.sku).once();
      
      if (existingItems.snapshot.exists && existingItems.snapshot.value != null) {
        final items = Map<String, dynamic>.from(existingItems.snapshot.value as Map);
        final existingKey = items.keys.first;
        await cartRef.child(existingKey).remove();
      }
    } catch (e) {
      AppLogger.error('Error removing spare part from cart', error: e);
    }
  }
  
  Future<void> _addToCart(SparePart part, int quantity, {bool showMessage = true}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add items to cart')),
        );
        return;
      }
      
      final database = FirebaseDatabase.instance;
      final cartRef = database.ref('cart_items/${user.uid}');
      
      // Check if item already exists in cart
      final existingItems = await cartRef.orderByChild('product_id').equalTo(part.sku).once();
      
      if (existingItems.snapshot.exists && existingItems.snapshot.value != null) {
        // Update existing item quantity
        final items = Map<String, dynamic>.from(existingItems.snapshot.value as Map);
        final existingKey = items.keys.first;
        await cartRef.child(existingKey).update({
          'quantity': quantity,
          'updated_at': ServerValue.timestamp,
        });
      } else {
        // Create a new cart item only if quantity > 0
        if (quantity > 0) {
          final newItemRef = cartRef.push();
          await newItemRef.set({
            'product_id': part.sku,
            'sku': part.sku,
            'name': part.name,
            'price': part.price,
            'quantity': quantity,
            'type': 'spare_part',
            'added_at': ServerValue.timestamp,
          });
        }
      }
      
      if (mounted && showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${part.sku} x$quantity added to cart'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error adding spare part to cart', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sparePartsAsync = ref.watch(sparePartsProvider);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spare Parts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(sparePartsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
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
            child: Row(
              children: [
                Expanded(
                  flex: isMobile ? 1 : 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search spare parts...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedWarehouse,
                      decoration: InputDecoration(
                        labelText: 'Warehouse',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Warehouses'),
                        ),
                        const DropdownMenuItem(
                          value: '999',
                          child: Text('999 - Reserved (Pending Deals)'),
                        ),
                        const DropdownMenuItem(
                          value: 'CA',
                          child: Text('CA - California'),
                        ),
                        const DropdownMenuItem(
                          value: 'CA1',
                          child: Text('CA1 - California 1'),
                        ),
                        const DropdownMenuItem(
                          value: 'CA2',
                          child: Text('CA2 - California 2'),
                        ),
                        const DropdownMenuItem(
                          value: 'CA3',
                          child: Text('CA3 - California 3'),
                        ),
                        const DropdownMenuItem(
                          value: 'CA4',
                          child: Text('CA4 - California 4'),
                        ),
                        const DropdownMenuItem(
                          value: 'COCZ',
                          child: Text('COCZ - Coahuila'),
                        ),
                        const DropdownMenuItem(
                          value: 'COPZ',
                          child: Text('COPZ - Copilco'),
                        ),
                        const DropdownMenuItem(
                          value: 'INT',
                          child: Text('INT - International'),
                        ),
                        const DropdownMenuItem(
                          value: 'MEE',
                          child: Text('MEE - Mexico East'),
                        ),
                        const DropdownMenuItem(
                          value: 'PU',
                          child: Text('PU - Puebla'),
                        ),
                        const DropdownMenuItem(
                          value: 'SI',
                          child: Text('SI - Sinaloa'),
                        ),
                        const DropdownMenuItem(
                          value: 'XCA',
                          child: Text('XCA - Xcaret'),
                        ),
                        const DropdownMenuItem(
                          value: 'XPU',
                          child: Text('XPU - Xpujil'),
                        ),
                        const DropdownMenuItem(
                          value: 'XZRE',
                          child: Text('XZRE - Xochimilco'),
                        ),
                        const DropdownMenuItem(
                          value: 'ZRE',
                          child: Text('ZRE - Zacatecas'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedWarehouse = value;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Spare parts list
          Expanded(
            child: sparePartsAsync.when(
              data: (spareParts) {
                // Filter spare parts
                var filteredParts = spareParts.where((part) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      part.sku.toLowerCase().contains(_searchQuery) ||
                      part.name.toLowerCase().contains(_searchQuery);

                  // Filter by selected warehouse
                  final matchesWarehouse = _selectedWarehouse == null ||
                      part.warehouse == _selectedWarehouse;
                  
                  return matchesSearch && matchesWarehouse;
                }).toList();
                
                if (filteredParts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.build_outlined,
                          size: 64,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No spare parts found',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try adjusting your search'
                              : 'No spare parts with available stock',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Show total stock summary
                final totalStock = filteredParts.fold<int>(
                  0,
                  (sum, part) => sum + part.stock,
                );
                
                return Column(
                  children: [
                    // Summary bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredParts.length} spare parts' +
                            (_selectedWarehouse == '999'
                                ? ' (Reserved - Pending Deals)'
                                : _selectedWarehouse != null
                                    ? ' (Warehouse $_selectedWarehouse)'
                                    : ' (All Warehouses)'),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            'Total: $totalStock units',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Parts list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredParts.length,
                        itemBuilder: (context, index) {
                          final part = filteredParts[index];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.build,
                                  color: theme.primaryColor,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      part.sku,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    PriceFormatter.formatPrice(part.price),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                part.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${part.stock} units',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: part.stock > 10
                                              ? Colors.green
                                              : part.stock > 5
                                                  ? Colors.orange
                                                  : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (part.warehouse != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: part.warehouse == '999'
                                                ? Colors.amber.withValues(alpha: 0.2)
                                                : Colors.blue.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            part.warehouse == '999'
                                                ? '999 - RESERVED'
                                                : part.warehouse?.toUpperCase() ?? 'STOCK',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: part.warehouse == '999'
                                                  ? Colors.amber.shade700
                                                  : Colors.blue.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  // Quantity selector with auto-add to cart
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.dividerColor,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          iconSize: 18,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          onPressed: part.stock > 0 ? () async {
                                            final current = _quantities[part.sku] ?? 0;
                                            if (current > 0) {
                                              final newQty = current - 1;
                                              setState(() {
                                                _quantities[part.sku] = newQty;
                                              });
                                              // Update cart with new quantity (0 removes from cart)
                                              if (newQty == 0) {
                                                // Remove from cart
                                                await _removeFromCart(part);
                                              } else {
                                                await _addToCart(part, newQty, showMessage: false);
                                              }
                                            }
                                          } : null,
                                        ),
                                        InkWell(
                                          onTap: part.stock > 0 ? () async {
                                            // Show dialog for manual quantity input
                                            final result = await showDialog<int>(
                                              context: context,
                                              builder: (context) {
                                                final controller = TextEditingController(
                                                  text: '${_quantities[part.sku] ?? 0}',
                                                );
                                                return AlertDialog(
                                                  title: Text('Enter Quantity for ${part.sku}'),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                        controller: controller,
                                                        keyboardType: TextInputType.number,
                                                        autofocus: true,
                                                        decoration: InputDecoration(
                                                          labelText: 'Quantity',
                                                          hintText: 'Max: ${part.stock}',
                                                          border: const OutlineInputBorder(),
                                                        ),
                                                        onSubmitted: (value) {
                                                          final qty = int.tryParse(value) ?? 1;
                                                          Navigator.of(context).pop(
                                                            qty.clamp(1, part.stock),
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Available stock: ${part.stock} units',
                                                        style: theme.textTheme.bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        final qty = int.tryParse(controller.text) ?? 1;
                                                        Navigator.of(context).pop(
                                                          qty.clamp(1, part.stock),
                                                        );
                                                      },
                                                      child: const Text('Add to Cart'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                            if (result != null) {
                                              setState(() {
                                                _quantities[part.sku] = result;
                                              });
                                              // Auto-add to cart with selected quantity
                                              await _addToCart(part, result);
                                            }
                                          } : null,
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              minWidth: 50,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              '${_quantities[part.sku] ?? 0}',
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: part.stock > 0 ? theme.primaryColor : theme.disabledColor,
                                                decoration: part.stock > 0 ? TextDecoration.underline : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          iconSize: 18,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          onPressed: part.stock > 0 ? () async {
                                            final current = _quantities[part.sku] ?? 0;
                                            if (current < part.stock) {
                                              final newQty = current + 1;
                                              setState(() {
                                                _quantities[part.sku] = newQty;
                                              });
                                              // Auto-add to cart with new quantity
                                              await _addToCart(part, newQty, showMessage: false);
                                            }
                                          } : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                    Text('Error loading spare parts: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(sparePartsProvider),
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
}