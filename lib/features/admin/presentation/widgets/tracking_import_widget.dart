// lib/features/admin/presentation/widgets/tracking_import_widget.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:typed_data';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/models/shipment_tracking.dart';

/// Widget for importing shipment tracking data from Excel files
class TrackingImportWidget extends StatefulWidget {
  const TrackingImportWidget({super.key});

  @override
  State<TrackingImportWidget> createState() => _TrackingImportWidgetState();
}

class _TrackingImportWidgetState extends State<TrackingImportWidget> {
  final TrackingService _trackingService = TrackingService();

  bool _isLoading = false;
  bool _hasPreview = false;
  List<Map<String, dynamic>> _previewData = [];
  String? _fileName;
  Uint8List? _fileBytes;

  // Column mapping configuration
  final Map<String, String> _columnMapping = {
    'trackingNumber': 'Tracking Number',
    'quoteNumber': 'Quote Number',
    'orderReference': 'Order Reference',
    'customerName': 'Customer Name',
    'customerEmail': 'Customer Email',
    'status': 'Status',
    'carrier': 'Carrier',
    'origin': 'Origin',
    'destination': 'Destination',
    'currentLocation': 'Current Location',
    'shipmentDate': 'Shipment Date',
    'estimatedDeliveryDate': 'Estimated Delivery',
    'actualDeliveryDate': 'Actual Delivery',
    'weight': 'Weight',
    'numberOfPackages': 'Packages',
    'notes': 'Notes',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.local_shipping, size: 32, color: theme.primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Shipment Tracking Data',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload an Excel file with shipment tracking information',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Instructions
            _buildInstructionsCard(),

            const SizedBox(height: 24),

            // Upload section
            if (!_hasPreview) ...[
              _buildUploadSection(theme),
            ] else ...[
              _buildPreviewSection(theme),
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Excel File Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Your Excel file should include the following columns:'),
          const SizedBox(height: 8),
          ..._columnMapping.values.map((col) => Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text('• $col', style: const TextStyle(fontSize: 13)),
          )),
          const SizedBox(height: 12),
          const Text(
            'Note: Only "Tracking Number" and "Status" are required. Other fields are optional.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload,
                size: 64,
                color: theme.primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Click to select Excel file',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Supports .xlsx files',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.file_upload),
                label: const Text('Select File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Download template button
        OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download),
          label: const Text('Download Excel Template'),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File loaded: $_fileName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_previewData.length} records found',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _clearPreview,
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Preview table
        const Text(
          'Preview (first 5 rows)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Tracking #')),
                DataColumn(label: Text('Quote #')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Carrier')),
              ],
              rows: _previewData.take(5).map((row) {
                return DataRow(cells: [
                  DataCell(Text(row['trackingNumber']?.toString() ?? '-')),
                  DataCell(Text(row['quoteNumber']?.toString() ?? '-')),
                  DataCell(Text(row['customerName']?.toString() ?? '-')),
                  DataCell(Text(row['status']?.toString() ?? '-')),
                  DataCell(Text(row['carrier']?.toString() ?? '-')),
                ]);
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _isLoading ? null : _clearPreview,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _importData,
              icon: const Icon(Icons.cloud_upload),
              label: Text('Import ${_previewData.length} Records'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showError('Failed to read file');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      await _processExcelFile(file.bytes!, file.name);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AppLogger.error('Error picking file', error: e, category: LogCategory.data);
      _showError('Error loading file: ${e.toString()}');
    }
  }

  Future<void> _processExcelFile(Uint8List bytes, String fileName) async {
    try {
      final excel = excel_pkg.Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        _showError('No sheets found in Excel file');
        return;
      }

      // Get first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        _showError('Sheet is empty');
        return;
      }

      final rows = sheet.rows;
      if (rows.length < 2) {
        _showError('File must have at least a header row and one data row');
        return;
      }

      // Parse header row
      final headers = rows[0].map((cell) => cell?.value?.toString() ?? '').toList();

      // Find column indices
      final columnIndices = <String, int>{};
      for (var entry in _columnMapping.entries) {
        final index = headers.indexWhere((h) =>
          h.toLowerCase().contains(entry.value.toLowerCase()) ||
          h.toLowerCase().replaceAll(' ', '').contains(entry.key.toLowerCase())
        );
        if (index != -1) {
          columnIndices[entry.key] = index;
        }
      }

      // Check required columns
      if (!columnIndices.containsKey('trackingNumber')) {
        _showError('Missing required column: Tracking Number');
        return;
      }

      // Parse data rows
      final data = <Map<String, dynamic>>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final rowData = <String, dynamic>{};

        for (var entry in columnIndices.entries) {
          final cellValue = row[entry.value]?.value;
          if (cellValue != null) {
            rowData[entry.key] = cellValue.toString();
          }
        }

        // Skip empty rows
        if (rowData.isEmpty || rowData['trackingNumber']?.toString().trim().isEmpty == true) {
          continue;
        }

        data.add(rowData);
      }

      if (data.isEmpty) {
        _showError('No valid data rows found');
        return;
      }

      setState(() {
        _previewData = data;
        _fileName = fileName;
        _fileBytes = bytes;
        _hasPreview = true;
      });

      AppLogger.info('Processed ${data.length} tracking records from Excel',
        category: LogCategory.business);

    } catch (e) {
      AppLogger.error('Error processing Excel file', error: e, category: LogCategory.data);
      _showError('Error processing file: ${e.toString()}');
    }
  }

  Future<void> _importData() async {
    if (_previewData.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _trackingService.bulkImportTrackings(_previewData);

      setState(() {
        _isLoading = false;
        _hasPreview = false;
        _previewData = [];
        _fileName = null;
        _fileBytes = null;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Successfully imported: ${result['success']}'),
                if (result['errors'] > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Errors: ${result['errors']}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  if (result['errorDetails'] != null && (result['errorDetails'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Error details:'),
                    ...(result['errorDetails'] as List).take(5).map((error) =>
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                          error.toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      )
                    ),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      AppLogger.info('Tracking import completed: ${result['success']} success, ${result['errors']} errors',
        category: LogCategory.business);

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AppLogger.error('Error importing tracking data', error: e, category: LogCategory.data);
      _showError('Import failed: ${e.toString()}');
    }
  }

  void _clearPreview() {
    setState(() {
      _hasPreview = false;
      _previewData = [];
      _fileName = null;
      _fileBytes = null;
    });
  }

  void _downloadTemplate() {
    // Create a sample Excel template
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel['Tracking Template'];

    // Add headers
    final headers = _columnMapping.values.toList();
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value = excel_pkg.TextCellValue(headers[i]);
    }

    // Add sample row
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      .value = excel_pkg.TextCellValue('1234567890');
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1))
      .value = excel_pkg.TextCellValue('Q-2025-001');
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1))
      .value = excel_pkg.TextCellValue('ORD-123');
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1))
      .value = excel_pkg.TextCellValue('John Doe');
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1))
      .value = excel_pkg.TextCellValue('john@example.com');
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1))
      .value = excel_pkg.TextCellValue('In Transit');
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1))
      .value = excel_pkg.TextCellValue('FedEx');

    // Generate file bytes
    final fileBytes = excel.encode();

    if (fileBytes != null) {
      // Trigger download
      // Note: This would need platform-specific implementation
      // For now, just log
      AppLogger.info('Template download requested', category: LogCategory.business);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template format shown in instructions above'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
