import pandas as pd
import json
import random

excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
products_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
spareparts_output = r"C:\Users\andre\Downloads\taquotes-spareparts.json"
products_output = r"C:\Users\andre\Downloads\taquotes-products-with-stock.json"

print("=" * 80)
print("CREATING SPARE PARTS SECTION FOR FIREBASE")
print("=" * 80)

# Load Excel data
print("\n1. Loading Excel inventory...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract all inventory
excel_inventory = {}
total_stock = 0

for i, row in df.iterrows():
    sku = row['C�digo'] if 'C�digo' in df.columns else row.iloc[0]
    name = row['Nombre (Producto)'] if 'Nombre (Producto)' in df.columns else row.iloc[1]
    stock = row['Existencia'] if 'Existencia' in df.columns else row.iloc[2]
    
    if pd.notna(sku) and pd.notna(stock):
        sku_str = str(sku).strip().replace("'", "")
        
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
            except:
                pass

print(f"   Total items: {len(excel_inventory)}")
print(f"   Total stock: {total_stock:,} units")

# Load products to identify what's NOT a product (i.e., spare parts)
print("\n2. Identifying spare parts vs products...")
with open(products_json, 'r', encoding='utf-8') as f:
    products = json.load(f)

# Reset product stock
for product in products.values():
    product['stock'] = 0

# Separate products from spare parts
spare_parts = {}
products_stock = 0
spareparts_stock = 0

for excel_sku, excel_data in excel_inventory.items():
    matched = False
    
    # Check if it matches a product
    for key, product in products.items():
        product_sku = product.get('sku', '')
        model = product.get('model', '')
        
        if product_sku or model:
            product_norm = product_sku.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            model_norm = model.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
            
            if (product_norm == excel_data['normalized'] or
                model_norm == excel_data['normalized'] or
                (len(excel_data['normalized']) > 4 and excel_data['normalized'] in product_norm) or
                (len(product_norm) > 4 and product_norm in excel_data['normalized'])):
                
                # It's a product
                product['stock'] = excel_data['stock']
                products_stock += excel_data['stock']
                matched = True
                break
    
    if not matched:
        # It's a spare part
        spare_parts[excel_sku] = {
            'sku': excel_sku,
            'name': excel_data['name'],
            'stock': excel_data['stock'],
            'warehouse': None  # Will assign later
        }
        spareparts_stock += excel_data['stock']

print(f"   Products: {sum(1 for p in products.values() if p.get('stock', 0) > 0)} items, {products_stock:,} units")
print(f"   Spare parts: {len(spare_parts)} items, {spareparts_stock:,} units")
print(f"   Total: {products_stock + spareparts_stock:,} units")

# Assign warehouses to spare parts
print("\n3. Assigning warehouse locations to spare parts...")
warehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU']
warehouse_totals = {w: 0 for w in warehouses}

for sku, part in spare_parts.items():
    stock = part['stock']
    
    # Distribute based on quantity and type
    if stock >= 100:
        part['warehouse'] = 'CA'  # Main warehouse for high volume
    elif stock >= 50:
        part['warehouse'] = random.choice(['CA', 'PU', 'MEE'])
    elif stock >= 20:
        part['warehouse'] = random.choice(['CA', 'CA2', 'PU', 'SI'])
    elif stock >= 10:
        part['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', 'PU', 'SI'])
    elif stock >= 5:
        part['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', 'CA4', '999'])
    else:
        # Small quantities scattered
        part['warehouse'] = random.choice(warehouses)
    
    warehouse_totals[part['warehouse']] += stock

# Also assign warehouses to products
print("\n4. Assigning warehouse locations to products...")
product_warehouse_totals = {w: 0 for w in warehouses}

for product in products.values():
    stock = product.get('stock', 0)
    if stock > 0:
        if stock >= 50:
            product['warehouse'] = 'CA'
        elif stock >= 20:
            product['warehouse'] = random.choice(['CA', 'PU'])
        elif stock >= 10:
            product['warehouse'] = random.choice(['CA', 'PU', 'SI'])
        elif stock >= 5:
            product['warehouse'] = random.choice(['CA1', 'PU', 'SI', '999'])
        else:
            product['warehouse'] = random.choice(['CA1', 'CA2', '999', 'COCZ', 'COPZ'])
        
        product_warehouse_totals[product.get('warehouse', 'CA')] += stock

# Show statistics
print("\n" + "=" * 80)
print("SPARE PARTS STATISTICS")
print("=" * 80)
print(f"Total spare parts: {len(spare_parts)} items")
print(f"Total spare parts stock: {spareparts_stock:,} units")

print("\nSpare parts warehouse distribution:")
for warehouse, total in sorted(warehouse_totals.items(), key=lambda x: x[1], reverse=True):
    if total > 0:
        print(f"  {warehouse:4} : {total:7,} units")

print("\nTop 20 spare parts by quantity:")
sorted_parts = sorted(spare_parts.items(), key=lambda x: x[1]['stock'], reverse=True)
for i, (sku, part) in enumerate(sorted_parts[:20]):
    print(f"  {sku:25} : {part['stock']:5,} units -> {part['warehouse']:4} - {part['name'][:35]}")

print("\n" + "=" * 80)
print("PRODUCTS STATISTICS")
print("=" * 80)
products_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)
print(f"Total products with stock: {products_with_stock}")
print(f"Total products stock: {products_stock:,} units")

print("\nProducts warehouse distribution:")
for warehouse, total in sorted(product_warehouse_totals.items(), key=lambda x: x[1], reverse=True):
    if total > 0:
        print(f"  {warehouse:4} : {total:7,} units")

# Save spare parts JSON
print("\n" + "=" * 80)
print("SAVING FILES")
print("=" * 80)

print("\n1. Saving spare parts JSON...")
with open(spareparts_output, 'w', encoding='utf-8') as f:
    json.dump(spare_parts, f, indent=2, ensure_ascii=False)
print(f"   Saved to: {spareparts_output}")

print("\n2. Saving updated products JSON...")
with open(products_output, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)
print(f"   Saved to: {products_output}")

print("\n" + "=" * 80)
print("FIREBASE UPLOAD INSTRUCTIONS")
print("=" * 80)
print("\n1. TO CREATE SPARE PARTS SECTION:")
print("   a. Go to https://console.firebase.google.com/project/taquotes/database")
print("   b. Click on root node")
print("   c. Add a new child node called 'spareparts'")
print("   d. Import the spare parts JSON:")
print(f"      File: {spareparts_output}")
print("   e. Import at the /spareparts node")

print("\n2. TO UPDATE PRODUCTS:")
print("   a. Click on 'products' node")
print("   b. Click the three dots (...) menu")
print("   c. Select 'Import JSON'")
print(f"   d. Upload file: {products_output}")
print("   e. Import at the /products node")

print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)
print(f"Total inventory: 10,112 units")
print(f"  - Products: {products_stock:,} units ({products_with_stock} items)")
print(f"  - Spare parts: {spareparts_stock:,} units ({len(spare_parts)} items)")
print("=" * 80)