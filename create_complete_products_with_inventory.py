import json
import requests
from datetime import datetime

# Firebase database URL
FIREBASE_URL = "https://taquotes-default-rtdb.firebaseio.com"

print("Fetching all existing products from Firebase...")
response = requests.get(f"{FIREBASE_URL}/products.json")
if response.status_code != 200:
    print(f"Error fetching products: {response.status_code}")
    exit(1)

all_products = response.json() or {}
print(f"Downloaded {len(all_products)} products from Firebase")

# Load the matching results
print("\nLoading inventory matches...")
with open('sku_matching_results.json', 'r', encoding='utf-8') as f:
    results = json.load(f)

matches = results['matches']
print(f"Found {len(matches)} products with inventory data")

# Create a map for quick lookup
inventory_map = {match['firebase_key']: match for match in matches}

# Update products with inventory data
updated_count = 0
for firebase_key, product_data in all_products.items():
    if firebase_key in inventory_map:
        match = inventory_map[firebase_key]
        warehouses = match['warehouses']
        
        # Calculate totals
        warehouse_stock = {}
        total_stock = 0
        available_stock = 0
        
        for warehouse_code, quantity in warehouses.items():
            is_reserved = (warehouse_code == '999')
            warehouse_stock[warehouse_code] = {
                'available': quantity,
                'reserved': quantity if is_reserved else 0,
                'lastUpdate': datetime.now().isoformat()
            }
            total_stock += quantity
            if not is_reserved:
                available_stock += quantity
        
        # Add inventory data to the product
        product_data['warehouseStock'] = warehouse_stock
        product_data['totalStock'] = total_stock
        product_data['availableStock'] = available_stock
        
        updated_count += 1
        print(f"Added inventory to {product_data.get('sku', firebase_key)}: {total_stock} units across {list(warehouses.keys())}")

# Save the complete products data
output_file = 'products_complete_with_inventory.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(all_products, f, ensure_ascii=False, indent=2)

print(f"\n{'='*80}")
print("COMPLETE PRODUCTS FILE CREATED")
print(f"{'='*80}")
print(f"File: {output_file}")
print(f"Total products: {len(all_products)}")
print(f"Products with inventory: {updated_count}")
print(f"Products without inventory: {len(all_products) - updated_count}")

print(f"\n{'='*80}")
print("HOW TO UPLOAD TO FIREBASE:")
print(f"{'='*80}")
print("""
⚠️ IMPORTANT: This file contains ALL products with complete data!

TO UPLOAD SAFELY:
1. Go to Firebase Console: https://console.firebase.google.com/project/taquotes/database
2. Navigate to the 'products' node
3. Click the three dots menu (⋮) on the 'products' node
4. Select "Import JSON"
5. Choose the file: products_complete_with_inventory.json
6. Select "Replace" (this is safe because it contains ALL existing data PLUS inventory)

WHAT THIS WILL DO:
✅ Keep all existing product data (names, prices, specs, images)
✅ Add inventory data to 83 products
✅ Maintain all other products unchanged
❌ Will NOT affect other nodes (clients, quotes, users)

The file contains:
- All {len_all} products from Firebase
- {updated} products now have warehouseStock, totalStock, and availableStock
- {unchanged} products remain exactly as they were
""".format(len_all=len(all_products), updated=updated_count, unchanged=len(all_products)-updated_count))

# Create a backup of original products without inventory
with open('products_backup_before_inventory.json', 'w', encoding='utf-8') as f:
    # Remove inventory fields for backup
    backup_products = {}
    for key, product in all_products.items():
        backup_product = product.copy()
        backup_product.pop('warehouseStock', None)
        backup_product.pop('totalStock', None)
        backup_product.pop('availableStock', None)
        backup_products[key] = backup_product
    json.dump(backup_products, f, ensure_ascii=False, indent=2)

print(f"\nAlso created backup: products_backup_before_inventory.json")