import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../../core/widgets/product_image_widget.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Simple products provider - no batching, just load everything
final productsProviderV2 = FutureProvider<List<Product>>((ref) async {
  try {
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('products').get();
    
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final products = <Product>[];
    
    for (final entry in data.entries) {
      try {
        final productMap = Map<String, dynamic>.from(entry.value);
        productMap['id'] = entry.key;
        products.add(Product.fromMap(productMap));
      } catch (e) {
        AppLogger.debug('Error parsing product ${entry.key}: $e');
      }
    }
    
    products.sort((a, b) => (a.sku ?? '').compareTo(b.sku ?? ''));
    return products;
  } catch (e) {
    AppLogger.error('Error loading products: $e');
    return [];
  }
});

// Cart management
final cartItemsProvider = StateNotifierProvider<CartItemsNotifier, Map<String, int>>((ref) {
  return CartItemsNotifier(ref);
});

class CartItemsNotifier extends StateNotifier<Map<String, int>> {
  final Ref ref;
  
  CartItemsNotifier(this.ref) : super({});
  
  Future<void> addToCart(Product product, int quantity) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      
      final database = FirebaseDatabase.instance;
      final cartRef = database.ref('carts/${user.uid}');
      
      // Check if item exists
      final existingSnapshot = await cartRef
          .orderByChild('product_id')
          .equalTo(product.id)
          .get();
      
      if (existingSnapshot.exists && existingSnapshot.value != null) {
        // Update existing
        final data = Map<String, dynamic>.from(existingSnapshot.value as Map);
        final existingKey = data.keys.first;
        final existingItem = Map<String, dynamic>.from(data[existingKey]);
        final newQuantity = (existingItem['quantity'] ?? 0) + quantity;
        
        await cartRef.child(existingKey).update({
          'quantity': newQuantity,
          'updated_at': ServerValue.timestamp,
        });
      } else {
        // Add new
        await cartRef.push().set({
          'product_id': product.id,
          'product_name': product.displayName,
          'sku': product.sku,
          'model': product.model,
          'unit_price': product.price,
          'quantity': quantity,
          'user_id': user.uid,
          'created_at': ServerValue.timestamp,
          'updated_at': ServerValue.timestamp,
        });
      }
      
      // Update local state
      if (product.id != null) {
        state = {...state, product.id!: quantity};
      }
      
    } catch (e) {
      AppLogger.error('Error adding to cart: $e');
    }
  }
  
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      state = {...state}..remove(productId);
    } else {
      state = {...state, productId: quantity};
    }
  }
  
  int getQuantity(String? productId) => productId != null ? state[productId] ?? 0 : 0;
}

class ProductsScreenV2 extends ConsumerStatefulWidget {
  const ProductsScreenV2({super.key});
  
  @override
  ConsumerState<ProductsScreenV2> createState() => _ProductsScreenV2State();
}

class _ProductsScreenV2State extends ConsumerState<ProductsScreenV2> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isTableView = false;
  final _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  List<Product> _filterProducts(List<Product> products) {
    var filtered = products;
    
    // Category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((p) => 
        p.category.toLowerCase().contains(_selectedCategory.toLowerCase())
      ).toList();
    }
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
        (p.sku ?? '').toLowerCase().contains(query) ||
        (p.model ?? '').toLowerCase().contains(query) ||
        p.name.toLowerCase().contains(query) ||
        p.description.toLowerCase().contains(query)
      ).toList();
    }
    
    return filtered;
  }
  
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProviderV2);
    final cartItems = ref.watch(cartItemsProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Products',
        actions: [
          // View toggle
          IconButton(
            icon: Icon(_isTableView ? Icons.grid_view : Icons.table_chart),
            onPressed: () => setState(() => _isTableView = !_isTableView),
          ),
          // Cart
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => context.go('/cart'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.cardColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          // Category tabs
          if (!_isTableView)
            Container(
              height: 50,
              color: theme.primaryColor.withOpacity(0.1),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  'All',
                  'Refrigerators',
                  'Freezers',
                  'Prep Tables',
                  'Under Counter',
                  'Display Cases',
                ].map((category) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = selected ? category : 'All');
                    },
                  ),
                )).toList(),
              ),
            ),
          
          // Products content
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final filtered = _filterProducts(products);
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No products available' : 'No products found',
                          style: theme.textTheme.titleLarge,
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                
                return _isTableView 
                    ? _buildTableView(filtered)
                    : _buildGridView(filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Failed to load products'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(productsProviderV2),
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
  
  Widget _buildGridView(List<Product> products) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 5 : 
                           screenWidth > 900 ? 4 : 
                           screenWidth > 600 ? 3 : 2;
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final quantity = product.id != null ? ref.watch(cartItemsProvider)[product.id!] ?? 0 : 0;
        
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () => context.go('/products/${product.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: ProductImageWidget(
                      sku: product.sku ?? product.model ?? '',
                      useThumbnail: true,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.sku ?? product.model,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        product.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${PriceFormatter.formatNumber(product.price)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Add to cart
                      Row(
                        children: [
                          if (quantity > 0) ...[
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: () {
                                ref.read(cartItemsProvider.notifier)
                                    .updateQuantity(product.id!, quantity - 1);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                            Text(
                              quantity.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () {
                                ref.read(cartItemsProvider.notifier)
                                    .updateQuantity(product.id!, quantity + 1);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ] else
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                label: const Text('Add', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  await ref.read(cartItemsProvider.notifier)
                                      .addToCart(product, 1);
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${product.sku ?? product.model} added to cart'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          ),
        );
      },
    );
  }
  
  Widget _buildTableView(List<Product> products) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Image')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Actions')),
          ],
          rows: products.map((product) {
            final quantity = product.id != null ? ref.watch(cartItemsProvider)[product.id!] ?? 0 : 0;
            
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: ProductImageWidget(
                      sku: product.sku ?? product.model ?? '',
                      useThumbnail: true,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                DataCell(Text(product.sku ?? product.model)),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      product.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text('\$${PriceFormatter.formatNumber(product.price)}')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () => context.go('/products/${product.id}'),
                      ),
                      if (quantity > 0) ...[
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: () {
                            ref.read(cartItemsProvider.notifier)
                                .updateQuantity(product.id!, quantity - 1);
                          },
                        ),
                        Text(quantity.toString()),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () {
                            ref.read(cartItemsProvider.notifier)
                                .updateQuantity(product.id!, quantity + 1);
                          },
                        ),
                      ] else
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                          onPressed: () async {
                            await ref.read(cartItemsProvider.notifier)
                                .addToCart(product, 1);
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.sku ?? product.model} added to cart'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}