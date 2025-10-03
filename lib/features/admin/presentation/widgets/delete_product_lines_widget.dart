// lib/features/admin/presentation/widgets/delete_product_lines_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/rbac_service.dart';

class DeleteProductLinesWidget extends ConsumerStatefulWidget {
  const DeleteProductLinesWidget({super.key});

  @override
  ConsumerState<DeleteProductLinesWidget> createState() => _DeleteProductLinesWidgetState();
}

class _DeleteProductLinesWidgetState extends ConsumerState<DeleteProductLinesWidget> {
  bool _isDeleting = false;
  String _statusMessage = '';
  int _productsToDelete = 0;
  int _productsDeleted = 0;

  // Product lines to delete
  final List<String> _productLinesToDelete = [
    'EST', 'EUR', 'EUF', 'MST',
    // All E. models (E followed by a period)
  ];

  Future<void> _countProductsToDelete() async {
    try {
      setState(() {
        _statusMessage = 'Counting products to delete...';
        _productsToDelete = 0;
      });

      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('products').get();

      if (snapshot.exists && snapshot.value != null) {
        final products = Map<String, dynamic>.from(snapshot.value as Map);
        int count = 0;

        products.forEach((key, value) {
          final productData = Map<String, dynamic>.from(value);
          final model = productData['model']?.toString() ?? '';
          final sku = productData['sku']?.toString() ?? '';

          // Check if this product should be deleted
          if (_shouldDeleteProduct(model, sku)) {
            count++;
          }
        });

        setState(() {
          _productsToDelete = count;
          _statusMessage = 'Found $count products to delete';
        });
      } else {
        setState(() {
          _statusMessage = 'No products found';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error counting products: $e';
      });
      AppLogger.error('Error counting products to delete', error: e);
    }
  }

  bool _shouldDeleteProduct(String model, String sku) {
    // Check for exact matches with product lines
    for (final line in _productLinesToDelete) {
      if (model.toUpperCase() == line || sku.toUpperCase() == line) {
        return true;
      }

      // Check if model starts with the line followed by a dash or number
      if (model.toUpperCase().startsWith('$line-') ||
          model.toUpperCase().startsWith('${line}0') ||
          model.toUpperCase().startsWith('${line}1') ||
          model.toUpperCase().startsWith('${line}2') ||
          model.toUpperCase().startsWith('${line}3') ||
          model.toUpperCase().startsWith('${line}4') ||
          model.toUpperCase().startsWith('${line}5') ||
          model.toUpperCase().startsWith('${line}6') ||
          model.toUpperCase().startsWith('${line}7') ||
          model.toUpperCase().startsWith('${line}8') ||
          model.toUpperCase().startsWith('${line}9')) {
        return true;
      }
    }

    // Special case: All E. models (E followed by a period)
    if (model.toUpperCase().startsWith('E.')) {
      return true;
    }

    return false;
  }

  Future<void> _deleteProducts() async {
    // Check permissions
    final canDelete = await RBACService.hasPermission('delete_products');
    if (!canDelete) {
      setState(() {
        _statusMessage = 'Access denied. Admin privileges required.';
      });
      return;
    }

    // Confirm deletion
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete Product Lines'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete $_productsToDelete products from the following lines:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('• EST models'),
            const Text('• EUR models'),
            const Text('• EUF models'),
            const Text('• All E. models (starting with E.)'),
            const Text('• MST models'),
            const SizedBox(height: 16),
            const Text(
              'This action CANNOT be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Products'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isDeleting = true;
        _statusMessage = 'Deleting products...';
        _productsDeleted = 0;
      });

      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('products').get();

      if (snapshot.exists && snapshot.value != null) {
        final products = Map<String, dynamic>.from(snapshot.value as Map);
        final keysToDelete = <String>[];

        // Collect keys of products to delete
        products.forEach((key, value) {
          final productData = Map<String, dynamic>.from(value);
          final model = productData['model']?.toString() ?? '';
          final sku = productData['sku']?.toString() ?? '';

          if (_shouldDeleteProduct(model, sku)) {
            keysToDelete.add(key);
            AppLogger.info('Marking for deletion', data: {
              'productId': key,
              'model': model,
              'sku': sku,
            });
          }
        });

        // Delete products in batches
        for (final key in keysToDelete) {
          await database.ref('products/$key').remove();
          setState(() {
            _productsDeleted++;
            _statusMessage = 'Deleted $_productsDeleted of ${keysToDelete.length} products...';
          });
        }

        setState(() {
          _statusMessage = 'Successfully deleted $_productsDeleted products!';
        });

        AppLogger.info('Product lines deleted', data: {
          'user': FirebaseAuth.instance.currentUser?.email,
          'productsDeleted': _productsDeleted,
          'lines': _productLinesToDelete,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted $_productsDeleted products'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      AppLogger.error('Error deleting products', error: e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delete_forever, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Delete Product Lines',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Remove EST, EUR, EUF, E., and MST product lines from the database.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Product lines to delete
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Product Lines to Delete:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  const Text('• EST - All EST models'),
                  const Text('• EUR - All EUR models'),
                  const Text('• EUF - All EUF models'),
                  const Text('• E. - All models starting with E.'),
                  const Text('• MST - All MST models'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _countProductsToDelete,
                  icon: const Icon(Icons.search),
                  label: const Text('Count Products'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                if (_productsToDelete > 0)
                  ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _deleteProducts,
                    icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete),
                    label: Text(_isDeleting ? 'Deleting...' : 'Delete $_productsToDelete Products'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),

            // Status message
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('Error')
                    ? Colors.red.withValues(alpha: 0.1)
                    : _statusMessage.contains('Successfully')
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('Error')
                      ? Colors.red.withValues(alpha: 0.3)
                      : _statusMessage.contains('Successfully')
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage.contains('Error')
                        ? Icons.error
                        : _statusMessage.contains('Successfully')
                          ? Icons.check_circle
                          : Icons.info,
                      color: _statusMessage.contains('Error')
                        ? Colors.red
                        : _statusMessage.contains('Successfully')
                          ? Colors.green
                          : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: _statusMessage.contains('Error')
                            ? Colors.red
                            : _statusMessage.contains('Successfully')
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WARNING: This action is permanent and cannot be undone. Always backup your database before deleting products.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}