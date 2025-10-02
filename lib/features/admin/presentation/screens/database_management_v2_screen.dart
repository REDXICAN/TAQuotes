// lib/features/admin/presentation/screens/database_management_v2_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/auth/models/rbac_permissions.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/utils/download_helper.dart';

// ============================================================================
// STATE MANAGEMENT
// ============================================================================

/// Tracks which row is being edited
class EditingState {
  final String? productId;
  final Map<String, dynamic>? editedData;
  final bool hasUnsavedChanges;

  EditingState({
    this.productId,
    this.editedData,
    this.hasUnsavedChanges = false,
  });

  EditingState copyWith({
    String? productId,
    Map<String, dynamic>? editedData,
    bool? hasUnsavedChanges,
  }) {
    return EditingState(
      productId: productId ?? this.productId,
      editedData: editedData ?? this.editedData,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}

/// Provider for all products (sorted by SKU)
final allProductsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseDatabase.instance
      .ref('products')
      .onValue
      .map((event) {
        if (!event.snapshot.exists) return <Map<String, dynamic>>[];

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final products = <Map<String, dynamic>>[];

        data.forEach((key, value) {
          if (value is Map) {
            final product = Map<String, dynamic>.from(value);
            product['id'] = key.toString();
            products.add(product);
          }
        });

        // Sort by SKU (same as Firebase Realtime Database)
        products.sort((a, b) {
          final skuA = a['sku']?.toString() ?? a['model']?.toString() ?? '';
          final skuB = b['sku']?.toString() ?? b['model']?.toString() ?? '';
          return skuA.compareTo(skuB);
        });

        return products;
      })
      .handleError((error) {
        AppLogger.error('Error loading products', error: error);
        return <Map<String, dynamic>>[];
      });
});

// ============================================================================
// MAIN SCREEN
// ============================================================================

class DatabaseManagementV2Screen extends ConsumerStatefulWidget {
  const DatabaseManagementV2Screen({super.key});

  @override
  ConsumerState<DatabaseManagementV2Screen> createState() => _DatabaseManagementV2ScreenState();
}

class _DatabaseManagementV2ScreenState extends ConsumerState<DatabaseManagementV2Screen> {
  EditingState _editingState = EditingState();
  final Map<String, TextEditingController> _controllers = {};
  final ScrollController _horizontalScrollController = ScrollController();
  String _searchQuery = '';

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // All field names in Firebase Realtime Database order
  final List<String> _fieldNames = [
    'sku',
    'model',
    'name',
    'displayName',
    'description',
    'category',
    'subcategory',
    'productType',
    'price',
    'stock',
    'warehouse',
    'dimensions',
    'dimensionsMetric',
    'weight',
    'weightMetric',
    'voltage',
    'amperage',
    'phase',
    'frequency',
    'plugType',
    'temperatureRange',
    'temperatureRangeMetric',
    'refrigerant',
    'compressor',
    'capacity',
    'doors',
    'shelves',
    'features',
    'certifications',
    'imageUrl',
    'imageUrl2',
    'thumbnailUrl',
    'pdfUrl',
    'isTopSeller',
    'createdAt',
    'updatedAt',
  ];

  final Map<String, String> _fieldLabels = {
    'sku': 'SKU',
    'model': 'Model',
    'name': 'Name',
    'displayName': 'Display Name',
    'description': 'Description',
    'category': 'Category',
    'subcategory': 'Subcategory',
    'productType': 'Product Type',
    'price': 'Price',
    'stock': 'Stock',
    'warehouse': 'Warehouse',
    'dimensions': 'Dimensions',
    'dimensionsMetric': 'Dimensions (Metric)',
    'weight': 'Weight',
    'weightMetric': 'Weight (Metric)',
    'voltage': 'Voltage',
    'amperage': 'Amperage',
    'phase': 'Phase',
    'frequency': 'Frequency',
    'plugType': 'Plug Type',
    'temperatureRange': 'Temperature Range',
    'temperatureRangeMetric': 'Temperature Range (Metric)',
    'refrigerant': 'Refrigerant',
    'compressor': 'Compressor',
    'capacity': 'Capacity',
    'doors': 'Doors',
    'shelves': 'Shelves',
    'features': 'Features',
    'certifications': 'Certifications',
    'imageUrl': 'Image URL (P.1)',
    'imageUrl2': 'Image URL (P.2)',
    'thumbnailUrl': 'Thumbnail URL',
    'pdfUrl': 'PDF URL',
    'isTopSeller': 'Top Seller',
    'createdAt': 'Created At',
    'updatedAt': 'Updated At',
  };

