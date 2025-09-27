#!/usr/bin/env python3
"""
Better script to analyze the Excel inventory file structure.
Looking for actual warehouse sections, not mistaking product codes.
"""

import pandas as pd
import json
import sys
from pathlib import Path
import re

def analyze_excel_structure(excel_path):
    """Analyze the Excel file to identify warehouse sections correctly."""
    try:
        print(f"Reading Excel file: {excel_path}")

        # Read the entire file without headers
        df = pd.read_excel(excel_path, sheet_name='INVENTARIOS', header=None)

        print(f"Raw DataFrame shape: {df.shape}")

        # Look for warehouse sections - they should start with "Almacén:" followed by warehouse info
        warehouses = []
        current_warehouse = None
        warehouse_data = {}

        print("\n=== ANALYZING STRUCTURE ===")

        # First pass - identify the pattern
        for i, row in df.iterrows():
            col1 = str(row[0]).strip() if pd.notna(row[0]) else ""
            col2 = str(row[1]).strip() if pd.notna(row[1]) else ""
            col3 = str(row[2]).strip() if pd.notna(row[2]) else ""

            # Print first 50 rows to understand pattern
            if i < 50:
                print(f"Row {i}: [{col1}] | [{col2}] | [{col3}]")

            # Look for warehouse section headers
            if 'Almac' in col1 or 'ALMAC' in col1:
                print(f"\nFound warehouse header at row {i}: {col1}")
                continue

            # Look for warehouse codes (should be a clean number followed by warehouse name)
            if (col1.startswith("'") or col1.isdigit()) and len(col1) <= 10 and col2 and not col1.startswith("30"):
                # This looks like a warehouse code line
                warehouse_code = col1.replace("'", "").strip()
                warehouse_name = col2.strip()

                # Skip if this looks like a product code
                if len(warehouse_code) >= 8 or any(char.isalpha() for char in warehouse_code[1:]):
                    continue

                current_warehouse = warehouse_code
                warehouses.append({
                    'code': warehouse_code,
                    'name': warehouse_name,
                    'row': i
                })
                print(f"Found warehouse section: {warehouse_code} - {warehouse_name}")
                continue

            # Process product data if we have a current warehouse
            if current_warehouse and col1 and len(col1) >= 6 and not col1.startswith("Almac"):
                # This looks like a product code
                try:
                    stock_qty = int(float(col3)) if col3 and col3 != 'nan' else 0

                    if col1 not in warehouse_data:
                        warehouse_data[col1] = {
                            'name': col2 if col2 != 'nan' else '',
                            'warehouses': {}
                        }

                    warehouse_data[col1]['warehouses'][current_warehouse] = stock_qty

                    # Update product name if we have a better one
                    if col2 and col2 != 'nan' and col2 != '':
                        warehouse_data[col1]['name'] = col2

                except (ValueError, TypeError):
                    continue

        print(f"\n=== RESULTS ===")
        print(f"Found {len(warehouses)} warehouses:")
        for wh in warehouses:
            print(f"  {wh['code']}: {wh['name']}")

        print(f"\nFound products with inventory: {len(warehouse_data)}")

        # Show sample products
        sample_skus = list(warehouse_data.keys())[:5]
        for sku in sample_skus:
            product = warehouse_data[sku]
            total_stock = sum(product['warehouses'].values())
            print(f"SKU: {sku} (Total: {total_stock})")
            print(f"  Name: {product['name']}")
            print(f"  Warehouses: {product['warehouses']}")
            print()

        # Calculate warehouse totals
        warehouse_totals = {}
        for wh in warehouses:
            warehouse_totals[wh['code']] = 0

        for sku, product in warehouse_data.items():
            for wh_code, stock in product['warehouses'].items():
                if wh_code in warehouse_totals:
                    warehouse_totals[wh_code] += stock

        print(f"\nWarehouse stock totals:")
        for wh_code, total in warehouse_totals.items():
            wh_name = next((w['name'] for w in warehouses if w['code'] == wh_code), 'Unknown')
            print(f"  {wh_code} ({wh_name}): {total} units")

        # Save the processed data
        output_data = {
            'warehouses': warehouses,
            'products': warehouse_data,
            'warehouse_totals': warehouse_totals,
            'summary': {
                'total_warehouses': len(warehouses),
                'total_products': len(warehouse_data),
                'extraction_date': '2025-01-26'
            }
        }

        with open("processed_inventory_data.json", 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)

        print(f"\nData saved to: processed_inventory_data.json")

        return output_data

    except Exception as e:
        print(f"Error analyzing Excel file: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    excel_path = r"O:\OneDrive\Documentos\-- TurboAir\7 Bots\09.12.25 INVENTARIO MEXICO.xlsx"

    if not Path(excel_path).exists():
        print(f"Excel file not found: {excel_path}")
        sys.exit(1)

    # Analyze the Excel file structure
    output_data = analyze_excel_structure(excel_path)

    if output_data:
        print(f"\n=== FINAL SUMMARY ===")
        print(f"Excel file processed: {excel_path}")
        print(f"Warehouses found: {output_data['summary']['total_warehouses']}")
        print(f"Products with inventory: {output_data['summary']['total_products']}")
        print("\nWarehouse list:")
        for wh in output_data['warehouses']:
            total = output_data['warehouse_totals'].get(wh['code'], 0)
            print(f"  {wh['code']}: {wh['name']} ({total} units)")
    else:
        print("Failed to analyze Excel file")

if __name__ == "__main__":
    main()