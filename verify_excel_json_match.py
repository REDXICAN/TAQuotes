import json
import pandas as pd
import re

# File paths
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
json_file = r"C:\Users\andre\Downloads\taquotes-products-with-stock-final.json"

print("=" * 80)
print("EXCEL vs JSON STOCK VERIFICATION")
print("=" * 80)

# Load JSON
print("\n1. Loading JSON file...")
with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)

# Load Excel
print("2. Loading Excel file...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract Excel inventory with stock > 0
excel_inventory = {}
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

print(f"\nExcel items with stock > 0: {len(excel_inventory)}")
print(f"JSON products total: {len(products)}")

# Function to normalize SKU
def normalize_sku(sku):
    if not sku:
        return ""
    normalized = sku.upper()
    normalized = re.sub(r'[-()\s]', '', normalized)
    normalized = re.sub(r'(AL|AR)$', '', normalized)
    return normalized

# Check each Excel item against JSON
print("\n" + "=" * 80)
print("VERIFYING EACH EXCEL ITEM IN JSON:")
print("=" * 80)

perfect_matches = []
mismatches = []
not_found = []

for excel_sku, excel_data in excel_inventory.items():
    excel_norm = normalize_sku(excel_sku)
    found = False
    
    for prod_key, prod_data in products.items():
        prod_sku = prod_data.get('sku', '')
        prod_norm = normalize_sku(prod_sku)
        
        if (excel_norm == prod_norm or 
            excel_norm in prod_norm or 
            prod_norm in excel_norm):
            
            json_stock = prod_data.get('stock', 0)
            excel_stock = excel_data['stock']
            
            if json_stock == excel_stock:
                perfect_matches.append({
                    'excel_sku': excel_sku,
                    'json_sku': prod_sku,
                    'stock': excel_stock
                })
            else:
                mismatches.append({
                    'excel_sku': excel_sku,
                    'json_sku': prod_sku,
                    'excel_stock': excel_stock,
                    'json_stock': json_stock
                })
            found = True
            break
    
    if not found:
        not_found.append({
            'excel_sku': excel_sku,
            'stock': excel_data['stock'],
            'name': excel_data['name']
        })

# Display results
print(f"\n[OK] PERFECT MATCHES: {len(perfect_matches)}")
if perfect_matches:
    print("Sample (first 10):")
    for match in perfect_matches[:10]:
        print(f"  {match['excel_sku']:<20} = {match['json_sku']:<20} Stock: {match['stock']}")

print(f"\n[WARNING] STOCK MISMATCHES: {len(mismatches)}")
if mismatches:
    print("ALL MISMATCHES (Excel stock != JSON stock):")
    for mismatch in mismatches:
        print(f"  {mismatch['excel_sku']:<20} -> {mismatch['json_sku']:<20}")
        print(f"    Excel: {mismatch['excel_stock']} | JSON: {mismatch['json_stock']}")

print(f"\n[ERROR] NOT FOUND IN JSON: {len(not_found)}")
if not_found:
    print("Excel items with no matching product in JSON:")
    for item in not_found[:20]:  # Show first 20
        print(f"  {item['excel_sku']:<20} Stock: {item['stock']:>3} - {item['name'][:40]}")
    if len(not_found) > 20:
        print(f"  ... and {len(not_found) - 20} more")

# Calculate totals
excel_total = sum(item['stock'] for item in excel_inventory.values())
json_total = sum(p.get('stock', 0) for p in products.values())
json_items_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)

print("\n" + "=" * 80)
print("SUMMARY:")
print("=" * 80)
print(f"Excel: {len(excel_inventory)} items with total {excel_total} units")
print(f"JSON: {json_items_with_stock} items with total {json_total} units")
print(f"Difference: {excel_total - json_total} units")

if excel_total == json_total:
    print("\n[SUCCESS] TOTAL STOCK MATCHES PERFECTLY!")
else:
    print(f"\n[WARNING] STOCK DIFFERENCE: Excel has {excel_total} units, JSON has {json_total} units")
    print(f"   Missing {excel_total - json_total} units in JSON")

# List top 10 products by stock in JSON
print("\n" + "=" * 80)
print("TOP 10 PRODUCTS BY STOCK IN JSON:")
print("=" * 80)
sorted_products = sorted(products.items(), key=lambda x: x[1].get('stock', 0), reverse=True)
for i, (key, product) in enumerate(sorted_products[:10]):
    print(f"{i+1}. {product.get('sku', 'N/A'):<20} Stock: {product.get('stock', 0)}")

print("\n" + "=" * 80)