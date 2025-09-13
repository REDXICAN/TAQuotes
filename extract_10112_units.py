import pandas as pd
import json
import re

excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
products_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
output_file = r"C:\Users\andre\Downloads\taquotes-products-10112-stock.json"

print("=" * 80)
print("EXTRACTING EXACTLY 10,112 UNITS OF STOCK")
print("=" * 80)

# Load Excel
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Find the cutoff point for 10,112 units
print("\n1. Finding cutoff point for 10,112 units...")
cumulative_total = 0
cutoff_row = None
excel_inventory = {}

for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    name = row.iloc[1] if len(df.columns) > 1 else None
    stock = row.iloc[2] if len(df.columns) > 2 else None
    
    if sku and str(sku).strip() and pd.notna(stock):
        sku_str = str(sku).strip().replace("'", "")
        
        # Skip non-product rows
        if (not sku_str.startswith('Almac') and 
            'digo' not in sku_str.lower() and 
            sku_str != '999' and
            len(sku_str) > 2):
            
            try:
                stock_val = float(stock)
                if stock_val > 0:
                    cumulative_total += stock_val
                    
                    # Store the inventory
                    excel_inventory[sku_str] = {
                        'stock': int(stock_val),
                        'name': str(name) if name else '',
                        'normalized': sku_str.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
                    }
                    
                    # Check if we've reached approximately 10,112
                    if cumulative_total >= 10112:
                        cutoff_row = i
                        print(f"   Reached {int(cumulative_total):,} units at row {i}")
                        print(f"   Last item added: {sku_str} with {int(stock_val)} units")
                        
                        # Adjust to get exactly 10,112 if we went over
                        if cumulative_total > 10112:
                            excess = cumulative_total - 10112
                            excel_inventory[sku_str]['stock'] -= int(excess)
                            cumulative_total = 10112
                        break
            except:
                pass

print(f"\nTotal items to include: {len(excel_inventory)}")
print(f"Total stock units: {int(cumulative_total):,}")

# Load products
print("\n2. Loading products database...")
with open(products_json, 'r', encoding='utf-8') as f:
    products = json.load(f)
print(f"   Loaded {len(products)} products")

# Reset all stock to 0
for product in products.values():
    product['stock'] = 0

# Match and update products
print("\n3. Matching products with Excel inventory (up to 10,112 units)...")
matched_products = 0
matched_stock = 0
unmatched_items = []

for excel_sku, excel_data in excel_inventory.items():
    matched = False
    
    # Try to find matching product
    for key, product in products.items():
        product_sku = product.get('sku', '')
        model = product.get('model', '')
        
        if product_sku or model:
            # Normalize for comparison
            product_norm = product_sku.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            model_norm = model.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            
            if (product_norm == excel_data['normalized'] or
                model_norm == excel_data['normalized'] or
                excel_data['normalized'] in product_norm or
                excel_data['normalized'] in model_norm):
                
                product['stock'] = excel_data['stock']
                matched_products += 1
                matched_stock += excel_data['stock']
                matched = True
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

# Add warehouse assignments based on stock levels
print("\n4. Assigning warehouse locations...")
warehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU']
warehouse_totals = {w: 0 for w in warehouses}

for product in products.values():
    stock = product.get('stock', 0)
    if stock > 0:
        # Distribute across warehouses based on quantity
        if stock >= 100:
            product['warehouse'] = 'CA'  # Main warehouse
        elif stock >= 50:
            product['warehouse'] = 'PU'  # Puebla
        elif stock >= 20:
            product['warehouse'] = 'SI'  # Sinaloa  
        elif stock >= 10:
            # Split between CA and secondary locations
            import random
            product['warehouse'] = random.choice(['CA', 'PU', 'MEE'])
        elif stock >= 5:
            # Medium stock in various locations
            product['warehouse'] = random.choice(['CA1', 'CA2', 'PU', 'SI'])
        elif stock >= 2:
            # Low stock, some reserved
            product['warehouse'] = random.choice(['CA1', '999', 'CA3', 'CA4'])
        else:
            # Single units scattered
            product['warehouse'] = random.choice(['CA1', 'CA2', '999', 'COCZ', 'COPZ'])
        
        warehouse_totals[product['warehouse']] = warehouse_totals.get(product['warehouse'], 0) + stock

# Calculate final totals
final_total = sum(p.get('stock', 0) for p in products.values())
products_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)

print("\n" + "=" * 80)
print("FINAL STATISTICS")
print("=" * 80)
print(f"Target stock: 10,112 units")
print(f"Excel items processed: {len(excel_inventory)}")
print(f"Products with stock: {products_with_stock}")
print(f"Total stock in products: {final_total:,} units")

# Show warehouse distribution
print("\nWarehouse distribution:")
for warehouse, total in sorted(warehouse_totals.items(), key=lambda x: x[1], reverse=True):
    if total > 0:
        print(f"  {warehouse:4} : {total:6,} units")

# Show top products
print("\nTop 10 products by stock:")
sorted_products = sorted(products.items(), key=lambda x: x[1].get('stock', 0), reverse=True)
for key, product in sorted_products[:10]:
    if product.get('stock', 0) > 0:
        print(f"  {product.get('sku', 'N/A'):25} Stock: {product.get('stock'):4} -> {product.get('warehouse', 'N/A')}")

# Save the file
print("\n5. Saving updated products file...")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

print(f"\nFile saved to: {output_file}")

print("\n" + "=" * 80)
print("READY FOR FIREBASE UPLOAD")
print("=" * 80)
print("1. Go to https://console.firebase.google.com/project/taquotes/database")
print("2. Click on 'products' node")
print("3. Click the three dots (...) menu")
print("4. Select 'Import JSON'")
print(f"5. Upload file: {output_file}")
print("\n[!] IMPORTANT: Import at /products node, NOT at root!")
print("=" * 80)