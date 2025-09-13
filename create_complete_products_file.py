import json
import pandas as pd
import re
from datetime import datetime

# File paths
original_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
stock_json = r"C:\Users\andre\Downloads\taquotes-products-with-stock-final.json"
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
output_file = r"C:\Users\andre\Downloads\taquotes-complete-products-with-stock.json"

print("=" * 80)
print("CREATING COMPLETE PRODUCTS FILE WITH ALL SKUS AND UPDATED STOCK")
print("=" * 80)

# Load original products (has all SKUs)
print("\n1. Loading original products from Firebase export...")
try:
    with open(original_json, 'r', encoding='utf-8') as f:
        all_products = json.load(f)
    print(f"   [OK] Loaded {len(all_products)} products")
except FileNotFoundError:
    print(f"   [X] Original file not found: {original_json}")
    print("   Using stock file as base instead...")
    original_json = stock_json
    with open(original_json, 'r', encoding='utf-8') as f:
        all_products = json.load(f)
    print(f"   [OK] Loaded {len(all_products)} products from stock file")

# Load products with stock (has 123 items with stock > 0)
print("\n2. Loading products with stock information...")
try:
    with open(stock_json, 'r', encoding='utf-8') as f:
        products_with_stock = json.load(f)
    print(f"   [OK] Loaded {len(products_with_stock)} products with stock")
except FileNotFoundError:
    print(f"   [X] Stock file not found: {stock_json}")
    products_with_stock = {}

# Count how many have stock in the stock file
stock_count = sum(1 for p in products_with_stock.values() if p.get('stock', 0) > 0)
print(f"   --> {stock_count} products have stock > 0")

# Load Excel to double-check stock data
print("\n3. Loading Excel inventory for verification...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract inventory from Excel
excel_inventory = {}
for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
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
            
            if stock_val > 0:
                normalized_sku = sku_str.upper().replace('-', '').replace(' ', '')
                excel_inventory[normalized_sku] = stock_val

print(f"   [OK] Found {len(excel_inventory)} items with stock > 0 in Excel")

# Function to normalize SKU for matching
def normalize_sku(sku):
    if not sku:
        return ""
    normalized = sku.upper()
    normalized = re.sub(r'[-()\s]', '', normalized)
    normalized = re.sub(r'(AL|AR)$', '', normalized)
    return normalized

# Merge stock information into all products
print("\n4. Merging stock information into all products...")
updated = 0
already_has_stock = 0
set_to_zero = 0

for key, product in all_products.items():
    product_sku = product.get('sku', '')
    
    # First check if this product already has stock in the stock file
    if key in products_with_stock and 'stock' in products_with_stock[key]:
        product['stock'] = products_with_stock[key]['stock']
        if product['stock'] > 0:
            already_has_stock += 1
        else:
            set_to_zero += 1
    else:
        # Try to match with Excel inventory
        if product_sku:
            normalized_product_sku = normalize_sku(product_sku)
            stock_found = False
            
            for excel_norm_sku, stock_val in excel_inventory.items():
                if (normalized_product_sku == excel_norm_sku or
                    excel_norm_sku in normalized_product_sku or
                    normalized_product_sku in excel_norm_sku):
                    
                    product['stock'] = stock_val
                    updated += 1
                    stock_found = True
                    break
            
            if not stock_found:
                product['stock'] = 0
                set_to_zero += 1
        else:
            product['stock'] = 0
            set_to_zero += 1

# Final statistics
total_with_stock = sum(1 for p in all_products.values() if p.get('stock', 0) > 0)
total_stock_units = sum(p.get('stock', 0) for p in all_products.values())

print(f"\n5. Final Statistics:")
print(f"   --> Total products: {len(all_products)}")
print(f"   --> Products with stock > 0: {total_with_stock}")
print(f"   --> Products with stock = 0: {len(all_products) - total_with_stock}")
print(f"   --> Total stock units: {total_stock_units}")
print(f"   --> Already had stock: {already_has_stock}")
print(f"   --> Newly updated: {updated}")
print(f"   --> Set to zero: {set_to_zero}")

# Save the complete file
print(f"\n6. Saving complete products file...")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(all_products, f, indent=2, ensure_ascii=False)

print(f"   [OK] Saved to: {output_file}")

# Show sample of products with stock
print("\n7. Sample of products with stock:")
count = 0
for key, product in all_products.items():
    if product.get('stock', 0) > 0 and count < 15:
        print(f"   {product.get('sku', 'N/A'):<25} Stock: {product.get('stock', 0):>4} units")
        count += 1

print("\n" + "=" * 80)
print("COMPLETE PRODUCTS FILE READY FOR UPLOAD")
print("=" * 80)
print(f"\nFile location: {output_file}")
print(f"Total products: {len(all_products)}")
print(f"Products with stock: {total_with_stock}")
print(f"Total inventory: {total_stock_units} units")
print("\nTo upload to Firebase:")
print("1. Go to https://console.firebase.google.com/project/taquotes/database")
print("2. Click on 'products' node")
print("3. Click the three dots (...) menu")
print("4. Select 'Import JSON'")
print(f"5. Upload file: {output_file}")
print("\n[!] IMPORTANT: Make sure to import at the /products node, NOT at root!")
print("=" * 80)