import pandas as pd
import re

excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"

print("=" * 80)
print("FINDING THE CORRECT 10,112 TOTAL STOCK")
print("=" * 80)

# Load Excel with skiprows=3
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

print(f"\nTotal rows in Excel: {len(df)}")
print(f"Columns: {list(df.columns)}")

# Different ways to calculate the total
print("\n" + "=" * 80)
print("ANALYZING STOCK TOTALS")
print("=" * 80)

# Method 1: Sum all numeric values in Existencia column
total_all = 0
count_all = 0
for val in df['Existencia']:
    if pd.notna(val):
        try:
            num_val = float(val)
            if num_val > 0:
                total_all += num_val
                count_all += 1
        except:
            pass

print(f"\n1. Total including ALL rows: {int(total_all):,} units from {count_all} items")

# Method 2: Sum only rows with valid product codes (not starting with numbers)
total_products_only = 0
count_products = 0
total_spare_parts = 0
count_spare = 0

for i, row in df.iterrows():
    sku = str(row.iloc[0]) if not pd.isna(row.iloc[0]) else ""
    stock = row.iloc[2] if len(df.columns) > 2 else 0
    
    if sku and pd.notna(stock):
        try:
            stock_val = float(stock)
            if stock_val > 0:
                # Check if it's a product (starts with letter) or spare part (starts with number)
                sku_clean = sku.strip().replace("'", "")
                if sku_clean and sku_clean[0].isalpha():
                    # Product code (starts with letter)
                    total_products_only += stock_val
                    count_products += 1
                elif sku_clean and sku_clean[0].isdigit():
                    # Spare part (starts with number)
                    total_spare_parts += stock_val
                    count_spare += 1
        except:
            pass

print(f"\n2. Products only (SKU starts with letter): {int(total_products_only):,} units from {count_products} items")
print(f"   Spare parts (SKU starts with number): {int(total_spare_parts):,} units from {count_spare} items")
print(f"   Combined total: {int(total_products_only + total_spare_parts):,} units")

# Method 3: Check specific row ranges
print("\n3. Checking different row ranges:")

# Maybe there's a subtotal row around 10,112?
cumulative_total = 0
milestone_10k = None
milestone_15k = None
milestone_20k = None

for i, row in df.iterrows():
    stock = row.iloc[2] if len(df.columns) > 2 else 0
    if pd.notna(stock):
        try:
            stock_val = float(stock)
            if stock_val > 0:
                cumulative_total += stock_val
                
                # Check for milestones
                if milestone_10k is None and cumulative_total >= 10000:
                    milestone_10k = (i, cumulative_total)
                if milestone_15k is None and cumulative_total >= 15000:
                    milestone_15k = (i, cumulative_total)
                if milestone_20k is None and cumulative_total >= 20000:
                    milestone_20k = (i, cumulative_total)
        except:
            pass

if milestone_10k:
    print(f"   Reached 10,000 at row {milestone_10k[0]}: {int(milestone_10k[1]):,} units")
if milestone_15k:
    print(f"   Reached 15,000 at row {milestone_15k[0]}: {int(milestone_15k[1]):,} units")
if milestone_20k:
    print(f"   Reached 20,000 at row {milestone_20k[0]}: {int(milestone_20k[1]):,} units")

# Method 4: Check if warehouse 999 should be excluded
print("\n4. Checking if certain warehouses should be excluded:")

# Look for warehouse indicators in the data
warehouse_999_found = False
for i in range(min(20, len(df))):
    row_text = str(df.iloc[i, 0]) if not pd.isna(df.iloc[i, 0]) else ""
    if '999' in row_text:
        print(f"   Found '999' reference at row {i}: {row_text}")
        warehouse_999_found = True

# Calculate total excluding certain patterns
total_excluding_999 = 0
count_excluding = 0

for i, row in df.iterrows():
    sku = str(row.iloc[0]) if not pd.isna(row.iloc[0]) else ""
    stock = row.iloc[2] if len(df.columns) > 2 else 0
    
    # Skip if SKU contains 999 or starts with 999
    if '999' not in sku and pd.notna(stock):
        try:
            stock_val = float(stock)
            if stock_val > 0:
                total_excluding_999 += stock_val
                count_excluding += 1
        except:
            pass

print(f"\n   Total excluding '999' items: {int(total_excluding_999):,} units from {count_excluding} items")

# Show the breakdown by magnitude
print("\n" + "=" * 80)
print("STOCK BREAKDOWN BY QUANTITY")
print("=" * 80)

ranges = {
    "1-5 units": 0,
    "6-10 units": 0,
    "11-50 units": 0,
    "51-100 units": 0,
    "101-500 units": 0,
    "500+ units": 0
}

for i, row in df.iterrows():
    stock = row.iloc[2] if len(df.columns) > 2 else 0
    if pd.notna(stock):
        try:
            stock_val = float(stock)
            if 1 <= stock_val <= 5:
                ranges["1-5 units"] += stock_val
            elif 6 <= stock_val <= 10:
                ranges["6-10 units"] += stock_val
            elif 11 <= stock_val <= 50:
                ranges["11-50 units"] += stock_val
            elif 51 <= stock_val <= 100:
                ranges["51-100 units"] += stock_val
            elif 101 <= stock_val <= 500:
                ranges["101-500 units"] += stock_val
            elif stock_val > 500:
                ranges["500+ units"] += stock_val
        except:
            pass

for range_name, total in ranges.items():
    if total > 0:
        print(f"  {range_name:15} : {int(total):,} units")

print("\n" + "=" * 80)
print("CONCLUSION")
print("=" * 80)
print(f"Excel shows total of {int(total_all):,} units")
print(f"You expected 10,112 units")
print(f"Difference: {int(total_all - 10112):,} units")
print("\nPossible reasons for discrepancy:")
print("1. Excel might have hidden rows or filters applied")
print("2. The 10,112 might be from a different date/version")
print("3. Some items might need to be excluded (like warehouse 999)")
print("4. There might be a subtotal somewhere we're not seeing")
print("=" * 80)