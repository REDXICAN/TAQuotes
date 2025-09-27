#!/usr/bin/env python3
"""
Script to analyze the Excel inventory file structure and extract warehouse information.
"""

import pandas as pd
import json
import sys
from pathlib import Path

def analyze_excel_file(excel_path):
    """Analyze the Excel file structure and extract warehouse information."""
    try:
        # Read the Excel file
        print(f"Reading Excel file: {excel_path}")

        # Get all sheet names first
        xl_file = pd.ExcelFile(excel_path)
        print(f"Sheet names: {xl_file.sheet_names}")

        # Read the first sheet (or main sheet)
        df = pd.read_excel(excel_path, sheet_name=0)

        print(f"\nDataFrame shape: {df.shape}")
        print(f"Columns: {list(df.columns)}")

        # Show first few rows
        print("\nFirst 5 rows:")
        print(df.head())

        # Check for warehouse-related columns
        warehouse_columns = []
        for col in df.columns:
            col_lower = str(col).lower()
            if any(keyword in col_lower for keyword in ['warehouse', 'stock', 'inventory', 'qty', 'quantity', 'available']):
                warehouse_columns.append(col)

        print(f"\nPotential warehouse/stock columns: {warehouse_columns}")

        # Look for SKU or product identifier columns
        sku_columns = []
        for col in df.columns:
            col_lower = str(col).lower()
            if any(keyword in col_lower for keyword in ['sku', 'code', 'model', 'part', 'product']):
                sku_columns.append(col)

        print(f"Potential SKU/product columns: {sku_columns}")

        # Check data types
        print(f"\nData types:")
        print(df.dtypes)

        # Check for non-null values in potential warehouse columns
        if warehouse_columns:
            print(f"\nNon-null counts for warehouse columns:")
            for col in warehouse_columns[:10]:  # Limit to first 10
                print(f"{col}: {df[col].count()} non-null values")

        # Look for unique values in potential warehouse columns (if they seem like warehouse names)
        for col in warehouse_columns[:5]:  # Check first 5 warehouse columns
            unique_vals = df[col].dropna().unique()
            if len(unique_vals) < 20:  # If few unique values, might be warehouse names
                print(f"\nUnique values in {col}: {unique_vals}")

        # Export sample data for manual inspection
        sample_file = "excel_sample_data.json"
        sample_data = {
            "sheet_names": xl_file.sheet_names,
            "columns": list(df.columns),
            "shape": df.shape,
            "warehouse_columns": warehouse_columns,
            "sku_columns": sku_columns,
            "sample_rows": df.head(10).to_dict('records') if len(df) > 0 else []
        }

        with open(sample_file, 'w', encoding='utf-8') as f:
            json.dump(sample_data, f, indent=2, default=str)

        print(f"\nSample data exported to: {sample_file}")

        return df, warehouse_columns, sku_columns

    except Exception as e:
        print(f"Error reading Excel file: {e}")
        return None, [], []

def extract_warehouse_data(df, warehouse_columns, sku_columns):
    """Extract warehouse stock data from the DataFrame."""
    if df is None or not warehouse_columns or not sku_columns:
        print("Insufficient data to extract warehouse information")
        return {}

    try:
        # Use the first SKU column as identifier
        sku_col = sku_columns[0]
        print(f"\nUsing '{sku_col}' as SKU identifier")

        # Create warehouse stock mapping
        warehouse_data = {}

        for _, row in df.iterrows():
            sku = str(row[sku_col]).strip() if pd.notna(row[sku_col]) else None
            if not sku or sku == 'nan':
                continue

            warehouse_data[sku] = {}

            for warehouse_col in warehouse_columns:
                stock_value = row[warehouse_col]
                if pd.notna(stock_value):
                    try:
                        # Try to convert to integer
                        stock_int = int(float(stock_value))
                        warehouse_data[sku][warehouse_col] = stock_int
                    except (ValueError, TypeError):
                        # If not numeric, store as string
                        warehouse_data[sku][warehouse_col] = str(stock_value)

        # Remove empty SKUs
        warehouse_data = {k: v for k, v in warehouse_data.items() if v}

        print(f"\nExtracted warehouse data for {len(warehouse_data)} SKUs")

        # Show sample of extracted data
        sample_skus = list(warehouse_data.keys())[:3]
        for sku in sample_skus:
            print(f"SKU {sku}: {warehouse_data[sku]}")

        # Save extracted data
        output_file = "extracted_warehouse_data.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(warehouse_data, f, indent=2, default=str)

        print(f"\nWarehouse data saved to: {output_file}")

        return warehouse_data

    except Exception as e:
        print(f"Error extracting warehouse data: {e}")
        return {}

def main():
    excel_path = r"O:\OneDrive\Documentos\-- TurboAir\7 Bots\09.12.25 INVENTARIO MEXICO.xlsx"

    if not Path(excel_path).exists():
        print(f"Excel file not found: {excel_path}")
        sys.exit(1)

    # Analyze the Excel file
    df, warehouse_columns, sku_columns = analyze_excel_file(excel_path)

    # Extract warehouse data
    warehouse_data = extract_warehouse_data(df, warehouse_columns, sku_columns)

    # Summary
    print(f"\n=== ANALYSIS SUMMARY ===")
    print(f"Excel file: {excel_path}")
    print(f"Total rows: {len(df) if df is not None else 0}")
    print(f"Warehouse columns found: {len(warehouse_columns)}")
    print(f"SKU columns found: {len(sku_columns)}")
    print(f"Products with warehouse data: {len(warehouse_data)}")

    if warehouse_columns:
        print(f"\nWarehouse columns: {warehouse_columns}")

    return warehouse_data

if __name__ == "__main__":
    main()