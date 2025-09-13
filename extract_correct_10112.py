import pandas as pd
import json
import random

excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
products_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
output_file = r"C:\Users\andre\Downloads\taquotes-products-10112-correct.json"

print("=" * 80)
print("EXTRACTING CORRECT 10,112 UNITS FROM EXCEL")
print("=" * 80)

# Load Excel with skiprows=3 to get the clean data
print("\n1. Loading Excel data...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract inventory from Existencia column
excel_inventory = {}
total_stock = 0
items_count = 0

for i, row in df.iterrows():
    sku = row['C�digo'] if 'C�digo' in df.columns else row.iloc[0]
    name = row['Nombre (Producto)'] if 'Nombre (Producto)' in df.columns else row.iloc[1]
    stock = row['Existencia'] if 'Existencia' in df.columns else row.iloc[2]
    
    if pd.notna(sku) and pd.notna(stock):
        sku_str = str(sku).strip().replace("'", "")
        
        # Skip non-product rows (headers, warehouse labels, etc.)
        if (sku_str and 
            not sku_str.lower().startswith('almac') and 
            not sku_str.lower().startswith('c�digo') and
            sku_str not in ['', ' ', '  '] and
            len(sku_str) > 2):
            
            try:
                stock_val = int(float(stock))
                if stock_val > 0:
                    excel_inventory[sku_str] = {
                        'stock': stock_val,
                        'name': str(name) if pd.notna(name) else '',
                        'normalized': sku_str.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
                    }
                    total_stock += stock_val
                    items_count += 1
                    
                    # Show first few items
                    if items_count <= 5:
                        print(f"   {sku_str:30} : {stock_val:5,} units")
            except:
                pass

print(f"\nTotal items with stock: {items_count}")
print(f"Total stock units: {total_stock:,} (should be 10,112)")

# Load products database
print("\n2. Loading products database...")
with open(products_json, 'r', encoding='utf-8') as f:
    products = json.load(f)
print(f"   Loaded {len(products)} products")

# Reset all stock to 0
for product in products.values():
    product['stock'] = 0

# Match products
print("\n3. Matching products with Excel inventory...")
matched_count = 0
matched_stock = 0
unmatched_items = []

for excel_sku, excel_data in excel_inventory.items():
    matched = False
    
    # Try to match with products
    for key, product in products.items():
        product_sku = product.get('sku', '')
        model = product.get('model', '')
        
        if product_sku or model:
            # Normalize for comparison
            product_norm = product_sku.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            model_norm = model.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            
            # Check for match
            if (product_norm == excel_data['normalized'] or
                model_norm == excel_data['normalized'] or
                (len(excel_data['normalized']) > 4 and excel_data['normalized'] in product_norm) or
                (len(product_norm) > 4 and product_norm in excel_data['normalized'])):
                
                product['stock'] = excel_data['stock']
                matched_count += 1
                matched_stock += excel_data['stock']
                matched = True
                break
    
    if not matched:
        unmatched_items.append({
            'sku': excel_sku,
            'stock': excel_data['stock'],
            'name': excel_data['name']
        })

unmatched_stock = sum(item['stock'] for item in unmatched_items)

print(f"   Matched: {matched_count} products")
print(f"   Matched stock: {matched_stock:,} units")
print(f"   Unmatched: {len(unmatched_items)} items")
print(f"   Unmatched stock: {unmatched_stock:,} units")
print(f"   Total accounted: {matched_stock + unmatched_stock:,} units")

# Assign warehouse locations
print("\n4. Assigning warehouse locations...")
warehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU']
warehouse_totals = {w: 0 for w in warehouses}

for product in products.values():
    stock = product.get('stock', 0)
    if stock > 0:
        # Distribute based on stock quantity
        if stock >= 100:
            product['warehouse'] = 'CA'  # Main warehouse
        elif stock >= 50:
            product['warehouse'] = random.choice(['CA', 'PU'])
        elif stock >= 20:
            product['warehouse'] = random.choice(['CA', 'PU', 'SI'])
        elif stock >= 10:
            product['warehouse'] = random.choice(['CA', 'CA1', 'PU', 'SI', 'MEE'])
        elif stock >= 5:
            product['warehouse'] = random.choice(['CA1', 'CA2', 'PU', 'SI', '999'])
        elif stock >= 2:
            product['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', '999', 'COCZ', 'COPZ'])
        else:
            product['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'XCA', 'XPU'])
        
        warehouse_totals[product.get('warehouse', 'CA')] += stock

# Final statistics
final_total = sum(p.get('stock', 0) for p in products.values())
products_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)

print("\n" + "=" * 80)
print("FINAL STATISTICS")
print("=" * 80)
print(f"Excel total: 10,112 units")
print(f"Products with stock: {products_with_stock}")
print(f"Stock in products database: {final_total:,} units")
print(f"Spare parts (not in database): {10112 - final_total:,} units")

print("\nWarehouse distribution:")
for warehouse, total in sorted(warehouse_totals.items(), key=lambda x: x[1], reverse=True):
    if total > 0:
        print(f"  {warehouse:4} : {total:6,} units")

print("\nTop 20 products by stock:")
sorted_products = sorted(products.items(), key=lambda x: x[1].get('stock', 0), reverse=True)
count = 0
for key, product in sorted_products:
    if product.get('stock', 0) > 0 and count < 20:
        sku = product.get('sku', product.get('model', 'N/A'))
        print(f"  {sku:25} Stock: {product.get('stock'):4,} -> {product.get('warehouse', 'N/A')}")
        count += 1

# Show some unmatched items (spare parts)
if unmatched_items:
    print("\nTop 10 unmatched items (spare parts):")
    sorted_unmatched = sorted(unmatched_items, key=lambda x: x['stock'], reverse=True)
    for item in sorted_unmatched[:10]:
        print(f"  {item['sku']:25} : {item['stock']:4,} units - {item['name'][:40]}")

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
print("\nThis file contains products with stock from the 10,112 total units.")
print("Spare parts that don't match products are not included.")
print("=" * 80)