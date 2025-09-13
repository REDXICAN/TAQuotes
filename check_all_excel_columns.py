import pandas as pd
import numpy as np

excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"

print("=" * 80)
print("CHECKING ALL COLUMNS IN EXCEL FOR STOCK DATA")
print("=" * 80)

# Load Excel with different skip options
for skip in [0, 1, 2, 3]:
    print(f"\n\nTrying with skiprows={skip}:")
    df = pd.read_excel(excel_file, sheet_name=0, skiprows=skip)
    
    print(f"Shape: {df.shape[0]} rows x {df.shape[1]} columns")
    print(f"\nColumn headers:")
    for i, col in enumerate(df.columns[:20]):  # Show first 20 columns
        print(f"  Col {i}: {col}")
    
    # Check for numeric columns
    print(f"\nChecking for numeric data in all columns:")
    for col_idx in range(min(20, len(df.columns))):
        numeric_count = 0
        total_sum = 0
        sample_values = []
        
        for val in df.iloc[:, col_idx]:
            if pd.notna(val):
                try:
                    num_val = float(val)
                    if 0 < num_val < 100000:  # Reasonable range
                        numeric_count += 1
                        total_sum += num_val
                        if len(sample_values) < 3:
                            sample_values.append(num_val)
                except:
                    pass
        
        if numeric_count > 10:  # Only show columns with significant numeric data
            print(f"    Col {col_idx:2} ({str(df.columns[col_idx])[:20]:20}): {int(total_sum):,} total from {numeric_count} items")
            print(f"         Sample values: {sample_values}")

print("\n" + "=" * 80)
print("CHECKING IF THERE ARE WAREHOUSE COLUMNS")
print("=" * 80)

# Load with skiprows=3 and check for patterns
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Look for columns that might be warehouse codes
potential_warehouses = []
for col in df.columns:
    col_str = str(col).upper()
    # Check if column name looks like a warehouse code
    if (len(col_str) <= 4 and 
        (col_str in ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'PU', 'SI', 'MEE', 'COCZ', 'COPZ', 'XCA', 'XPU'] or
         'ALMAC' in col_str or 'BODEGA' in col_str)):
        potential_warehouses.append(col)

if potential_warehouses:
    print(f"Found potential warehouse columns: {potential_warehouses}")
else:
    print("No warehouse columns found in headers")

# Check row structure - maybe warehouses are in rows
print("\n" + "=" * 80)
print("SAMPLE OF FIRST 20 ROWS")
print("=" * 80)

df = pd.read_excel(excel_file, sheet_name=0)
for i in range(min(20, len(df))):
    row_vals = []
    for j in range(min(5, len(df.columns))):
        val = df.iloc[i, j]
        if pd.isna(val):
            row_vals.append("NaN")
        else:
            row_vals.append(str(val)[:20])
    print(f"Row {i:2}: {' | '.join(row_vals)}")

print("\n" + "=" * 80)