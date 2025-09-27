// lib/core/utils/warehouse_utils.dart

import 'package:flutter/material.dart';

/// Utility class for warehouse code management and nomenclature
class WarehouseUtils {
  // Private constructor to prevent instantiation
  WarehouseUtils._();

  /// Map of warehouse codes to their full descriptions
  static const Map<String, String> warehouseDescriptions = {
    '999': 'MERCANCIA APARTADA (Reserved Merchandise)',
    'CA1': 'California Warehouse 1',
    'CA2': 'California Warehouse 2',
    'CA3': 'California Warehouse 3',
    'CA4': 'California Warehouse 4',
    'CA': 'California Main Warehouse',
    'COCZ': 'Coahuila Cool Zone',
    'COPZ': 'Coahuila Parts Zone',
    'INT': 'International Warehouse',
    'MEE': 'Mexico Export Warehouse',
    'PU': 'Pick Up Location',
    'SI': 'Special Inventory',
    'XCA': 'Export California',
    'XPU': 'Export Pick Up',
  };

  /// Map of warehouse codes to their short display names
  static const Map<String, String> warehouseShortNames = {
    '999': 'Reserved Merch.',
    'CA1': 'CA1',
    'CA2': 'CA2',
    'CA3': 'CA3',
    'CA4': 'CA4',
    'CA': 'CA Main',
    'COCZ': 'Coahuila CZ',
    'COPZ': 'Coahuila PZ',
    'INT': 'International',
    'MEE': 'Mexico Export',
    'PU': 'Pick Up',
    'SI': 'Special Inv.',
    'XCA': 'Export CA',
    'XPU': 'Export PU',
  };

  /// Map of warehouse codes to their locations/regions
  static const Map<String, String> warehouseLocations = {
    '999': 'Mexico (Reserved)',
    'CA1': 'California, USA',
    'CA2': 'California, USA',
    'CA3': 'California, USA',
    'CA4': 'California, USA',
    'CA': 'California, USA',
    'COCZ': 'Coahuila, Mexico',
    'COPZ': 'Coahuila, Mexico',
    'INT': 'International',
    'MEE': 'Mexico',
    'PU': 'Multiple Locations',
    'SI': 'Special Location',
    'XCA': 'Export - California',
    'XPU': 'Export - Pick Up',
  };

  /// Mexican warehouses (priority display)
  static const List<String> mexicanWarehouses = ['999', 'COCZ', 'COPZ', 'MEE'];

  /// US warehouses
  static const List<String> usWarehouses = ['CA1', 'CA2', 'CA3', 'CA4', 'CA'];

  /// Export warehouses
  static const List<String> exportWarehouses = ['XCA', 'XPU'];

  /// Get the full description for a warehouse code
  static String getDescription(String warehouseCode) {
    return warehouseDescriptions[warehouseCode] ?? 'Unknown Warehouse ($warehouseCode)';
  }

  /// Get the short display name for a warehouse code
  static String getShortName(String warehouseCode) {
    return warehouseShortNames[warehouseCode] ?? warehouseCode;
  }

  /// Get the location for a warehouse code
  static String getLocation(String warehouseCode) {
    return warehouseLocations[warehouseCode] ?? 'Unknown Location';
  }

  /// Check if a warehouse is in Mexico
  static bool isMexicanWarehouse(String warehouseCode) {
    return mexicanWarehouses.contains(warehouseCode);
  }

  /// Check if a warehouse is in the US
  static bool isUSWarehouse(String warehouseCode) {
    return usWarehouses.contains(warehouseCode);
  }

  /// Check if a warehouse is for export
  static bool isExportWarehouse(String warehouseCode) {
    return exportWarehouses.contains(warehouseCode);
  }

  /// Get color for warehouse display based on type
  static Color getWarehouseColor(String warehouseCode) {
    if (warehouseCode == '999') {
      return Colors.amber; // Special color for main warehouse
    } else if (isMexicanWarehouse(warehouseCode)) {
      return Colors.green;
    } else if (isUSWarehouse(warehouseCode)) {
      return Colors.blue;
    } else if (isExportWarehouse(warehouseCode)) {
      return Colors.purple;
    } else {
      return Colors.grey;
    }
  }

  /// Get icon for warehouse type
  static IconData getWarehouseIcon(String warehouseCode) {
    if (warehouseCode == '999') {
      return Icons.inventory_2; // Reserved merchandise
    } else if (isMexicanWarehouse(warehouseCode)) {
      return Icons.location_on; // Mexican location
    } else if (isUSWarehouse(warehouseCode)) {
      return Icons.warehouse; // US warehouse
    } else if (isExportWarehouse(warehouseCode)) {
      return Icons.flight_takeoff; // Export
    } else {
      return Icons.storage;
    }
  }

  /// Generate comprehensive tooltip message for all warehouses
  static String getComprehensiveTooltip() {
    final buffer = StringBuffer();
    buffer.writeln('Warehouse Codes:');
    buffer.writeln();

    // Main warehouse first
    buffer.writeln('999 - ${getDescription('999')}');
    buffer.writeln();

    // Mexican warehouses
    buffer.writeln('Mexican Warehouses:');
    for (final warehouse in mexicanWarehouses.where((w) => w != '999')) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // US warehouses
    buffer.writeln('US Warehouses:');
    for (final warehouse in usWarehouses) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // Export warehouses
    buffer.writeln('Export Warehouses:');
    for (final warehouse in exportWarehouses) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // Other warehouses
    final otherWarehouses = warehouseDescriptions.keys
        .where((w) => !mexicanWarehouses.contains(w) &&
                     !usWarehouses.contains(w) &&
                     !exportWarehouses.contains(w))
        .toList();

    if (otherWarehouses.isNotEmpty) {
      buffer.writeln('Other Warehouses:');
      for (final warehouse in otherWarehouses) {
        buffer.writeln('$warehouse - ${getDescription(warehouse)}');
      }
    }

    return buffer.toString().trim();
  }

  /// Generate tooltip for specific warehouse category
  static String getCategoryTooltip(String category) {
    switch (category.toLowerCase()) {
      case 'mexican':
        return mexicanWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      case 'us':
        return usWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      case 'export':
        return exportWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      default:
        return getComprehensiveTooltip();
    }
  }

  /// Get all warehouse codes sorted by priority (Mexican first, then US, then export)
  static List<String> getAllWarehouseCodesSorted() {
    final sorted = <String>[];
    sorted.addAll(mexicanWarehouses);
    sorted.addAll(usWarehouses);
    sorted.addAll(exportWarehouses);

    // Add any remaining warehouses
    final remaining = warehouseDescriptions.keys
        .where((w) => !sorted.contains(w))
        .toList()
        ..sort();
    sorted.addAll(remaining);

    return sorted;
  }

  /// Create a formatted dropdown item for warehouse selection
  static Widget createWarehouseDropdownItem(String warehouseCode, {bool showLocation = false}) {
    return Row(
      children: [
        Icon(
          getWarehouseIcon(warehouseCode),
          size: 16,
          color: getWarehouseColor(warehouseCode),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$warehouseCode - ${getShortName(warehouseCode)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (showLocation)
                Text(
                  getLocation(warehouseCode),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Create an info tooltip widget for warehouse help
  static Widget createInfoTooltip(BuildContext context, {String? customMessage}) {
    return Tooltip(
      message: customMessage ?? getComprehensiveTooltip(),
      textStyle: const TextStyle(fontSize: 12),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      preferBelow: false,
      child: Icon(
        Icons.info_outline,
        size: 16,
        color: Theme.of(context).primaryColor.withOpacity(0.7),
      ),
    );
  }
}