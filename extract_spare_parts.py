#!/usr/bin/env python3
"""
Extract spare parts data from Excel inventory file.
"""

import pandas as pd
import json
import sys
import os

def read_excel_file(file_path):
    """Read the Excel file and return DataFrame"""
    try:
        # Try reading the Excel file
        df = pd.read_excel(file_path, sheet_name=0)  # Read first sheet
        print(f"Successfully read Excel file with {len(df)} rows and {len(df.columns)} columns")
        print(f"Columns: {list(df.columns)}")
        return df
    except Exception as e:
        print(f"Error reading Excel file: {e}")
        return None

def identify_spare_parts(df):
    """Identify which items are spare parts based on naming patterns"""
    spare_parts_keywords = [
        'clip', 'rejilla', 'filtro', 'filter', 'belt', 'motor', 'fan', 'bearing',
        'gasket', 'seal', 'valve', 'sensor', 'switch', 'relay', 'fuse', 'thermostat',
        'capacitor', 'contactor', 'coil', 'evaporator', 'condenser', 'compressor',
        'drain', 'pump', 'hose', 'bracket', 'screw', 'bolt', 'nut', 'washer',
        'spring', 'blade', 'wheel', 'housing', 'cover', 'panel', 'door', 'handle',
        'knob', 'control', 'board', 'wire', 'cable', 'connector', 'terminal',
        'resistor', 'transformer', 'heater', 'element', 'bulb', 'lamp', 'lens',
        'glass', 'plastic', 'rubber', 'foam', 'insulation', 'kit', 'assembly',
        'part', 'component', 'piece', 'replacement', 'spare', 'service',
        'maintenance', 'repair', 'tubo', 'tube', 'manguera', 'tornillo', 'tapa',
        'soporte', 'support', 'placa', 'plate', 'membrana', 'membrane'
    ]

    # Based on the data structure we observed:
    # Column 0: 'CONTPAQ i' - contains SKUs
    # Column 1: 'TAR COMMERCIAL REFRIGERATION' - contains product names
    # Column 2: '12/SEP/2025' - contains stock quantities

    sku_column = df.columns[0]
    name_column = df.columns[1]
    stock_column = df.columns[2]

    print(f"Using columns: SKU='{sku_column}', Name='{name_column}', Stock='{stock_column}'")

    spare_parts = []
    current_warehouse = "999"  # Default warehouse

    for index, row in df.iterrows():
        # Skip header rows and empty rows
        if index < 8:  # Skip the first few header rows
            continue

        sku = row[sku_column]
        name = row[name_column]
        stock = row[stock_column]

        # Check for warehouse indicators
        if pd.notna(sku) and isinstance(sku, str):
            sku_clean = str(sku).strip()
            if sku_clean.startswith("'") and len(sku_clean) > 10:
                # This might be a warehouse indicator like "'999                           "
                warehouse_code = sku_clean.strip("' ")
                if warehouse_code in ['999', 'CA', 'CA1', 'CA2', 'CA3', 'CA4', 'COCZ', 'COPZ', 'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU', 'XZRE', 'ZRE']:
                    current_warehouse = warehouse_code
                    print(f"Found warehouse: {current_warehouse}")
                continue

        # Skip rows without proper SKU and name
        if pd.isna(sku) or pd.isna(name) or not isinstance(sku, str) or not isinstance(name, str):
            continue

        sku_clean = str(sku).strip()
        name_clean = str(name).strip()

        # Skip if SKU is too short or name is too short
        if len(sku_clean) < 3 or len(name_clean) < 5:
            continue

        # Check if this is a spare part based on name
        name_lower = name_clean.lower()
        is_spare_part = any(keyword in name_lower for keyword in spare_parts_keywords)

        if is_spare_part:
            try:
                stock_qty = int(float(stock)) if pd.notna(stock) else 0
            except (ValueError, TypeError):
                stock_qty = 0

            spare_parts.append({
                'index': index,
                'sku': sku_clean,
                'name': name_clean,
                'warehouse': current_warehouse,
                'stock': stock_qty,
                'row_data': row.to_dict()
            })

    print(f"Found {len(spare_parts)} potential spare parts out of {len(df)} total items")
    return spare_parts

def extract_warehouse_data(row_data, warehouse_columns):
    """Extract warehouse stock data from a row"""
    warehouse_stock = {}
    target_warehouses = ['999', 'CA', 'CA1', 'CA2', 'CA3', 'CA4', 'COCZ', 'COPZ',
                        'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU', 'XZRE', 'ZRE']

    for col_name, col_value in row_data.items():
        col_str = str(col_name).upper()

        # Check if column name matches any of our target warehouses
        for warehouse in target_warehouses:
            if warehouse in col_str or col_str == warehouse:
                try:
                    # Convert to integer, default to 0 if invalid
                    stock_value = int(float(col_value)) if pd.notna(col_value) else 0
                    warehouse_stock[warehouse] = stock_value
                except (ValueError, TypeError):
                    warehouse_stock[warehouse] = 0
                break

    return warehouse_stock

def main():
    file_path = r"O:\OneDrive\Documentos\-- TurboAir\7 Bots\09.12.25 INVENTARIO MEXICO.xlsx"

    # Read the Excel file
    df = read_excel_file(file_path)
    if df is None:
        return

    # Print first few rows to understand structure
    print("\nFirst 5 rows of data:")
    print(df.head())
    print("\nColumn info:")
    print(df.info())

    # Identify spare parts
    spare_parts = identify_spare_parts(df)

    if not spare_parts:
        print("No spare parts found. Let's examine the data structure more closely...")
        print("\nSample data from first 10 rows:")
        for i in range(min(10, len(df))):
            print(f"Row {i}: {dict(df.iloc[i])}")
        return

    # Group spare parts by SKU and aggregate warehouse stock
    sku_parts = {}

    for spare_part in spare_parts:
        sku = spare_part['sku']
        warehouse = spare_part['warehouse']
        stock = spare_part['stock']

        if sku not in sku_parts:
            sku_parts[sku] = {
                'sku': sku,
                'name': spare_part['name'],
                'category': 'Spare Parts',
                'price': 0.0,  # Will need to be set manually
                'warehouse_stock': {},
                'description': f"Spare part: {spare_part['name']}",
                'original_row': spare_part['index']
            }

        # Add warehouse stock
        sku_parts[sku]['warehouse_stock'][warehouse] = stock

    # Convert to list and fill missing warehouses with 0
    processed_spare_parts = []
    target_warehouses = ['999', 'CA', 'CA1', 'CA2', 'CA3', 'CA4', 'COCZ', 'COPZ',
                        'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU', 'XZRE', 'ZRE']

    for sku, part_data in sku_parts.items():
        # Ensure all warehouses are represented
        for warehouse in target_warehouses:
            if warehouse not in part_data['warehouse_stock']:
                part_data['warehouse_stock'][warehouse] = 0

        processed_spare_parts.append(part_data)

    # Save to JSON file
    output_file = "spare_parts_extracted.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(processed_spare_parts, f, indent=2, ensure_ascii=False)

    print(f"\nExtracted {len(processed_spare_parts)} spare parts")
    print(f"Data saved to {output_file}")

    # Print sample data
    if processed_spare_parts:
        print("\nSample spare part data:")
        for i, part in enumerate(processed_spare_parts[:3]):
            print(f"\n{i+1}. {part['name']} ({part['sku']})")
            print(f"   Warehouse stock: {part['warehouse_stock']}")

if __name__ == "__main__":
    main()