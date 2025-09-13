import json
import pandas as pd
import re

# File paths
json_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
updated_json_file = r"C:\Users\andre\Downloads\taquotes-products-with-stock.json"

print("=" * 80)
print("STOCK MATCHING VERIFICATION REPORT")
print("=" * 80)

# Load original products
with open(json_file, 'r', encoding='utf-8') as f:
    original_products = json.load(f)

# Load updated products
with open(updated_json_file, 'r', encoding='utf-8') as f:
    updated_products = json.load(f)

# Load Excel inventory
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract all inventory items from Excel
excel_inventory = {}
total_excel_stock = 0

for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    name = row.iloc[1] if len(df.columns) > 1 and not pd.isna(row.iloc[1]) else None
    stock = row.iloc[2] if len(df.columns) > 2 else None
    
    if sku and str(sku).strip():
        sku_str = str(sku).strip().replace("'", "")
        # Skip non-product rows
        if (not sku_str.startswith('Almac') and 
            'digo' not in sku_str and 
            sku_str != '999' and
            len(sku_str) > 2):
            
            try:
                stock_val = int(float(str(stock))) if pd.notna(stock) else 0
            except:
                stock_val = 0
            
            if stock_val > 0:  # Only track items with actual stock
                excel_inventory[sku_str] = {
                    'name': str(name) if name else '',
                    'stock': stock_val
                }
                total_excel_stock += stock_val

print(f"\n[EXCEL INVENTORY ANALYSIS]")
print(f"  Total items with stock > 0: {len(excel_inventory)}")
print(f"  Total stock quantity: {total_excel_stock}")

# Normalize function
def normalize_sku(sku):
    if not sku:
        return ""
    normalized = sku.upper()
    normalized = re.sub(r'[-()\s]', '', normalized)
    normalized = re.sub(r'(AL|AR)$', '', normalized)
    return normalized

# Track which Excel items were matched
excel_matched = {}
excel_unmatched = {}

# Check each Excel inventory item
for excel_sku, excel_data in excel_inventory.items():
    normalized_excel = normalize_sku(excel_sku)
    matched = False
    
    # Look for this Excel SKU in the updated products
    for prod_key, prod_data in updated_products.items():
        prod_sku = prod_data.get('sku', '')
        normalized_prod = normalize_sku(prod_sku)
        
        if (normalized_excel == normalized_prod or
            normalized_excel in normalized_prod or
            normalized_prod in normalized_excel):
            
            if prod_data.get('stock', 0) == excel_data['stock']:
                matched = True
                excel_matched[excel_sku] = {
                    'product_sku': prod_sku,
                    'stock': excel_data['stock'],
                    'name': excel_data['name']
                }
                break
    
    if not matched:
        excel_unmatched[excel_sku] = excel_data

# Calculate stock totals in updated JSON
total_json_stock = sum(p.get('stock', 0) for p in updated_products.values())
products_with_stock = sum(1 for p in updated_products.values() if p.get('stock', 0) > 0)

print(f"\n[JSON PRODUCTS ANALYSIS]")
print(f"  Total products: {len(updated_products)}")
print(f"  Products with stock > 0: {products_with_stock}")
print(f"  Total stock quantity: {total_json_stock}")

print(f"\n[MATCHING RESULTS]")
print(f"  Excel items matched to products: {len(excel_matched)}")
print(f"  Excel items NOT matched: {len(excel_unmatched)}")

if excel_matched:
    print(f"\n[SAMPLE OF MATCHED ITEMS] (first 20):")
    for i, (excel_sku, match_data) in enumerate(list(excel_matched.items())[:20]):
        print(f"  {excel_sku:<20} -> {match_data['product_sku']:<20} Stock: {match_data['stock']}")

if excel_unmatched:
    print(f"\n[WARNING: EXCEL ITEMS NOT MATCHED TO ANY PRODUCT]")
    print(f"  (These {len(excel_unmatched)} items have stock but no matching product in JSON)")
    
    # Group unmatched items by potential product line
    grouped = {}
    for sku, data in excel_unmatched.items():
        prefix = sku[:3] if len(sku) >= 3 else 'OTHER'
        if prefix not in grouped:
            grouped[prefix] = []
        grouped[prefix].append((sku, data['stock'], data['name']))
    
    for prefix, items in sorted(grouped.items()):
        print(f"\n  [{prefix}...] - {len(items)} items:")
        for sku, stock, name in sorted(items)[:5]:  # Show first 5 of each group
            print(f"    {sku:<20} Stock: {stock:>3} - {name[:40]}")
        if len(items) > 5:
            print(f"    ... and {len(items)-5} more")

# Check for potential matching issues
print(f"\n[MATCHING DIAGNOSTICS]")

# Find products that might have wrong stock values
suspicious = []
for prod_key, prod_data in updated_products.items():
    prod_sku = prod_data.get('sku', '')
    prod_stock = prod_data.get('stock', 0)
    
    if prod_stock > 0:
        # Check if this stock value exists in Excel for a different SKU
        for excel_sku, excel_data in excel_inventory.items():
            if excel_data['stock'] == prod_stock and excel_sku != prod_sku:
                normalized_excel = normalize_sku(excel_sku)
                normalized_prod = normalize_sku(prod_sku)
                if normalized_excel != normalized_prod:
                    suspicious.append((prod_sku, excel_sku, prod_stock))

if suspicious:
    print(f"  [WARNING] Found {len(suspicious)} products with potentially mismatched stock")
else:
    print(f"  [OK] No obvious mismatches detected")

# Summary
print(f"\n" + "=" * 80)
print(f"SUMMARY:")
print(f"  Excel total stock: {total_excel_stock}")
print(f"  JSON total stock: {total_json_stock}")
print(f"  Difference: {total_excel_stock - total_json_stock}")
print(f"  Match rate: {len(excel_matched)}/{len(excel_inventory)} ({len(excel_matched)*100//len(excel_inventory) if excel_inventory else 0}%)")

if total_excel_stock > total_json_stock:
    print(f"\n  ⚠️ WARNING: {total_excel_stock - total_json_stock} units from Excel not accounted for in JSON")
    print(f"     This represents {len(excel_unmatched)} unmatched Excel SKUs")
elif total_excel_stock < total_json_stock:
    print(f"\n  ⚠️ WARNING: JSON has {total_json_stock - total_excel_stock} more units than Excel")
else:
    print(f"\n  ✅ Perfect match: All stock accounted for!")

print("=" * 80)