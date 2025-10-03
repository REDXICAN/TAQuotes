// lib/features/admin/presentation/widgets/enhanced_backup_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:typed_data';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/database_backup_service.dart';
import '../../../../core/utils/download_helper.dart';

class EnhancedBackupWidget extends ConsumerStatefulWidget {
  const EnhancedBackupWidget({super.key});

  @override
  ConsumerState<EnhancedBackupWidget> createState() => _EnhancedBackupWidgetState();
}

class _EnhancedBackupWidgetState extends ConsumerState<EnhancedBackupWidget> {
  bool _isExporting = false;
  bool _isImporting = false;
  String _statusMessage = '';

  Future<void> _exportDatabase() async {
    setState(() {
      _isExporting = true;
      _statusMessage = 'Preparing database export...';
    });

    try {
      final backupService = DatabaseBackupService();

      // Create the full backup
      final excelBytes = await backupService.createFullBackup();

      // Download the file
      await DownloadHelper.downloadFile(
        bytes: excelBytes,
        filename: 'turboair_database_backup_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );

      setState(() {
        _statusMessage = 'Database exported successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database backup downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error exporting database', error: e);
      setState(() {
        _statusMessage = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _importDatabase() async {
    // Show warning dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Database'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ WARNING: This will modify your database.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            SizedBox(height: 16),
            Text('Instructions:'),
            Text('1. Select the Excel file you exported earlier'),
            Text('2. Make sure you have edited it correctly'),
            Text('3. Products sheet will update existing items'),
            Text('4. New items will be added automatically'),
            SizedBox(height: 16),
            Text(
              'It is recommended to backup first before importing.',
              style: TextStyle(fontStyle: FontStyle.italic),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Proceed with Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Pick the Excel file
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isImporting = true;
          _statusMessage = 'Reading Excel file...';
        });

        await _processImport(result.files.single.bytes!);
      }
    } catch (e) {
      AppLogger.error('Error picking file', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processImport(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      final database = FirebaseDatabase.instance;

      int productsUpdated = 0;
      int productsAdded = 0;
      int clientsProcessed = 0;

      // Process Products Sheet
      if (excel.tables.containsKey('Products')) {
        setState(() => _statusMessage = 'Importing products...');

        final sheet = excel.tables['Products']!;
        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          try {
            final productId = row[0]?.value?.toString() ?? '';
            final sku = row[1]?.value?.toString() ?? '';
            final model = row[2]?.value?.toString() ?? '';
            final name = row[3]?.value?.toString() ?? '';
            final description = row[4]?.value?.toString() ?? '';
            final price = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
            final category = row[6]?.value?.toString() ?? '';
            final stock = int.tryParse(row[7]?.value?.toString() ?? '0') ?? 0;

            if (productId.isNotEmpty && name.isNotEmpty) {
              final productData = {
                'sku': sku,
                'model': model,
                'name': name,
                'displayName': name,
                'description': description,
                'price': price,
                'category': category,
                'stock': stock,
                'totalStock': stock,
                'updatedAt': ServerValue.timestamp,
              };

              // Check if product exists
              final snapshot = await database.ref('products/$productId').get();
              if (snapshot.exists) {
                await database.ref('products/$productId').update(productData);
                productsUpdated++;
              } else {
                await database.ref('products/$productId').set(productData);
                productsAdded++;
              }
            }
          } catch (e) {
            AppLogger.error('Error importing product row $i', error: e);
          }
        }
      }

      // Process Clients Sheet
      if (excel.tables.containsKey('Clients')) {
        setState(() => _statusMessage = 'Importing clients...');

        final sheet = excel.tables['Clients']!;
        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          try {
            final clientId = row[0]?.value?.toString() ?? '';
            final userId = row[1]?.value?.toString() ?? '';
            final company = row[2]?.value?.toString() ?? '';
            final contactName = row[3]?.value?.toString() ?? '';
            final email = row[4]?.value?.toString() ?? '';
            final phone = row[5]?.value?.toString() ?? '';
            final address = row[6]?.value?.toString() ?? '';

            if (clientId.isNotEmpty && userId.isNotEmpty && company.isNotEmpty) {
              final clientData = {
                'company': company,
                'contactName': contactName,
                'name': contactName,
                'email': email,
                'phone': phone,
                'address': address,
                'updatedAt': ServerValue.timestamp,
              };

              await database.ref('clients/$userId/$clientId').set(clientData);
              clientsProcessed++;
            }
          } catch (e) {
            AppLogger.error('Error importing client row $i', error: e);
          }
        }
      }

      // Process Warehouse Stock Sheet
      if (excel.tables.containsKey('Warehouse Stock')) {
        setState(() => _statusMessage = 'Importing warehouse stock...');

        final sheet = excel.tables['Warehouse Stock']!;
        final warehouseData = <String, Map<String, dynamic>>{};

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          try {
            final sku = row[0]?.value?.toString() ?? '';
            final warehouse = row[2]?.value?.toString() ?? '';
            final available = int.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
            final reserved = int.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;

            if (sku.isNotEmpty && warehouse.isNotEmpty) {
              if (!warehouseData.containsKey(sku)) {
                warehouseData[sku] = {};
              }
              warehouseData[sku]![warehouse] = {
                'available': available,
                'reserved': reserved,
                'lastUpdated': ServerValue.timestamp,
              };
            }
          } catch (e) {
            AppLogger.error('Error importing stock row $i', error: e);
          }
        }

        // Update warehouse stock in database
        for (final entry in warehouseData.entries) {
          await database.ref('warehouse_stock/${entry.key}').set(entry.value);
        }
      }

      setState(() {
        _statusMessage = '''Import completed:
• Products updated: $productsUpdated
• Products added: $productsAdded
• Clients processed: $clientsProcessed''';
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database imported successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error processing import', error: e);
      setState(() {
        _statusMessage = 'Import failed: $e';
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup, color: theme.primaryColor, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Database Backup & Restore',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Export the entire database to Excel for editing and backup. Import modified Excel files to update the database.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Export Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.download, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Export Database',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Download the complete database as an Excel file with separate sheets for Products, Clients, Quotes, Users, and Warehouse Stock.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportDatabase,
                    icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                    label: Text(_isExporting ? 'Exporting...' : 'Export to Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Import Section
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
                  Row(
                    children: [
                      const Icon(Icons.upload, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Import Database',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload an edited Excel file to update the database. Products will be updated or added based on their IDs.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ Warning: This will modify your database. Always backup first!',
                    style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isImporting ? null : _importDatabase,
                    icon: _isImporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                    label: Text(_isImporting ? 'Importing...' : 'Import from Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Status Message
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('Error')
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('Error')
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage.contains('Error') ? Icons.error : Icons.info,
                      color: _statusMessage.contains('Error') ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: _statusMessage.contains('Error') ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Instructions
            const Text(
              'How to use:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Export: Click "Export to Excel" to download the current database',
              style: TextStyle(fontSize: 12),
            ),
            const Text(
              '2. Edit: Open the Excel file and make your changes',
              style: TextStyle(fontSize: 12),
            ),
            const Text(
              '3. Import: Click "Import from Excel" and select your edited file',
              style: TextStyle(fontSize: 12),
            ),
            const Text(
              '4. Review: Check the status message for import results',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}