  @override
  Widget build(BuildContext context) {
    final hasAccessAsync = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAccessAsync.when(
      data: (hasAccess) {
        if (!hasAccess) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: const Center(child: Text('You do not have permission to access this page')),
          );
        }

        return PopScope(
          canPop: !_editingState.hasUnsavedChanges,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (!didPop && _editingState.hasUnsavedChanges) {
              final shouldPop = await _showUnsavedChangesDialog();
              if (!mounted) return;
              if (!context.mounted) return;
              if (shouldPop == true) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Database Management'),
              actions: [
                if (_editingState.hasUnsavedChanges) ...[
                  TextButton.icon(
                    onPressed: _discardChanges,
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Discard', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                IconButton(
                  icon: const Icon(Icons.file_download),
                  tooltip: 'Export to JSON',
                  onPressed: _exportToJson,
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: 'Import from JSON',
                  onPressed: _importFromJson,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by SKU, model, name...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  ),
                ),

                // Data table
                Expanded(
                  child: _buildDataTable(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDataTable() {
    final productsAsync = ref.watch(allProductsProvider);

    return productsAsync.when(
      data: (products) {
        // Filter by search query
        final filteredProducts = _searchQuery.isEmpty
            ? products
            : products.where((p) {
                final sku = p['sku']?.toString().toLowerCase() ?? '';
                final model = p['model']?.toString().toLowerCase() ?? '';
                final name = p['name']?.toString().toLowerCase() ?? '';
                return sku.contains(_searchQuery) ||
                    model.contains(_searchQuery) ||
                    name.contains(_searchQuery);
              }).toList();

        if (filteredProducts.isEmpty) {
          return Center(
            child: Text(_searchQuery.isEmpty ? 'No products found' : 'No results for "$_searchQuery"'),
          );
        }

        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontalScrollController,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 56,
                dataRowMinHeight: 72,
                dataRowMaxHeight: 72,
                columns: [
                  // Actions column (fixed left)
                  const DataColumn(
                    label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  // All field columns
                  ..._fieldNames.map((fieldName) {
                    return DataColumn(
                      label: Text(
                        _fieldLabels[fieldName] ?? fieldName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ],
                rows: filteredProducts.map((product) {
                  final productId = product['id'] as String;
                  final isEditing = _editingState.productId == productId;

                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>(
                      (states) => isEditing ? Colors.blue.withValues(alpha: 0.1) : null,
                    ),
                    cells: [
                      // Actions cell
                      DataCell(_buildActionsCell(product, isEditing)),
                      // Field cells
                      ..._fieldNames.map((fieldName) {
                        return DataCell(_buildFieldCell(product, fieldName, isEditing));
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error loading products: $error')),
    );
  }

  Widget _buildActionsCell(Map<String, dynamic> product, bool isEditing) {
    final productId = product['id'] as String;

    if (isEditing) {
      return SizedBox(
        width: 120,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.save, color: Colors.green),
              tooltip: 'Save',
              onPressed: _saveChanges,
              iconSize: 20,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Cancel',
              onPressed: _discardChanges,
              iconSize: 20,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 120,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            tooltip: 'Edit',
            onPressed: () => _startEditing(productId, product),
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, color: Colors.orange),
            tooltip: 'Duplicate',
            onPressed: () => _duplicateProduct(product),
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () => _deleteProduct(productId, product),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCell(Map<String, dynamic> product, String fieldName, bool isEditing) {
    final productId = product['id'] as String;
    final value = product[fieldName];

    if (isEditing && _editingState.editedData != null) {
      final editedValue = _editingState.editedData![fieldName] ?? value;
      final controllerKey = '$productId-$fieldName';

      // Create or update controller
      if (!_controllers.containsKey(controllerKey)) {
        _controllers[controllerKey] = TextEditingController(
          text: _formatValueForDisplay(editedValue),
        );
      }

      // Different input types based on field
      if (fieldName == 'isTopSeller') {
        return Checkbox(
          value: editedValue == true || editedValue == 'true',
          onChanged: (val) => _updateField(fieldName, val),
        );
      }

      if (fieldName == 'price' || fieldName == 'stock' || fieldName == 'doors' || fieldName == 'shelves') {
        return SizedBox(
          width: 100,
          child: TextField(
            controller: _controllers[controllerKey],
            keyboardType: TextInputType.number,
            inputFormatters: [
              if (fieldName == 'price')
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              if (fieldName != 'price')
                FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(8),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              if (fieldName == 'price' && val.isNotEmpty) {
                _updateField(fieldName, double.tryParse(val) ?? 0.0);
              } else if (fieldName != 'price' && val.isNotEmpty) {
                _updateField(fieldName, int.tryParse(val) ?? 0);
              } else {
                _updateField(fieldName, val);
              }
            },
          ),
        );
      }

      // Large text fields
      if (fieldName == 'description' || fieldName == 'features') {
        return SizedBox(
          width: 300,
          child: TextField(
            controller: _controllers[controllerKey],
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(8),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => _updateField(fieldName, val),
          ),
        );
      }

      // Read-only fields
      if (fieldName == 'createdAt' || fieldName == 'updatedAt') {
        return SizedBox(
          width: 150,
          child: Text(
            _formatValueForDisplay(editedValue),
            style: const TextStyle(color: Colors.grey),
          ),
        );
      }

      // Regular text field
      return SizedBox(
        width: 150,
        child: TextField(
          controller: _controllers[controllerKey],
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(8),
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => _updateField(fieldName, val),
        ),
      );
    }

    // Display mode (not editing)
    final displayValue = _formatValueForDisplay(value);
    return SizedBox(
      width: fieldName == 'description' || fieldName == 'features' ? 300 : 150,
      child: Text(
        displayValue,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatValueForDisplay(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) return value.toString();
    if (value is String) return value;
    return value.toString();
  }

  // ============================================================================
  // EDITING OPERATIONS
  // ============================================================================

  void _startEditing(String productId, Map<String, dynamic> product) {
    if (_editingState.hasUnsavedChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save or discard current changes first')),
      );
      return;
    }

    setState(() {
      _editingState = EditingState(
        productId: productId,
        editedData: Map<String, dynamic>.from(product),
        hasUnsavedChanges: false,
      );
    });
  }

  void _updateField(String fieldName, dynamic value) {
    if (_editingState.editedData == null) return;

    setState(() {
      _editingState.editedData![fieldName] = value;
      _editingState = _editingState.copyWith(hasUnsavedChanges: true);
    });
  }

  Future<void> _saveChanges() async {
    if (_editingState.productId == null || _editingState.editedData == null) return;

    try {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Update timestamp
      _editingState.editedData!['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      // Remove id field (not stored in database)
      final dataToSave = Map<String, dynamic>.from(_editingState.editedData!);
      dataToSave.remove('id');

      // Save to Firebase
      await FirebaseDatabase.instance
          .ref('products/${_editingState.productId}')
          .set(dataToSave);

      // Close loading
      if (!mounted) return;
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Clear editing state
      setState(() {
        _controllers.clear();
        _editingState = EditingState();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  void _discardChanges() {
    setState(() {
      _controllers.clear();
      _editingState = EditingState();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes discarded')),
    );
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Discard and leave
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveChanges();
              if (!mounted) return;
              if (!context.mounted) return;
              Navigator.of(context).pop(true); // Save and leave
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  Future<void> _duplicateProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Product'),
        content: Text('Create a copy of ${product['sku'] ?? product['model']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Create copy with new ID
      final newProduct = Map<String, dynamic>.from(product);
      newProduct.remove('id');
      newProduct['sku'] = '${newProduct['sku']}-COPY';
      newProduct['model'] = '${newProduct['model']}-COPY';
      newProduct['createdAt'] = DateTime.now().millisecondsSinceEpoch;
      newProduct['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      // Generate new ID
      final newRef = FirebaseDatabase.instance.ref('products').push();
      await newRef.set(newProduct);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product duplicated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error duplicating: $e')),
      );
    }
  }

  Future<void> _deleteProduct(String productId, Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product['sku'] ?? product['model']}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseDatabase.instance.ref('products/$productId').remove();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e')),
      );
    }
  }

  // ============================================================================
  // IMPORT/EXPORT
  // ============================================================================

  Future<void> _exportToJson() async {
    try {
      final productsAsync = ref.read(allProductsProvider);
      final products = productsAsync.value;

      if (products == null || products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products to export')),
        );
        return;
      }

      // Convert to JSON
      final jsonData = jsonEncode(products);
      final bytes = utf8.encode(jsonData);

      // Download
      await DownloadHelper.downloadFile(
        bytes: bytes,
        filename: 'products_export_${DateTime.now().millisecondsSinceEpoch}.json',
        mimeType: 'application/json',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${products.length} products')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting: $e')),
      );
    }
  }

  Future<void> _importFromJson() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file')),
        );
        return;
      }

      // Parse JSON
      final jsonString = utf8.decode(file.bytes!);
      final dynamic jsonData = jsonDecode(jsonString);

      List<Map<String, dynamic>> products;
      if (jsonData is List) {
        products = jsonData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (jsonData is Map) {
        products = [Map<String, dynamic>.from(jsonData)];
      } else {
        throw Exception('Invalid JSON format');
      }

      // Show confirmation
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Products'),
          content: Text('Import ${products.length} products?\n\nExisting products with the same ID will be overwritten.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (confirmed != true) return;

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Importing products...'),
            ],
          ),
        ),
      );

      // Import products
      int imported = 0;
      for (final product in products) {
        final productId = product['id'] as String?;
        product.remove('id'); // Don't store id in database

        if (productId != null && productId.isNotEmpty) {
          await FirebaseDatabase.instance.ref('products/$productId').set(product);
        } else {
          await FirebaseDatabase.instance.ref('products').push().set(product);
        }
        imported++;
      }

      // Close loading
      if (!mounted) return;
      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $imported products successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing: $e')),
      );
    }
  }
}
