// lib/core/utils/warehouse_utils.dart

import 'package:flutter/material.dart';

/// Utility class for warehouse code management and nomenclature
class WarehouseUtils {
  // Private constructor to prevent instantiation
  WarehouseUtils._();

  /// Map of warehouse codes to their full descriptions
  static const Map<String, String> warehouseDescriptions = {
    '999': 'MERCANCIA APARTADA',
    'CA': 'CANCUN',
    'CA1': 'CANCUN EXHIBICION',
    'CA2': 'CANCUN EQUIPOS A PRUEBA',
    'CA3': 'CANCUN LABORATORIO',
    'CA4': 'CANCUN AREA DE AJUSTE',
    'COCZ': 'CONSIGNACION CANCUN ZICOR',
    'COPZ': 'CONSIGNACION PUEBLA ZICOR',
    'INT': 'INTERNACIONAL',
    'MEE': 'MEXICO PROYECTOS ESPECIALES',
    'PU': 'PUEBLA BINEX',
    'SI': 'SILAO BINEX',
    'XCA': 'REFRIGERATION X CANCUN',
    'XPU': 'REFRIGERATION X PUEBLA',
    'XZRE': 'REFACCIONES REFRIGERATION X',
    'ZRE': 'REFACCIONES',
  };

  /// Map of warehouse codes to their short display names
  static const Map<String, String> warehouseShortNames = {
    '999': 'Apartada',
    'CA': 'Cancún',
    'CA1': 'Cancún Exhib.',
    'CA2': 'Cancún Prueba',
    'CA3': 'Cancún Lab.',
    'CA4': 'Cancún Ajuste',
    'COCZ': 'Cons. CUN Zicor',
    'COPZ': 'Cons. PU Zicor',
    'INT': 'Internacional',
    'MEE': 'MX Proy. Esp.',
    'PU': 'Puebla',
    'SI': 'Silao',
    'XCA': 'Refrig. X CUN',
    'XPU': 'Refrig. X PU',
    'XZRE': 'Refacc. Refrig. X',
    'ZRE': 'Refacciones',
  };

  /// Map of warehouse codes to their locations/regions
  static const Map<String, String> warehouseLocations = {
    '999': 'Mexico (Mercancia Apartada)',
    'CA': 'Cancún, Quintana Roo',
    'CA1': 'Cancún, Quintana Roo (Exhibición)',
    'CA2': 'Cancún, Quintana Roo (Equipos a Prueba)',
    'CA3': 'Cancún, Quintana Roo (Laboratorio)',
    'CA4': 'Cancún, Quintana Roo (Área de Ajuste)',
    'COCZ': 'Consignación Cancún - Zicor',
    'COPZ': 'Consignación Puebla - Zicor',
    'INT': 'Internacional',
    'MEE': 'México (Proyectos Especiales)',
    'PU': 'Puebla - Binex',
    'SI': 'Silao, Guanajuato - Binex',
    'XCA': 'Refrigeration X - Cancún',
    'XPU': 'Refrigeration X - Puebla',
    'XZRE': 'Refacciones Refrigeration X',
    'ZRE': 'Refacciones',
  };

  /// Cancún warehouses (main Cancún operations)
  static const List<String> cancunWarehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', 'XCA'];

  /// Puebla warehouses
  static const List<String> pueblaWarehouses = ['PU', 'XPU'];

  /// Consignación warehouses (Zicor)
  static const List<String> consignacionWarehouses = ['COCZ', 'COPZ'];

  /// Spare parts/refacciones warehouses
  static const List<String> sparePartsWarehouses = ['ZRE', 'XZRE'];

  /// Other Mexican warehouses
  static const List<String> otherMexicanWarehouses = ['999', 'SI', 'MEE'];

  /// International/Special warehouses
  static const List<String> internationalWarehouses = ['INT'];

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

  /// Check if a warehouse is in Cancún region
  static bool isCancunWarehouse(String warehouseCode) {
    return cancunWarehouses.contains(warehouseCode);
  }

  /// Check if a warehouse is in Puebla region
  static bool isPueblaWarehouse(String warehouseCode) {
    return pueblaWarehouses.contains(warehouseCode);
  }

  /// Check if a warehouse is a consignación warehouse
  static bool isConsignacionWarehouse(String warehouseCode) {
    return consignacionWarehouses.contains(warehouseCode);
  }

  /// Check if a warehouse is for spare parts
  static bool isSparePartsWarehouse(String warehouseCode) {
    return sparePartsWarehouses.contains(warehouseCode);
  }

  /// Check if a warehouse is international/special
  static bool isInternationalWarehouse(String warehouseCode) {
    return internationalWarehouses.contains(warehouseCode);
  }

