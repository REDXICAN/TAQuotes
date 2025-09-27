#!/usr/bin/env python3
"""
Script to properly parse the Excel inventory file and extract warehouse stock data.
"""

import pandas as pd
import json
import sys
from pathlib import Path
import re

def parse_excel_inventory(excel_path):
    """Parse the Excel inventory file with proper structure handling."""
    try:
        print(f"Reading Excel file: {excel_path}")

        # Read the Excel file without headers first
        df = pd.read_excel(excel_path, sheet_name='INVENTARIOS', header=None)

        print(f"Raw DataFrame shape: {df.shape}")

        # Find the header row (contains "Código", "Nombre", "Existencia")
        header_row = None
        for i, row in df.iterrows():
            if any('digo' in str(cell) for cell in row if pd.notna(cell)):
                header_row = i
                break

        if header_row is None:
            print("Could not find header row")
            return None, []

        print(f"Found header row at index: {header_row}")

        # Extract column names
        headers = [str(cell).strip() if pd.notna(cell) else f"col_{i}" for i, cell in enumerate(df.iloc[header_row])]
        print(f"Headers: {headers}")

        # Read data starting from header row
        df_data = pd.read_excel(excel_path, sheet_name='INVENTARIOS', header=header_row)
        df_data.columns = [col.strip() if isinstance(col, str) else col for col in df_data.columns]

        print(f"Data DataFrame shape: {df_data.shape}")
        print(f"Columns: {list(df_data.columns)}")

        # Show sample data
        print("\nFirst 10 rows of actual data:")
        print(df_data.head(10))

        # Find warehouse information
        warehouses = []
        warehouse_data = {}
        current_warehouse = None

        # Process the raw data to find warehouse sections
        for i, row in df.iterrows():
            row_str = ' '.join([str(cell) for cell in row if pd.notna(cell)])

            # Check for warehouse identifier
            if 'Almac' in row_str or 'ALMAC' in row_str:
                continue

            # Check for warehouse codes (like '999', '001', etc.)
            warehouse_match = re.search(r"'?(\d{3})\s*([A-Z\s]+)", row_str)
            if warehouse_match:
                warehouse_code = warehouse_match.group(1)
                warehouse_name = warehouse_match.group(2).strip()
                current_warehouse = warehouse_code
                warehouses.append({
                    'code': warehouse_code,
                    'name': warehouse_name
                })
                print(f"Found warehouse: {warehouse_code} - {warehouse_name}")
                continue

            # Process product data
            if current_warehouse and len(row) >= 3:
                codigo = str(row[0]).strip() if pd.notna(row[0]) else None
                nombre = str(row[1]).strip() if pd.notna(row[1]) else None
                existencia = row[2] if pd.notna(row[2]) else 0

                # Skip empty rows and header-like rows
                if (not codigo or codigo in ['nan', ' ', 'Código'] or
                    'digo' in codigo or codigo.startswith('Almac')):
                    continue

                try:
                    stock_qty = int(float(existencia)) if existencia != 0 else 0
                except (ValueError, TypeError):
                    stock_qty = 0

                if codigo and stock_qty >= 0:
                    if codigo not in warehouse_data:
                        warehouse_data[codigo] = {
                            'name': nombre or '',
                            'warehouses': {}
                        }

                    warehouse_data[codigo]['warehouses'][current_warehouse] = stock_qty

                    # Update name if we have a better one
                    if nombre and nombre != 'nan':
                        warehouse_data[codigo]['name'] = nombre

        print(f"\nFound {len(warehouses)} warehouses:")
        for wh in warehouses:
            print(f"  {wh['code']}: {wh['name']}")

        print(f"\nExtracted stock data for {len(warehouse_data)} products")

        # Show sample products
        sample_products = list(warehouse_data.keys())[:5]
        for sku in sample_products:
            product = warehouse_data[sku]
            print(f"SKU: {sku}")
            print(f"  Name: {product['name']}")
            print(f"  Warehouses: {product['warehouses']}")
            print()

        # Save the extracted data
        output_data = {
            'warehouses': warehouses,
            'products': warehouse_data,
            'summary': {
                'total_warehouses': len(warehouses),
                'total_products': len(warehouse_data),
                'extraction_date': '2025-01-26'
            }
        }

        output_file = "parsed_inventory_data.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)

        print(f"Data saved to: {output_file}")

        return output_data, warehouses

    except Exception as e:
        print(f"Error parsing Excel file: {e}")
        import traceback
        traceback.print_exc()
        return None, []

def generate_flutter_data(output_data):
    """Generate Dart data for Flutter integration."""
    if not output_data:
        return

    warehouses = output_data['warehouses']
    products = output_data['products']

    # Calculate totals by warehouse
    warehouse_totals = {}
    for wh in warehouses:
        warehouse_totals[wh['code']] = 0

    # Sort products by total stock (highest first)
    product_totals = {}
    for sku, product in products.items():
        total_stock = sum(product['warehouses'].values())
        product_totals[sku] = total_stock

        # Add to warehouse totals
        for wh_code, stock in product['warehouses'].items():
            if wh_code in warehouse_totals:
                warehouse_totals[wh_code] += stock

    # Sort products by stock volume
    sorted_products = dict(sorted(product_totals.items(), key=lambda x: x[1], reverse=True))

    # Generate Dart constants
    dart_code = f"""
// Generated from Excel inventory file
// Total warehouses: {len(warehouses)}
// Total products: {len(products)}

class InventoryConstants {{
  static const List<Map<String, String>> warehouses = [
"""

    for wh in warehouses:
        dart_code += f"    {{'code': '{wh['code']}', 'name': '{wh['name']}'}},\n"

    dart_code += "  ];\n\n"

    dart_code += "  static const Map<String, int> warehouseTotals = {\n"
    for wh_code, total in warehouse_totals.items():
        dart_code += f"    '{wh_code}': {total},\n"

    dart_code += "  };\n}\n"

    # Save Dart file
    with open("lib/core/config/inventory_constants.dart", 'w', encoding='utf-8') as f:
        f.write(dart_code)

    print("Generated inventory_constants.dart")

    # Save summary
    summary = {
        'warehouse_totals': warehouse_totals,
        'top_products_by_stock': dict(list(sorted_products.items())[:20]),
        'warehouses': [{'code': wh['code'], 'name': wh['name']} for wh in warehouses]
    }

    with open("inventory_summary.json", 'w', encoding='utf-8') as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    print(f"Inventory summary saved")

    return summary

def main():
    excel_path = r"O:\OneDrive\Documentos\-- TurboAir\7 Bots\09.12.25 INVENTARIO MEXICO.xlsx"

    if not Path(excel_path).exists():
        print(f"Excel file not found: {excel_path}")
        sys.exit(1)

    # Parse the Excel file
    output_data, warehouses = parse_excel_inventory(excel_path)

    if output_data:
        # Generate Flutter integration data
        summary = generate_flutter_data(output_data)

        print(f"\n=== FINAL SUMMARY ===")
        print(f"Excel file processed: {excel_path}")
        print(f"Warehouses found: {len(warehouses)}")
        print(f"Products with inventory: {len(output_data['products'])}")

        if summary:
            print(f"Warehouse totals: {summary['warehouse_totals']}")
    else:
        print("Failed to parse Excel file")

if __name__ == "__main__":
    main()