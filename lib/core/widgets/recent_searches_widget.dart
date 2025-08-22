// lib/core/widgets/recent_searches_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import 'product_thumbnail_widget.dart';

// Provider for recent searches
final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<Product>>((ref) {
  return RecentSearchesNotifier();
});

class RecentSearchesNotifier extends StateNotifier<List<Product>> {
  static const String _storageKey = 'recent_searches';
  static const int _maxItems = 15;

  RecentSearchesNotifier() : super([]) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        state = jsonList.map((json) => Product.fromJson(json)).take(_maxItems).toList();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> addProduct(Product product) async {
    // Remove if already exists
    state = state.where((p) => p.id != product.id).toList();
    
    // Add to beginning
    state = [product, ...state].take(_maxItems).toList();
    
    // Save to storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((p) => p.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      // Handle error silently
    }
  }

  void clearSearches() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

class RecentSearchesWidget extends ConsumerWidget {
  const RecentSearchesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentSearches = ref.watch(recentSearchesProvider);
    final theme = Theme.of(context);
    
    if (recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recently Viewed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(recentSearchesProvider.notifier).clearSearches();
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recentSearches.length,
                itemBuilder: (context, index) {
                  final product = recentSearches[index];
                  return _RecentSearchItem(product: product);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchItem extends StatelessWidget {
  final Product product;

  const _RecentSearchItem({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        _showProductPopup(context, product);
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            // Thumbnail
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductThumbnailWidget(
                  sku: product.sku,
                  imageUrl: product.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // SKU
            Text(
              product.sku ?? product.model ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Price
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.primaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showProductPopup(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ProductThumbnailWidget(
                    sku: product.sku,
                    imageUrl: product.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Product info
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'SKU: ${product.sku ?? product.model ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Price: \$${product.price.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/products', extra: product);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in Products'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}