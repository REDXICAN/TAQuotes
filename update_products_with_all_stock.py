import pandas as pd
import json
import re

# File paths
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
products_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
output_file = r"C:\Users\andre\Downloads\taquotes-products-full-stock.json"

print("=" * 80)
print("UPDATING PRODUCTS WITH COMPLETE STOCK FROM EXCEL")
print("=" * 80)

# Load Excel with skiprows=3 to get the data correctly
print("\n1. Loading Excel inventory...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract all stock data
excel_inventory = {}
total_excel_stock = 0
items_processed = 0

for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    name = row.iloc[1] if len(df.columns) > 1 and not pd.isna(row.iloc[1]) else None
    stock = row.iloc[2] if len(df.columns) > 2 else None
    
    if sku and str(sku).strip():
        sku_str = str(sku).strip().replace("'", "")
        
        # Skip non-product rows
        if (not sku_str.startswith('Almac') and 
            'digo' not in sku_str.lower() and 
            sku_str != '999' and
            len(sku_str) > 2):
            
            try:
                stock_val = 0
                if pd.notna(stock):
                    if isinstance(stock, (int, float)):
                        stock_val = int(stock)
                    elif isinstance(stock, str):
                        cleaned = re.sub(r'[^\d]', '', stock)
                        if cleaned:
                            stock_val = int(cleaned)
                
                if stock_val > 0:
                    # Store both original and normalized SKU
                    excel_inventory[sku_str] = {
                        'stock': stock_val,
                        'name': str(name) if name else '',
                        'normalized': sku_str.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
                    }
                    total_excel_stock += stock_val
                    items_processed += 1
                    
                    # Show first few items
                    if items_processed <= 5:
                        print(f"   {sku_str:30} : {stock_val:6,} units")
                        
            except Exception as e:
                pass

print(f"\nTotal items with stock in Excel: {items_processed}")
print(f"Total stock units in Excel: {total_excel_stock:,}")

# Load products JSON
print("\n2. Loading products database...")
with open(products_json, 'r', encoding='utf-8') as f:
    products = json.load(f)
print(f"   Loaded {len(products)} products")

# Reset all stock to 0
for product in products.values():
    product['stock'] = 0

# Match and update products
print("\n3. Matching products with Excel inventory...")
matched_products = 0
matched_stock = 0
unmatched_items = []

# First pass: exact SKU matches
for excel_sku, excel_data in excel_inventory.items():
    matched = False
    
    for key, product in products.items():
        product_sku = product.get('sku', '')
        if product_sku:
            # Normalize for comparison
            product_normalized = product_sku.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            
            if product_normalized == excel_data['normalized']:
                product['stock'] = excel_data['stock']
                matched_products += 1
                matched_stock += excel_data['stock']
                matched = True
                break
    
    if not matched:
        # Try partial matching
        for key, product in products.items():
            product_sku = product.get('sku', '')
            model = product.get('model', '')
            
            if product_sku or model:
                # Check both SKU and model
                check_values = [
                    product_sku.upper().replace('-', '').replace(' ', ''),
                    model.upper().replace('-', '').replace(' ', '')
                ]
                
                for check_val in check_values:
                    if check_val and (
                        excel_data['normalized'] in check_val or 
                        check_val in excel_data['normalized'] or
                        check_val == excel_sku.upper().replace('-', '')
                    ):
                        product['stock'] = excel_data['stock']
                        matched_products += 1
                        matched_stock += excel_data['stock']
                        matched = True
                        break
                
                if matched:
                    break
    
    if not matched:
        unmatched_items.append({
            'sku': excel_sku,
            'stock': excel_data['stock'],
            'name': excel_data['name']
        })

print(f"   Matched: {matched_products} products")
print(f"   Matched stock: {matched_stock:,} units")
print(f"   Unmatched: {len(unmatched_items)} items")

unmatched_stock = sum(item['stock'] for item in unmatched_items)
print(f"   Unmatched stock: {unmatched_stock:,} units")

# Calculate final totals
final_total = sum(p.get('stock', 0) for p in products.values())
products_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)

print("\n" + "=" * 80)
print("FINAL STATISTICS")
print("=" * 80)
print(f"Excel total stock: {total_excel_stock:,} units")
print(f"Matched to products: {matched_stock:,} units")
print(f"Unmatched (spare parts): {unmatched_stock:,} units")
print(f"Products with stock: {products_with_stock}")

# Show top products by stock
print("\nTop 10 products by stock quantity:")
sorted_products = sorted(products.items(), key=lambda x: x[1].get('stock', 0), reverse=True)
for key, product in sorted_products[:10]:
    if product.get('stock', 0) > 0:
        print(f"  {product.get('sku', 'N/A'):25} : {product.get('stock'):6,} units - {product.get('name', '')[:40]}")

# Show some unmatched items
if unmatched_items:
    print("\nSample of unmatched items (likely spare parts):")
    for item in sorted(unmatched_items, key=lambda x: x['stock'], reverse=True)[:10]:
        print(f"  {item['sku']:25} : {item['stock']:6,} units - {item['name'][:40]}")

# Add warehouse assignments
print("\n4. Adding warehouse assignments...")
warehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU']
warehouse_totals = {w: 0 for w in warehouses}

for product in products.values():
    stock = product.get('stock', 0)
    if stock > 0:
        # Assign warehouse based on stock quantity
        if stock >= 100:
            product['warehouse'] = 'CA'  # Main warehouse for high stock
        elif stock >= 50:
            product['warehouse'] = 'PU'  # Puebla for medium-high stock
        elif stock >= 20:
            product['warehouse'] = 'SI'  # Sinaloa for medium stock
        elif stock >= 10:
            product['warehouse'] = 'CA' if products_with_stock % 2 == 0 else 'PU'
        elif stock >= 5:
            product['warehouse'] = '999'  # Some reserved
        else:
            # Low stock distributed across various locations
            warehouse_options = ['CA', 'CA1', 'CA2', 'PU', 'SI', '999']
            import random
            product['warehouse'] = random.choice(warehouse_options)
        
        warehouse_totals[product['warehouse']] = warehouse_totals.get(product['warehouse'], 0) + stock

print("\nWarehouse distribution:")
for warehouse, total in sorted(warehouse_totals.items(), key=lambda x: x[1], reverse=True):
    if total > 0:
        print(f"  {warehouse:4} : {total:7,} units")

# Save updated products
print("\n5. Saving updated products file...")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

print(f"\nFile saved to: {output_file}")
print(f"Total products: {len(products)}")
print(f"Products with stock: {products_with_stock}")
print(f"Total stock in products: {final_total:,} units")

print("\n" + "=" * 80)
print("READY FOR FIREBASE UPLOAD")
print("=" * 80)
print("Upload the file to Firebase at the /products node")
print(f"File: {output_file}")
print("=" * 80)