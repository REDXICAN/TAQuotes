import pandas as pd
import json
import random

# File paths
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
database_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-export.json"
output_file = r"C:\Users\andre\Downloads\taquotes-complete-database-with-stock.json"

print("=" * 80)
print("CREATING COMPLETE DATABASE WITH STOCK AND SPARE PARTS")
print("=" * 80)

# Load existing complete database
print("\n1. Loading existing Firebase database...")
try:
    with open(database_json, 'r', encoding='utf-8') as f:
        database = json.load(f)
    print(f"   Loaded database with {len(database)} top-level sections")
    for key in database.keys():
        if isinstance(database[key], dict):
            print(f"   - {key}: {len(database[key])} items")
        else:
            print(f"   - {key}: (value)")
except FileNotFoundError:
    print(f"   ERROR: Database file not found: {database_json}")
    print("   Creating new database structure...")
    database = {}

# Ensure products section exists
if 'products' not in database:
    print("   WARNING: No products section found, loading from products export...")
    products_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
    try:
        with open(products_file, 'r', encoding='utf-8') as f:
            database['products'] = json.load(f)
        print(f"   Loaded {len(database['products'])} products")
    except:
        print("   ERROR: Could not load products")
        database['products'] = {}

# Load Excel inventory data
print("\n2. Loading Excel inventory data...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

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

print(f"   Found {len(excel_inventory)} items with {total_stock:,} total units")

# Update products with stock and identify spare parts
print("\n3. Updating products with stock and identifying spare parts...")

products = database.get('products', {})
spare_parts = {}
matched_count = 0
matched_stock = 0
spareparts_stock = 0

# First, reset all product stock to 0 (but preserve all other fields)
for product_key, product in products.items():
    if isinstance(product, dict):
        product['stock'] = 0
        product['warehouse'] = None

# Match Excel items with products
for excel_sku, excel_data in excel_inventory.items():
    matched = False
    
    # Try to match with existing products
    for product_key, product in products.items():
        if isinstance(product, dict):
            product_sku = product.get('sku', '')
            model = product.get('model', '')
            
            if product_sku or model:
                product_norm = product_sku.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
                model_norm = model.upper().replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
                
                if (product_norm == excel_data['normalized'] or
                    model_norm == excel_data['normalized'] or
                    (len(excel_data['normalized']) > 4 and excel_data['normalized'] in product_norm) or
                    (len(product_norm) > 4 and product_norm in excel_data['normalized'])):
                    
                    # Update product with stock
                    product['stock'] = excel_data['stock']
                    matched_count += 1
                    matched_stock += excel_data['stock']
                    matched = True
                    break
    
    if not matched:
        # It's a spare part - add to spare parts
        spare_parts[excel_sku] = {
            'sku': excel_sku,
            'name': excel_data['name'],
            'stock': excel_data['stock'],
            'warehouse': None
        }
        spareparts_stock += excel_data['stock']

print(f"   Matched {matched_count} products with {matched_stock:,} units")
print(f"   Found {len(spare_parts)} spare parts with {spareparts_stock:,} units")

# Assign warehouses
print("\n4. Assigning warehouse locations...")
warehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'MEE', 'PU', 'SI', 'XCA', 'XPU']

# Assign to products
products_with_stock = 0
for product_key, product in products.items():
    if isinstance(product, dict):
        stock = product.get('stock', 0)
        if stock > 0:
            products_with_stock += 1
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

# Assign to spare parts
for sku, part in spare_parts.items():
    stock = part['stock']
    if stock >= 100:
        part['warehouse'] = 'CA'
    elif stock >= 50:
        part['warehouse'] = random.choice(['CA', 'PU', 'MEE'])
    elif stock >= 20:
        part['warehouse'] = random.choice(['CA', 'CA2', 'PU', 'SI'])
    elif stock >= 10:
        part['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', 'PU', 'SI'])
    elif stock >= 5:
        part['warehouse'] = random.choice(['CA1', 'CA2', 'CA3', 'CA4', '999'])
    else:
        part['warehouse'] = random.choice(warehouses)

# Add spare parts section to database
print("\n5. Adding spare parts section to database...")
database['spareparts'] = spare_parts

# Update products in database
database['products'] = products

# Show statistics
print("\n" + "=" * 80)
print("DATABASE STATISTICS")
print("=" * 80)

print("\nTop-level sections in database:")
for key in database.keys():
    if isinstance(database[key], dict):
        print(f"  - {key}: {len(database[key])} items")
    else:
        print(f"  - {key}: (value/config)")

print(f"\nProducts section:")
print(f"  Total products: {len(products)}")
print(f"  Products with stock: {products_with_stock}")
print(f"  Total product units: {matched_stock:,}")

print(f"\nSpare parts section:")
print(f"  Total spare parts: {len(spare_parts)}")
print(f"  Total spare part units: {spareparts_stock:,}")

print(f"\nOverall inventory:")
print(f"  Total items with stock: {products_with_stock + len(spare_parts)}")
print(f"  Total units: {matched_stock + spareparts_stock:,}")

# Show sample products with stock
print("\nSample products with stock:")
count = 0
for key, product in products.items():
    if isinstance(product, dict) and product.get('stock', 0) > 0 and count < 10:
        sku = product.get('sku', product.get('model', key))
        print(f"  {sku:25} Stock: {product.get('stock'):4} -> {product.get('warehouse', 'N/A')}")
        count += 1

# Show sample spare parts
print("\nSample spare parts:")
sorted_parts = sorted(spare_parts.items(), key=lambda x: x[1]['stock'], reverse=True)
for i, (sku, part) in enumerate(sorted_parts[:10]):
    print(f"  {sku:25} Stock: {part['stock']:4} -> {part['warehouse']} - {part['name'][:30]}")

# Save complete database
print("\n6. Saving complete database...")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(database, f, indent=2, ensure_ascii=False)

print(f"\nFile saved to: {output_file}")

print("\n" + "=" * 80)
print("FIREBASE UPLOAD INSTRUCTIONS")
print("=" * 80)
print("\n⚠️ CRITICAL: This will replace your ENTIRE database!")
print("\n1. BACKUP FIRST:")
print("   firebase database:get '/' > backup_before_import.json")
print("\n2. IMPORT COMPLETE DATABASE:")
print("   a. Go to https://console.firebase.google.com/project/taquotes/database")
print("   b. Click on the ROOT node (the very top)")
print("   c. Click the three dots (...) menu")
print("   d. Select 'Import JSON'")
print(f"   e. Upload file: {output_file}")
print("   f. Confirm the import")
print("\n⚠️ WARNING: This will replace ALL data including users, clients, quotes, etc.")
print("⚠️ Make sure you have a backup before importing!")
print("\nAlternatively, you can import just the spareparts section:")
print("1. In Firebase console, add a new child node called 'spareparts'")
print("2. Import only the spareparts data to that node")
print("=" * 80)