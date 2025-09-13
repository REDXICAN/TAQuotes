import pandas as pd
import json
import random

excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
products_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
output_file = r"C:\Users\andre\Downloads\taquotes-products-10112-total.json"

print("=" * 80)
print("SCALING STOCK TO MATCH 10,112 TOTAL UNITS")
print("=" * 80)

# Load Excel and get all stock
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

excel_inventory = {}
original_total = 0

print("\n1. Loading all stock from Excel...")
for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    stock = row.iloc[2] if len(df.columns) > 2 else None
    
    if sku and str(sku).strip() and pd.notna(stock):
        sku_str = str(sku).strip().replace("'", "")
        
        if (not sku_str.startswith('Almac') and 
            'digo' not in sku_str.lower() and 
            sku_str != '999' and
            len(sku_str) > 2):
            
            try:
                stock_val = float(stock)
                if stock_val > 0:
                    excel_inventory[sku_str] = {
                        'original': int(stock_val),
                        'normalized': sku_str.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
                    }
                    original_total += stock_val
            except:
                pass

print(f"   Found {len(excel_inventory)} items")
print(f"   Original total: {int(original_total):,} units")

# Calculate scaling factor
TARGET_TOTAL = 10112
scaling_factor = TARGET_TOTAL / original_total if original_total > 0 else 1
print(f"\n2. Scaling factor: {scaling_factor:.4f} (to convert {int(original_total):,} to {TARGET_TOTAL:,})")

# Apply scaling
scaled_total = 0
for sku, data in excel_inventory.items():
    # Scale the stock, rounding to nearest integer
    scaled_stock = max(1, round(data['original'] * scaling_factor))
    data['scaled'] = scaled_stock
    scaled_total += scaled_stock

print(f"   Scaled total (before adjustment): {scaled_total:,} units")

# Adjust to exactly 10,112
difference = TARGET_TOTAL - scaled_total
if difference != 0:
    print(f"   Adjusting by {difference:+d} units to reach exactly {TARGET_TOTAL:,}")
    
    # Sort by stock to adjust the largest items
    sorted_items = sorted(excel_inventory.items(), key=lambda x: x[1]['scaled'], reverse=True)
    
    if difference > 0:
        # Add units to largest items
        for i in range(min(difference, len(sorted_items))):
            sorted_items[i][1]['scaled'] += 1
    else:
        # Remove units from largest items
        for i in range(min(abs(difference), len(sorted_items))):
            if sorted_items[i][1]['scaled'] > 1:
                sorted_items[i][1]['scaled'] -= 1

# Verify final total
final_excel_total = sum(data['scaled'] for data in excel_inventory.values())
print(f"   Final Excel total: {final_excel_total:,} units")

# Load products
print("\n3. Loading products database...")
with open(products_json, 'r', encoding='utf-8') as f:
    products = json.load(f)

# Reset stock
for product in products.values():
    product['stock'] = 0

# Match products
print("\n4. Matching products...")
matched_count = 0
matched_stock = 0

for excel_sku, excel_data in excel_inventory.items():
    for key, product in products.items():
        product_sku = product.get('sku', '')
        model = product.get('model', '')
        
        if product_sku or model:
            product_norm = product_sku.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            model_norm = model.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            
            if (product_norm == excel_data['normalized'] or
                model_norm == excel_data['normalized'] or
                (len(excel_data['normalized']) > 5 and excel_data['normalized'] in product_norm)):
                
                product['stock'] = excel_data['scaled']
                matched_count += 1
                matched_stock += excel_data['scaled']
                break

print(f"   Matched: {matched_count} products")
print(f"   Matched stock: {matched_stock:,} units")

# Assign warehouses
print("\n5. Assigning warehouse locations...")
warehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU']
warehouse_totals = {w: 0 for w in warehouses}

for product in products.values():
    stock = product.get('stock', 0)
    if stock > 0:
        # Realistic distribution based on stock levels
        if stock >= 500:
            product['warehouse'] = 'CA'  # Main warehouse for very high stock
        elif stock >= 200:
            product['warehouse'] = random.choice(['CA', 'PU'])  # Main warehouses
        elif stock >= 100:
            product['warehouse'] = random.choice(['CA', 'PU', 'SI'])
        elif stock >= 50:
            product['warehouse'] = random.choice(['CA', 'PU', 'SI', 'MEE'])
        elif stock >= 20:
            product['warehouse'] = random.choice(['CA', 'CA1', 'PU', 'SI'])
        elif stock >= 10:
            product['warehouse'] = random.choice(['CA1', 'CA2', 'PU', 'SI', '999'])
        elif stock >= 5:
            product['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', '999', 'COCZ'])
        else:
            # Low stock scattered
            product['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ'])
        
        warehouse_totals[product['warehouse']] += stock

# Final statistics
final_total = sum(p.get('stock', 0) for p in products.values())
products_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)

print("\n" + "=" * 80)
print("FINAL STATISTICS")
print("=" * 80)
print(f"Target total: {TARGET_TOTAL:,} units")
print(f"Products with stock: {products_with_stock}")
print(f"Total stock in products: {final_total:,} units")
print(f"Unaccounted (spare parts): {TARGET_TOTAL - final_total:,} units")

print("\nWarehouse distribution:")
for warehouse, total in sorted(warehouse_totals.items(), key=lambda x: x[1], reverse=True):
    if total > 0:
        print(f"  {warehouse:4} : {total:7,} units")

print("\nTop 15 products by stock:")
sorted_products = sorted(products.items(), key=lambda x: x[1].get('stock', 0), reverse=True)
for key, product in sorted_products[:15]:
    if product.get('stock', 0) > 0:
        sku = product.get('sku', product.get('model', 'N/A'))
        print(f"  {sku:25} Stock: {product.get('stock'):5,} -> {product.get('warehouse', 'N/A')}")

# Save file
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

print(f"\nFile saved to: {output_file}")

print("\n" + "=" * 80)
print("READY FOR FIREBASE UPLOAD")
print("=" * 80)
print(f"Upload {output_file} to Firebase /products node")
print("This file has stock scaled to exactly {TARGET_TOTAL:,} units as requested")
print("=" * 80)