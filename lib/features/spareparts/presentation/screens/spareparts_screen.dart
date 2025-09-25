import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/safe_conversions.dart';

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
      price: SafeConversions.toPrice(map['price']),
    );
  }
}

// Provider for spare parts
final sparePartsProvider = StreamProvider.autoDispose<List<SparePart>>((ref) {
  final database = FirebaseDatabase.instance;
  
  // Keep synced for faster loads
  database.ref('spareparts').keepSynced(true);
  
  return database.ref('spareparts').onValue.map((event) {
    if (!event.snapshot.exists || event.snapshot.value == null) {
      return [];
    }
    
    try {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((entry) {
        return SparePart.fromMap(
          entry.key,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }).toList()
        ..sort((a, b) => b.stock.compareTo(a.stock)); // Sort by stock quantity
    } catch (e) {
      AppLogger.error('Error loading spare parts', error: e);
      return [];
    }
  });
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
                        ...['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU']
                            .map((warehouse) => DropdownMenuItem(
                                  value: warehouse,
                                  child: Text(warehouse),
                                ))
                            ,
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
                              : 'No spare parts available',
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
                      color: theme.primaryColor.withOpacity(0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredParts.length} spare parts',
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
                                  color: theme.primaryColor.withOpacity(0.1),
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
                                            color: theme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            part.warehouse!,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.primaryColor,
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