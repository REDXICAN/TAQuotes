#!/usr/bin/env python3
"""
Final script to parse Excel inventory and create Flutter-compatible data.
"""

import pandas as pd
import json
import sys
from pathlib import Path

def parse_complete_excel(excel_path):
    """Parse the entire Excel file to extract all warehouse data."""
    try:
        print(f"Reading Excel file: {excel_path}")

        # Read without headers to get raw data
        df = pd.read_excel(excel_path, sheet_name='INVENTARIOS', header=None)

        warehouses = []
        warehouse_data = {}
        current_warehouse = None

        # Process each row
        for i, row in df.iterrows():
            col1 = str(row[0]).strip() if pd.notna(row[0]) else ""
            col2 = str(row[1]).strip() if pd.notna(row[1]) else ""
            col3 = str(row[2]).strip() if pd.notna(row[2]) else ""

            # Skip header rows
            if i < 6 or 'digo' in col1:
                continue

            # Look for warehouse section headers
            if 'Almac' in col1:
                current_warehouse = None  # Reset for new section
                continue

            # Look for warehouse codes (numbers with apostrophe or clean numbers)
            if ((col1.startswith("'") and col1[1:].isdigit()) or
                (col1.isdigit() and len(col1) <= 4)) and col2:

                warehouse_code = col1.replace("'", "").strip()
                warehouse_name = col2.strip()
                current_warehouse = warehouse_code

                # Check if already exists
                if not any(w['code'] == warehouse_code for w in warehouses):
                    warehouses.append({
                        'code': warehouse_code,
                        'name': warehouse_name
                    })
                    print(f"Found warehouse: {warehouse_code} - {warehouse_name}")
                continue

            # Process product data
            if current_warehouse and col1 and len(col1) >= 6:
                # Skip if this looks like header text
                if any(word in col1.lower() for word in ['almac', 'codigo', 'nombre']):
                    continue

                try:
                    stock_qty = int(float(col3)) if col3 and col3 != 'nan' else 0

                    if col1 not in warehouse_data:
                        warehouse_data[col1] = {
                            'name': '',
                            'warehouses': {}
                        }

                    # Add or update stock for this warehouse
                    if current_warehouse in warehouse_data[col1]['warehouses']:
                        warehouse_data[col1]['warehouses'][current_warehouse] += stock_qty
                    else:
                        warehouse_data[col1]['warehouses'][current_warehouse] = stock_qty

                    # Update product name
                    if col2 and col2 != 'nan' and col2 != '':
                        warehouse_data[col1]['name'] = col2

                except (ValueError, TypeError):
                    continue

        # Calculate totals and sort by stock volume
        product_totals = {}
        warehouse_totals = {}

        # Initialize warehouse totals
        for wh in warehouses:
            warehouse_totals[wh['code']] = 0

        # Calculate totals
        for sku, product in warehouse_data.items():
            total_stock = sum(product['warehouses'].values())
            product_totals[sku] = total_stock

            for wh_code, stock in product['warehouses'].items():
                if wh_code in warehouse_totals:
                    warehouse_totals[wh_code] += stock

        # Sort products by total stock (highest first)
        sorted_products = dict(sorted(product_totals.items(), key=lambda x: x[1], reverse=True))

        # Prepare final data
        final_data = {
            'warehouses': warehouses,
            'products': {sku: warehouse_data[sku] for sku in sorted_products.keys()},
            'warehouse_totals': warehouse_totals,
            'summary': {
                'total_warehouses': len(warehouses),
                'total_products': len(warehouse_data),
                'highest_stock_product': list(sorted_products.keys())[0] if sorted_products else None,
                'highest_stock_amount': list(sorted_products.values())[0] if sorted_products else 0,
                'total_inventory': sum(warehouse_totals.values())
            }
        }

        print(f"\n=== FINAL RESULTS ===")
        print(f"Warehouses found: {len(warehouses)}")
        for wh in warehouses:
            total = warehouse_totals.get(wh['code'], 0)
            print(f"  {wh['code']}: {wh['name']} ({total} units)")

        print(f"\nProducts with inventory: {len(warehouse_data)}")
        print(f"Total inventory across all warehouses: {final_data['summary']['total_inventory']} units")

        # Show top 10 products by stock
        print(f"\nTop 10 products by stock:")
        for i, (sku, stock) in enumerate(list(sorted_products.items())[:10]):
            product_name = warehouse_data[sku]['name'][:50] + "..." if len(warehouse_data[sku]['name']) > 50 else warehouse_data[sku]['name']
            print(f"  {i+1}. {sku}: {stock} units - {product_name}")

        # Save data
        with open("final_inventory_data.json", 'w', encoding='utf-8') as f:
            json.dump(final_data, f, indent=2, ensure_ascii=False)

        print(f"\nData saved to: final_inventory_data.json")

        return final_data

    except Exception as e:
        print(f"Error parsing Excel file: {e}")
        import traceback
        traceback.print_exc()
        return None

