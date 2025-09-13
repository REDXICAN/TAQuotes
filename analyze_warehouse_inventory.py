import pandas as pd
import json

# Load Excel file
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
print("=" * 80)
print("ANALYZING WAREHOUSE INVENTORY STRUCTURE")
print("=" * 80)

# Read the Excel file
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Display column headers to understand warehouse structure
print("\nColumn Headers:")
for i, col in enumerate(df.columns):
    print(f"  Column {i}: {col}")

# Identify warehouse columns (usually after the first few product info columns)
print("\n" + "=" * 80)
print("WAREHOUSE COLUMNS IDENTIFIED")
print("=" * 80)

# The Excel structure typically has:
# Column 0: SKU/Code
# Column 1: Description  
# Column 2: Stock/Quantity
# Column 3+: Individual warehouse quantities

warehouse_columns = {}
for i in range(3, len(df.columns)):
    col_name = str(df.columns[i])
    if not pd.isna(df.columns[i]) and col_name != 'nan':
        warehouse_columns[i] = col_name
        print(f"  Column {i}: {col_name}")

# Count products per warehouse
print("\n" + "=" * 80)
print("WAREHOUSE INVENTORY SUMMARY")
print("=" * 80)

warehouse_totals = {}
warehouse_products = {}

for col_idx, warehouse in warehouse_columns.items():
    total = 0
    product_count = 0
    
    for index, row in df.iterrows():
        value = row.iloc[col_idx] if col_idx < len(row) else None
        if pd.notna(value) and value != 0:
            try:
                qty = int(float(str(value)))
                if qty > 0:
                    total += qty
                    product_count += 1
            except:
                pass
    
    if total > 0:
        warehouse_totals[warehouse] = total
        warehouse_products[warehouse] = product_count
        print(f"\n{warehouse}:")
        print(f"  Products: {product_count}")
        print(f"  Total Units: {total}")

# Show sample of products with warehouse distribution
print("\n" + "=" * 80)
print("SAMPLE PRODUCTS WITH WAREHOUSE DISTRIBUTION")
print("=" * 80)

sample_count = 0
for index, row in df.iterrows():
    if sample_count >= 10:
        break
    
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    if sku and str(sku).strip():
        has_warehouse_stock = False
        warehouse_dist = {}
        
        for col_idx, warehouse in warehouse_columns.items():
            value = row.iloc[col_idx] if col_idx < len(row) else None
            if pd.notna(value) and value != 0:
                try:
                    qty = int(float(str(value)))
                    if qty > 0:
                        warehouse_dist[warehouse] = qty
                        has_warehouse_stock = True
                except:
                    pass
        
        if has_warehouse_stock:
            print(f"\nSKU: {sku}")
            for wh, qty in warehouse_dist.items():
                print(f"  {wh}: {qty} units")
            sample_count += 1

print("\n" + "=" * 80)
print("ANALYSIS COMPLETE")
print("=" * 80)