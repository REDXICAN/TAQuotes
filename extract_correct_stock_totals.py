import pandas as pd
import json
import re

# File paths
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
products_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
output_file = r"C:\Users\andre\Downloads\taquotes-products-correct-stock.json"

print("=" * 80)
print("EXTRACTING CORRECT STOCK TOTALS FROM EXCEL")
print("Target Total: 10,112 units")
print("=" * 80)

# Load the Excel file
print("\n1. Loading Excel file...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

print(f"   Loaded {len(df)} rows")
print(f"   Columns: {list(df.columns[:5])}")

# Extract stock data from column 2 (Existencia)
print("\n2. Extracting stock from 'Existencia' column...")
total_stock = 0
stock_by_sku = {}
items_with_stock = 0

for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    stock = row.iloc[2] if len(df.columns) > 2 else None
    
    if sku and str(sku).strip():
        sku_str = str(sku).strip().replace("'", "")
        
        # Skip header rows and non-product entries
        if (not sku_str.startswith('Almac') and 
            'digo' not in sku_str and 
            sku_str != '999' and
            len(sku_str) > 2):
            
            try:
                # Try to extract stock value
                if pd.notna(stock):
                    stock_val = 0
                    if isinstance(stock, (int, float)):
                        stock_val = int(stock)
                    elif isinstance(stock, str):
                        # Remove non-numeric characters
                        cleaned = re.sub(r'[^\d.-]', '', stock)
                        if cleaned:
                            stock_val = int(float(cleaned))
                    
                    if stock_val > 0:
                        # Normalize SKU (remove dashes for matching)
                        normalized_sku = sku_str.upper().replace('-', '').replace(' ', '')
                        stock_by_sku[normalized_sku] = stock_val
                        total_stock += stock_val
                        items_with_stock += 1
                        
                        # Show some examples
                        if items_with_stock <= 10:
                            print(f"   {sku_str:30} : {stock_val:5} units")
            except Exception as e:
                pass

print(f"\nTotal stock found in Excel: {total_stock:,} units")
print(f"Items with stock: {items_with_stock}")

if total_stock < 10000:
    print("\n⚠️ WARNING: Total is less than expected 10,112")
    print("   Checking if there are multiple quantity columns...")
    
    # Check all columns for numeric data
    numeric_totals = []
    for col_idx in range(2, min(len(df.columns), 20)):
        col_sum = 0
        for i, row in df.iterrows():
            try:
                val = row.iloc[col_idx]
                if pd.notna(val) and isinstance(val, (int, float)):
                    col_sum += int(val)
            except:
                pass
        if col_sum > 0:
            numeric_totals.append((col_idx, df.columns[col_idx] if col_idx < len(df.columns) else f"Col{col_idx}", col_sum))
    
    print("\n   Numeric columns found:")
    for idx, name, total in numeric_totals:
        print(f"     Column {idx} ({name}): {total:,} units")

# Load products JSON
print("\n3. Loading products from Firebase export...")
with open(products_json, 'r', encoding='utf-8') as f:
    products = json.load(f)
print(f"   Loaded {len(products)} products")

# Reset all stock to 0 first
for product in products.values():
    product['stock'] = 0

# Update products with stock from Excel
print("\n4. Matching products with Excel stock...")
matched = 0
unmatched_skus = []

for excel_sku, stock_val in stock_by_sku.items():
    found = False
    
    # Try to find matching product
    for key, product in products.items():
        product_sku = product.get('sku', '')
        if product_sku:
            # Normalize product SKU for comparison
            normalized_product = product_sku.upper().replace('-', '').replace(' ', '')
            
            # Check for exact match or close match
            if (normalized_product == excel_sku or 
                excel_sku in normalized_product or 
                normalized_product in excel_sku):
                
                product['stock'] = stock_val
                matched += 1
                found = True
                break
    
    if not found:
        unmatched_skus.append((excel_sku, stock_val))

print(f"   Matched: {matched} products")
print(f"   Unmatched: {len(unmatched_skus)} items")

# Calculate final totals
final_total = sum(p.get('stock', 0) for p in products.values())
products_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)

print("\n" + "=" * 80)
print("FINAL STATISTICS")
print("=" * 80)
print(f"Total stock in products JSON: {final_total:,} units")
print(f"Products with stock > 0: {products_with_stock}")
print(f"Expected total: 10,112 units")
print(f"Difference: {10112 - final_total:,} units")

if unmatched_skus:
    print("\n" + "=" * 80)
    print("UNMATCHED ITEMS (not in products database)")
    print("=" * 80)
    print("These are likely spare parts or accessories:")
    unmatched_total = sum(stock for _, stock in unmatched_skus)
    print(f"Total unmatched stock: {unmatched_total:,} units")
    print("\nFirst 20 unmatched items:")
    for sku, stock in unmatched_skus[:20]:
        print(f"  {sku:30} : {stock:5} units")

# Save the updated products
print("\n" + "=" * 80)
print("SAVING UPDATED PRODUCTS")
print("=" * 80)

with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

print(f"File saved to: {output_file}")
print(f"Total products: {len(products)}")
print(f"Products with stock: {products_with_stock}")
print(f"Total stock units: {final_total:,}")

# Show sample of high-stock items
print("\nSample of products with highest stock:")
sorted_products = sorted(products.items(), key=lambda x: x[1].get('stock', 0), reverse=True)
for key, product in sorted_products[:10]:
    if product.get('stock', 0) > 0:
        print(f"  {product.get('sku', 'N/A'):25} : {product.get('stock'):5} units")

print("\n" + "=" * 80)
print("NEXT STEPS")
print("=" * 80)
print("If total is still not 10,112, the difference is likely:")
print("1. Spare parts not in the products database")
print("2. Items with SKU formats that don't match")
print("3. Multiple quantity columns that need to be summed")
print("=" * 80)