def generate_flutter_service(data):
    """Generate Flutter service for Excel inventory data."""
    if not data:
        return

    dart_service = '''import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/models.dart';

/// Service to read inventory data from Excel file
class ExcelInventoryService {
  static const String excelPath = r"O:\\OneDrive\\Documentos\\-- TurboAir\\7 Bots\\09.12.25 INVENTARIO MEXICO.xlsx";

  // Cached data
  static Map<String, dynamic>? _cachedData;
  static DateTime? _lastUpdate;

'''

    # Add warehouse constants
    dart_service += '  static const List<Map<String, String>> warehouses = [\n'
    for wh in data['warehouses']:
        dart_service += f"    {{'code': '{wh['code']}', 'name': '{wh['name']}'}},\n"
    dart_service += '  ];\n\n'

    # Add warehouse totals
    dart_service += '  static const Map<String, int> warehouseTotals = {\n'
    for wh_code, total in data['warehouse_totals'].items():
        dart_service += f"    '{wh_code}': {total},\n"
    dart_service += '  };\n\n'

    dart_service += f'''
  /// Load inventory data from the JSON file (converted from Excel)
  static Future<Map<String, dynamic>> loadInventoryData() async {{
    try {{
      // Check if we have cached data and it's recent (less than 1 hour old)
      if (_cachedData != null && _lastUpdate != null) {{
        final timeDiff = DateTime.now().difference(_lastUpdate!);
        if (timeDiff.inHours < 1) {{
          return _cachedData!;
        }}
      }}

      // For now, return the static data embedded in the service
      final data = {{
        'warehouses': warehouses,
        'warehouse_totals': warehouseTotals,
        'products': <String, dynamic>{{}}, // Will be loaded from JSON file
        'summary': {{
          'total_warehouses': {data['summary']['total_warehouses']},
          'total_products': {data['summary']['total_products']},
          'total_inventory': {data['summary']['total_inventory']},
        }}
      }};

      _cachedData = data;
      _lastUpdate = DateTime.now();

      return data;
    }} catch (e) {{
      print('Error loading inventory data: $e');
      return {{}};
    }}
  }}

  /// Get stock for a specific product SKU
  static Map<String, int> getProductStock(String sku) {{
    // This would normally read from the JSON data
    // For now, return empty stock
    return {{}};
  }}

  /// Get total stock for a product across all warehouses
  static int getTotalStock(String sku) {{
    final stock = getProductStock(sku);
    return stock.values.fold(0, (sum, count) => sum + count);
  }}

  /// Get products sorted by stock volume (highest first)
  static Future<List<Product>> getProductsSortedByStock() async {{
    final data = await loadInventoryData();
    // This would normally process the products data
    // For now, return empty list
    return [];
  }}

  /// Get warehouse names list
  static List<String> getWarehouseNames() {{
    return warehouses.map((wh) => wh['name'] ?? '').toList();
  }}

  /// Get warehouse codes list
  static List<String> getWarehouseCodes() {{
    return warehouses.map((wh) => wh['code'] ?? '').toList();
  }}
}}
''';

    # Save the Dart service
    service_path = "lib/core/services/excel_inventory_service.dart"
    with open(service_path, 'w', encoding='utf-8') as f:
        f.write(dart_service)

    print(f"Generated Flutter service: {service_path}")

def main():
    excel_path = r"O:\OneDrive\Documentos\-- TurboAir\7 Bots\09.12.25 INVENTARIO MEXICO.xlsx"

    if not Path(excel_path).exists():
        print(f"Excel file not found: {excel_path}")
        sys.exit(1)

    # Parse the Excel file completely
    data = parse_complete_excel(excel_path)

    if data:
        # Generate Flutter service
        generate_flutter_service(data)
        print("\n✅ Excel inventory processing completed successfully!")
    else:
        print("❌ Failed to process Excel inventory file")

if __name__ == "__main__":
    main()