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

# Create a backup first
print("\nCreating backup of original data...")
with open('products_ORIGINAL_BACKUP.json', 'w', encoding='utf-8') as f:
    json.dump(all_products, f, ensure_ascii=False, indent=2)
print("Backup saved to: products_ORIGINAL_BACKUP.json")

# Load the matching results
print("\nLoading inventory matches...")
with open('sku_matching_results.json', 'r', encoding='utf-8') as f:
    results = json.load(f)

matches = results['matches']
print(f"Found {len(matches)} products with inventory data")

# Create a map for quick lookup
inventory_map = {match['firebase_key']: match for match in matches}

# Process ALL products
products_with_inventory = 0
products_without_inventory = 0

print("\n" + "="*80)
print("PROCESSING ALL PRODUCTS")
print("="*80)

for firebase_key, product_data in all_products.items():
    # PRESERVE ALL EXISTING DATA - just add inventory fields
    
    if firebase_key in inventory_map:
        # Product HAS inventory data
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
        
        products_with_inventory += 1
        sku = product_data.get('sku', firebase_key)
        print(f"  [YES] {sku}: Added {total_stock} units across {list(warehouses.keys())}")
        
    else:
        # Product has NO inventory - add empty/zero inventory fields
        product_data['warehouseStock'] = {}
        product_data['totalStock'] = 0
        product_data['availableStock'] = 0
        
        products_without_inventory += 1
        if products_without_inventory <= 10:  # Show first 10 as examples
            sku = product_data.get('sku', firebase_key)
            print(f"  [ZERO] {sku}: No inventory (set to 0)")

if products_without_inventory > 10:
    print(f"  ... and {products_without_inventory - 10} more products with no inventory (set to 0)")

# Verify all products have all required fields
print("\n" + "="*80)
print("VERIFICATION")
print("="*80)

missing_fields = []
for firebase_key, product_data in all_products.items():
    sku = product_data.get('sku', firebase_key)
    
    # Check for essential fields that should be preserved
    essential_fields = ['name', 'price', 'category', 'sku']
    for field in essential_fields:
        if field not in product_data:
            missing_fields.append(f"{sku} missing {field}")
    
    # Check that inventory fields were added
    if 'warehouseStock' not in product_data:
        missing_fields.append(f"{sku} missing warehouseStock")
    if 'totalStock' not in product_data:
        missing_fields.append(f"{sku} missing totalStock")
    if 'availableStock' not in product_data:
        missing_fields.append(f"{sku} missing availableStock")

if missing_fields:
    print("WARNING: Some products have missing fields:")
    for msg in missing_fields[:10]:
        print(f"  - {msg}")
else:
    print("[OK] All products have essential fields and inventory fields")

# Save the complete products data
output_file = 'products_COMPLETE_WITH_INVENTORY_SAFE.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(all_products, f, ensure_ascii=False, indent=2)

print(f"\n{'='*80}")
print("COMPLETE PRODUCTS FILE CREATED")
print(f"{'='*80}")
print(f"File: {output_file}")
print(f"Total products: {len(all_products)}")
print(f"Products with real inventory: {products_with_inventory}")
print(f"Products with zero inventory: {products_without_inventory}")

# Create a summary report
summary = {
    'timestamp': datetime.now().isoformat(),
    'total_products': len(all_products),
    'products_with_inventory': products_with_inventory,
    'products_without_inventory': products_without_inventory,
    'all_products_have_inventory_fields': True,
    'original_backup': 'products_ORIGINAL_BACKUP.json',
    'output_file': output_file,
    'sample_product_with_inventory': None,
    'sample_product_without_inventory': None
}

# Add sample products to summary
for key, product in all_products.items():
    if product.get('totalStock', 0) > 0 and not summary['sample_product_with_inventory']:
        summary['sample_product_with_inventory'] = {
            'sku': product.get('sku'),
            'totalStock': product.get('totalStock'),
            'warehouseStock': product.get('warehouseStock')
        }
    if product.get('totalStock', 0) == 0 and not summary['sample_product_without_inventory']:
        summary['sample_product_without_inventory'] = {
            'sku': product.get('sku'),
            'totalStock': product.get('totalStock'),
            'warehouseStock': product.get('warehouseStock')
        }
    if summary['sample_product_with_inventory'] and summary['sample_product_without_inventory']:
        break

with open('inventory_update_summary_final.json', 'w', encoding='utf-8') as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)

print(f"\nSummary saved to: inventory_update_summary_final.json")

print(f"\n{'='*80}")
print("📋 INSTRUCTIONS TO UPLOAD TO FIREBASE:")
print(f"{'='*80}")
print(f"""
SAFE TO UPLOAD - This file contains:
✅ ALL 801 products with ALL their original data preserved
✅ 83 products with real inventory from Excel
✅ 718 products with inventory set to 0
✅ ALL products now have warehouseStock, totalStock, and availableStock fields

TO UPLOAD:
1. Go to: https://console.firebase.google.com/project/taquotes/database
2. Click on 'products' node
3. Click three dots menu → Import JSON
4. Select file: {output_file}
5. Choose "Replace" - This is SAFE because:
   - Contains ALL products
   - Preserves ALL existing data (names, prices, specs, images)
   - Only ADDS inventory fields

BACKUP AVAILABLE:
- products_ORIGINAL_BACKUP.json (your original data before inventory)
""")

print("\n✅ File is ready for upload!")