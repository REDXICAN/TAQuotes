// lib/features/quotes/presentation/screens/edit_quote_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/responsive_helper.dart';

class EditQuoteScreen extends ConsumerStatefulWidget {
  final Quote quote;
  
  const EditQuoteScreen({
    super.key,
    required this.quote,
  });

  @override
  ConsumerState<EditQuoteScreen> createState() => _EditQuoteScreenState();
}

class _EditQuoteScreenState extends ConsumerState<EditQuoteScreen> {
  late List<QuoteItem> _items;
  late String _selectedClientId;
  final _taxRateController = TextEditingController(text: '8.0');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.quote.items);
    _selectedClientId = widget.quote.clientId ?? '';
    
    // Calculate tax rate from existing quote
    if (widget.quote.subtotal > 0) {
      final taxRate = (widget.quote.tax / widget.quote.subtotal) * 100;
      _taxRateController.text = taxRate.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
  }

  double get _taxRate {
    return double.tryParse(_taxRateController.text) ?? 0.0;
  }

  double get _taxAmount {
    return _subtotal * (_taxRate / 100);
  }

  double get _total {
    return _subtotal + _taxAmount;
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      setState(() {
        _items.removeAt(index);
      });
    } else {
      setState(() {
        _items[index] = _items[index].copyWith(
          quantity: newQuantity,
          total: _items[index].unitPrice * newQuantity,
        );
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _saveQuote() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save quote with no items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedClientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a client'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dbService = ref.read(databaseServiceProvider);
      
      // Update the quote
      await dbService.updateQuote(
        widget.quote.id!,
        {
          'client_id': _selectedClientId,
          'quote_items': _items.map((item) => {
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total_price': item.total,
          }).toList(),
          'subtotal': _subtotal,
          'tax_rate': _taxRate,
          'tax_amount': _taxAmount,
          'total_amount': _total,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/quotes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating quote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Quote #${widget.quote.quoteNumber}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveQuote,
              icon: _isSaving 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client Information',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, child) {
                        final dbService = ref.watch(databaseServiceProvider);
                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: dbService.getClients(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            
                            final clients = snapshot.data!;
                            return DropdownButtonFormField<String>(
                              value: _selectedClientId.isEmpty ? null : _selectedClientId,
                              decoration: const InputDecoration(
                                labelText: 'Select Client',
                                border: OutlineInputBorder(),
                              ),
                              items: clients.map((client) {
                                return DropdownMenuItem<String>(
                                  value: client['id'] as String,
                                  child: Text(client['company'] ?? 'Unknown'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedClientId = value ?? '';
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Quote Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quote Items',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No items in this quote'),
                        ),
                      )
                    else
                      ...List.generate(_items.length, (index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SKU: ${item.productId}',
                                        style: TextStyle(
                                          color: theme.disabledColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${item.unitPrice.toStringAsFixed(2)} each',
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity controls
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: theme.dividerColor),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () => _updateQuantity(
                                          index,
                                          item.quantity - 1,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                      ),
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 50,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () => _updateQuantity(
                                          index,
                                          item.quantity + 1,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Total
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    '\$${item.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.red,
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Totals
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quote Summary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tax rate input
                    Row(
                      children: [
                        const Text('Tax Rate (%): '),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _taxRateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Summary rows
                    _buildSummaryRow('Subtotal', _subtotal),
                    _buildSummaryRow('Tax', _taxAmount),
                    const Divider(height: 24),
                    _buildSummaryRow('Total', _total, isTotal: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension for QuoteItem
extension on QuoteItem {
  QuoteItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? total,
    Product? product,
    DateTime? addedAt,
  }) {
    return QuoteItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      product: product ?? this.product,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}