  /// Get color for warehouse display based on type
  static Color getWarehouseColor(String warehouseCode) {
    if (warehouseCode == '999') {
      return Colors.amber; // Special color for reserved merchandise
    } else if (isCancunWarehouse(warehouseCode)) {
      return Colors.blue; // Cancún - blue
    } else if (isPueblaWarehouse(warehouseCode)) {
      return Colors.green; // Puebla - green
    } else if (isConsignacionWarehouse(warehouseCode)) {
      return Colors.purple; // Consignación - purple
    } else if (isSparePartsWarehouse(warehouseCode)) {
      return Colors.orange; // Spare parts - orange
    } else if (isInternationalWarehouse(warehouseCode)) {
      return Colors.teal; // International - teal
    } else {
      return Colors.grey;
    }
  }

  /// Get icon for warehouse type
  static IconData getWarehouseIcon(String warehouseCode) {
    if (warehouseCode == '999') {
      return Icons.inventory_2; // Reserved merchandise
    } else if (isCancunWarehouse(warehouseCode)) {
      return Icons.warehouse; // Cancún warehouses
    } else if (isPueblaWarehouse(warehouseCode)) {
      return Icons.business; // Puebla warehouses
    } else if (isConsignacionWarehouse(warehouseCode)) {
      return Icons.handshake; // Consignación
    } else if (isSparePartsWarehouse(warehouseCode)) {
      return Icons.construction; // Spare parts
    } else if (isInternationalWarehouse(warehouseCode)) {
      return Icons.public; // International
    } else {
      return Icons.storage;
    }
  }

  /// Generate comprehensive tooltip message for all warehouses
  static String getComprehensiveTooltip() {
    final buffer = StringBuffer();
    buffer.writeln('Warehouse Codes:');
    buffer.writeln();

    // Reserved merchandise first
    buffer.writeln('999 - ${getDescription('999')}');
    buffer.writeln();

    // Cancún warehouses
    buffer.writeln('Cancún Warehouses:');
    for (final warehouse in cancunWarehouses) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // Puebla warehouses
    buffer.writeln('Puebla Warehouses:');
    for (final warehouse in pueblaWarehouses) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // Consignación warehouses
    buffer.writeln('Consignación Warehouses:');
    for (final warehouse in consignacionWarehouses) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // Spare parts warehouses
    buffer.writeln('Spare Parts Warehouses:');
    for (final warehouse in sparePartsWarehouses) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // Other Mexican warehouses
    buffer.writeln('Other Mexican Warehouses:');
    for (final warehouse in otherMexicanWarehouses.where((w) => w != '999')) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }
    buffer.writeln();

    // International warehouses
    buffer.writeln('International Warehouses:');
    for (final warehouse in internationalWarehouses) {
      buffer.writeln('$warehouse - ${getDescription(warehouse)}');
    }

    return buffer.toString().trim();
  }

  /// Generate tooltip for specific warehouse category
  static String getCategoryTooltip(String category) {
    switch (category.toLowerCase()) {
      case 'cancun':
        return cancunWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      case 'puebla':
        return pueblaWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      case 'consignacion':
        return consignacionWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      case 'spareparts':
        return sparePartsWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      case 'international':
        return internationalWarehouses
            .map((w) => '$w - ${getDescription(w)}')
            .join('\n');
      default:
        return getComprehensiveTooltip();
    }
  }

  /// Get all warehouse codes sorted by priority (Cancún, Puebla, Consignación, Spare Parts, Other, International)
  static List<String> getAllWarehouseCodesSorted() {
    final sorted = <String>[];
    sorted.add('999'); // Reserved merchandise first
    sorted.addAll(cancunWarehouses);
    sorted.addAll(pueblaWarehouses);
    sorted.addAll(consignacionWarehouses);
    sorted.addAll(sparePartsWarehouses);
    sorted.addAll(otherMexicanWarehouses.where((w) => w != '999'));
    sorted.addAll(internationalWarehouses);

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
        color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
      ),
    );
  }

  /// Get warehouse category name for display
  static String getCategoryName(String warehouseCode) {
    if (warehouseCode == '999') return 'Apartada';
    if (isCancunWarehouse(warehouseCode)) return 'Cancún';
    if (isPueblaWarehouse(warehouseCode)) return 'Puebla';
    if (isConsignacionWarehouse(warehouseCode)) return 'Consignación';
    if (isSparePartsWarehouse(warehouseCode)) return 'Refacciones';
    if (isInternationalWarehouse(warehouseCode)) return 'Internacional';
    if (warehouseCode == 'SI') return 'Silao';
    if (warehouseCode == 'MEE') return 'Proyectos Especiales';
    return 'Otro';
  }
}