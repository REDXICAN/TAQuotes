// lib/features/admin/presentation/widgets/spare_parts_import_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../../../core/services/spare_parts_import_service.dart';
import '../../../../core/services/app_logger.dart';

// Provider for the spare parts import service
final sparePartsImportServiceProvider = Provider<SparePartsImportService>((ref) {
  return SparePartsImportService();
});

// Provider for spare parts import state
final sparePartsImportProvider = StateNotifierProvider<SparePartsImportNotifier, SparePartsImportState>((ref) {
  final service = ref.watch(sparePartsImportServiceProvider);
  return SparePartsImportNotifier(service);
});

// Import state
class SparePartsImportState {
  final bool isImporting;
  final bool hasImported;
  final String? error;
  final int? importedCount;
  final int? totalCount;

  const SparePartsImportState({
    this.isImporting = false,
    this.hasImported = false,
    this.error,
    this.importedCount,
    this.totalCount,
  });

  SparePartsImportState copyWith({
    bool? isImporting,
    bool? hasImported,
    String? error,
    int? importedCount,
    int? totalCount,
  }) {
    return SparePartsImportState(
      isImporting: isImporting ?? this.isImporting,
      hasImported: hasImported ?? this.hasImported,
      error: error ?? this.error,
      importedCount: importedCount ?? this.importedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

// State notifier for managing import process
class SparePartsImportNotifier extends StateNotifier<SparePartsImportState> {
  final SparePartsImportService _service;

  SparePartsImportNotifier(this._service) : super(const SparePartsImportState());

  /// Import spare parts from the extracted JSON file
  Future<void> importSparePartsFromJsonFile() async {
    if (state.isImporting) return;

    state = state.copyWith(isImporting: true, error: null);

    try {
      // First try to use the default file location
      String? jsonString;

      // Path to the extracted spare parts JSON file
      final jsonFilePath = 'spare_parts_extracted.json';
      final file = File(jsonFilePath);

      if (await file.exists()) {
        jsonString = await file.readAsString();
      } else {
        // If file doesn't exist, prompt user to select file
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          dialogTitle: 'Select spare_parts_extracted.json file',
        );

        if (result == null || result.files.isEmpty) {
          state = state.copyWith(
            isImporting: false,
            error: 'No file selected. Please select the spare_parts_extracted.json file.',
          );
          return;
        }

        final pickedFile = result.files.first;

        if (pickedFile.bytes != null) {
          // For web platform - use bytes
          jsonString = String.fromCharCodes(pickedFile.bytes!);
        } else if (pickedFile.path != null) {
          // For mobile/desktop platforms - use path
          final selectedFile = File(pickedFile.path!);
          jsonString = await selectedFile.readAsString();
        } else {
          state = state.copyWith(
            isImporting: false,
            error: 'Could not read selected file.',
          );
          return;
        }
      }

      if (jsonString.isEmpty) {
        state = state.copyWith(
          isImporting: false,
          error: 'Failed to read JSON file content.',
        );
        return;
      }

      // Parse the JSON file
      final List<dynamic> sparePartsData = jsonDecode(jsonString);

      state = state.copyWith(totalCount: sparePartsData.length);

      // Convert to proper format
      final List<Map<String, dynamic>> convertedData = sparePartsData
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      // Import the data
      final success = await _service.importSparePartsFromData(convertedData);

      if (success) {
        state = state.copyWith(
          isImporting: false,
          hasImported: true,
          importedCount: convertedData.length,
        );
        AppLogger.info('Successfully imported ${convertedData.length} spare parts',
                      category: LogCategory.database);
      } else {
        state = state.copyWith(
          isImporting: false,
          error: 'Failed to import spare parts. Check logs for details.',
        );
      }

    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: 'Error during import: ${e.toString()}',
      );
      AppLogger.error('Spare parts import failed', error: e, category: LogCategory.database);
    }
  }

  /// Get spare parts count from Firebase
  Future<void> getSparePartsCount() async {
    try {
      final spareParts = await _service.getSparePartsFromFirebase();
      state = state.copyWith(importedCount: spareParts.length);
    } catch (e) {
      AppLogger.error('Failed to get spare parts count', error: e, category: LogCategory.database);
    }
  }

  /// Clear spare parts (for testing)
  Future<void> clearSparePartsData() async {
    if (state.isImporting) return;

    state = state.copyWith(isImporting: true, error: null);

    try {
      final success = await _service.deleteAllSpareParts();

      if (success) {
        state = state.copyWith(
          isImporting: false,
          hasImported: false,
          importedCount: 0,
        );
        AppLogger.info('Successfully cleared all spare parts data',
                      category: LogCategory.database);
      } else {
        state = state.copyWith(
          isImporting: false,
          error: 'Failed to clear spare parts data.',
        );
      }

    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: 'Error clearing data: ${e.toString()}',
      );
      AppLogger.error('Spare parts clearing failed', error: e, category: LogCategory.database);
    }
  }

  /// Reset state
  void reset() {
    state = const SparePartsImportState();
  }
}

class SparePartsImportWidget extends ConsumerStatefulWidget {
  const SparePartsImportWidget({super.key});

  @override
  ConsumerState<SparePartsImportWidget> createState() => _SparePartsImportWidgetState();
}

class _SparePartsImportWidgetState extends ConsumerState<SparePartsImportWidget> {
  @override
  void initState() {
    super.initState();
    // Get current count on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sparePartsImportProvider.notifier).getSparePartsCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sparePartsImportProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.precision_manufacturing,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Spare Parts Import',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status info
            if (state.importedCount != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current spare parts in database: ${state.importedCount}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Description
            Text(
              'Import real spare parts data from the extracted JSON file (spare_parts_extracted.json). '
              'This will add 94 spare parts with actual warehouse stock levels from the Mexico inventory. '
              'Run the extraction script first to create the JSON file from the Excel inventory.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 16),

            // Progress indicator
            if (state.isImporting) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Importing spare parts...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (state.totalCount != null)
                Text(
                  'Total items to import: ${state.totalCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
            ],

            // Error message
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Success message
            if (state.hasImported && !state.isImporting && state.error == null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Successfully imported ${state.importedCount} spare parts!',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: state.isImporting
                      ? null
                      : () {
                          ref.read(sparePartsImportProvider.notifier)
                              .importSparePartsFromJsonFile();
                        },
                  icon: const Icon(Icons.upload),
                  label: const Text('Import Spare Parts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: state.isImporting
                      ? null
                      : () {
                          ref.read(sparePartsImportProvider.notifier)
                              .getSparePartsCount();
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Count'),
                ),

                if (state.importedCount != null && state.importedCount! > 0)
                  OutlinedButton.icon(
                    onPressed: state.isImporting
                        ? null
                        : () => _showClearConfirmation(context),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Spare Parts'),
          content: const Text(
            'Are you sure you want to delete all spare parts data from Firebase? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(sparePartsImportProvider.notifier).clearSparePartsData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }
}