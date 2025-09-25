// lib/features/products/widgets/excel_preview_dialog.dart
import 'package:flutter/material.dart';

class ExcelPreviewDialog extends StatefulWidget {
  final Map<String, dynamic> previewData;
  final Function(List<Map<String, dynamic>>, bool, String) onConfirm;

  const ExcelPreviewDialog({
    super.key,
    required this.previewData,
    required this.onConfirm,
  });

  @override
  State<ExcelPreviewDialog> createState() => _ExcelPreviewDialogState();
}

class _ExcelPreviewDialogState extends State<ExcelPreviewDialog> {
  bool _clearExisting = false;
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  String _duplicateHandling = 'update'; // 'update', 'skip', 'error'
  
  List<Map<String, dynamic>> get products => widget.previewData['products'] ?? [];
  List<String> get errors => widget.previewData['errors'] ?? [];
  
  int get totalPages => (products.length / _itemsPerPage).ceil();
  
  List<Map<String, dynamic>> get currentPageProducts {
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, products.length);
    return products.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.preview, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Preview Excel Import (${products.length} products)'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        products.length.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      Text('Total Products', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  if (errors.isNotEmpty)
                    Column(
                      children: [
                        Text(
                          errors.length.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text('Warnings', style: theme.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Clear existing checkbox
            CheckboxListTile(
              title: const Text('Clear existing products before import'),
              subtitle: const Text('Warning: This will remove all current products'),
              value: _clearExisting,
              onChanged: (value) {
                setState(() {
                  _clearExisting = value ?? false;
                  // Reset duplicate handling when clearing existing
                  if (_clearExisting) {
                    _duplicateHandling = 'update';
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),

            // Duplicate handling options (only show when not clearing existing)
            if (!_clearExisting) ...[
              const SizedBox(height: 8),
              Text(
                'Duplicate Product Handling:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Update existing products'),
                    subtitle: const Text('Replace duplicate products with new data'),
                    value: 'update',
                    groupValue: _duplicateHandling,
                    onChanged: (value) {
                      setState(() {
                        _duplicateHandling = value!;
                      });
                    },
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: const Text('Skip duplicates'),
                    subtitle: const Text('Keep existing products, skip duplicates'),
                    value: 'skip',
                    groupValue: _duplicateHandling,
                    onChanged: (value) {
                      setState(() {
                        _duplicateHandling = value!;
                      });
                    },
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: const Text('Error on duplicates'),
                    subtitle: const Text('Stop import if duplicates are found'),
                    value: 'error',
                    groupValue: _duplicateHandling,
                    onChanged: (value) {
                      setState(() {
                        _duplicateHandling = value!;
                      });
                    },
                    dense: true,
                  ),
                ],
              ),
            ],
            const Divider(),
            
            // Products table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Row')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('Price')),
                    ],
                    rows: currentPageProducts.map((product) {
                      return DataRow(
                        cells: [
                          DataCell(Text(product['row_number']?.toString() ?? '')),
                          DataCell(Text(product['sku'] ?? '')),
                          DataCell(Text(product['category'] ?? '')),
                          DataCell(
                            Tooltip(
                              message: product['description'] ?? '',
                              child: Text(
                                (product['description'] ?? '').length > 30
                                    ? '${(product['description'] ?? '').substring(0, 30)}...'
                                    : product['description'] ?? '',
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              product['price'] != null 
                                  ? '\$${product['price'].toStringAsFixed(2)}'
                                  : 'N/A',
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            
            // Pagination
            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  Text('Page ${_currentPage + 1} of $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            
            // Errors section
            if (errors.isNotEmpty) ...[
              const Divider(),
              Text(
                'Warnings (${errors.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 60,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: errors.length,
                  itemBuilder: (context, index) {
                    return Text(
                      errors[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload),
          label: Text(
            _clearExisting
                ? 'Replace All Products (${products.length})'
                : _getImportButtonText(),
          ),
          onPressed: products.isNotEmpty
              ? () {
                  Navigator.of(context).pop();
                  // Pass duplicate handling along with existing parameters
                  widget.onConfirm(products, _clearExisting, _duplicateHandling);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getImportButtonColor(theme),
          ),
        ),
      ],
    );
  }

  String _getImportButtonText() {
    switch (_duplicateHandling) {
      case 'update':
        return 'Import & Update (${products.length})';
      case 'skip':
        return 'Import & Skip Duplicates (${products.length})';
      case 'error':
        return 'Import (Error on Duplicates) (${products.length})';
      default:
        return 'Import ${products.length} Products';
    }
  }

  Color _getImportButtonColor(ThemeData theme) {
    if (_clearExisting) {
      return Colors.orange;
    }

    switch (_duplicateHandling) {
      case 'update':
        return Colors.blue;
      case 'skip':
        return Colors.green;
      case 'error':
        return Colors.red.shade600;
      default:
        return theme.primaryColor;
    }
  }
}