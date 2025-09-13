import json
import requests
import time
from datetime import datetime

# Firebase database URL
FIREBASE_URL = "https://taquotes-default-rtdb.firebaseio.com"

# Load the inventory data we extracted
print("Loading inventory data...")
with open('mexico_warehouse_inventory.json', 'r', encoding='utf-8') as f:
    inventory_data = json.load(f)

print(f"Loaded {len(inventory_data['inventory_by_product'])} products with inventory")

# First, get all existing products from Firebase
print("\nFetching existing products from Firebase...")
response = requests.get(f"{FIREBASE_URL}/products.json")
if response.status_code != 200:
    print(f"Error fetching products: {response.status_code}")
    print(response.text)
    exit(1)

existing_products = response.json() or {}
print(f"Found {len(existing_products)} products in Firebase")

# Create a mapping of SKU to Firebase product key
print("\nBuilding SKU to Firebase key mapping...")
sku_to_firebase_key = {}
firebase_skus = []

for firebase_key, product_data in existing_products.items():
    if product_data and isinstance(product_data, dict) and 'sku' in product_data:
        sku = product_data['sku']
        sku_to_firebase_key[sku] = firebase_key
        firebase_skus.append(sku)

print(f"Found {len(sku_to_firebase_key)} products with SKUs in Firebase")

# Now update products that exist in both Firebase and inventory
updates_count = 0
updated_products = []
products_with_no_match = []
matched_but_no_inventory = []

print("\n" + "="*80)
print("UPDATING PRODUCTS WITH INVENTORY DATA")
print("="*80)

for sku, warehouses in inventory_data['inventory_by_product'].items():
    # Check if we have a Firebase key for this SKU
    if sku in sku_to_firebase_key:
        firebase_key = sku_to_firebase_key[sku]
        
        # Prepare warehouse stock data
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
        
        # Update the product with inventory data
        update_data = {
            'warehouseStock': warehouse_stock,
            'totalStock': total_stock,
            'availableStock': available_stock
        }
        
        print(f"Updating {sku} ({firebase_key}): {total_stock} total ({available_stock} available) in {len(warehouses)} warehouses")
        
        # Send update to Firebase
        update_response = requests.patch(
            f"{FIREBASE_URL}/products/{firebase_key}.json",
            json=update_data
        )
        
        if update_response.status_code == 200:
            updates_count += 1
            updated_products.append({
                'sku': sku,
                'firebase_key': firebase_key,
                'total_stock': total_stock,
                'warehouses': list(warehouses.keys())
            })
            print(f"  ✓ Updated successfully")
        else:
            print(f"  ✗ Failed to update: {update_response.status_code}")
            print(f"    Response: {update_response.text[:200]}")
        
        # Rate limiting
        if updates_count % 10 == 0:
            time.sleep(0.5)  # Small delay every 10 updates
            print(f"\nProgress: {updates_count} products updated...")
    else:
        products_with_no_match.append(sku)

# Check for Firebase products that don't have inventory data
for firebase_sku in firebase_skus:
    if firebase_sku not in inventory_data['inventory_by_product']:
        matched_but_no_inventory.append(firebase_sku)

print("\n" + "="*80)
print("UPDATE COMPLETE")
print("="*80)
print(f"Successfully updated: {updates_count} products")
print(f"Products with inventory but no match in Firebase: {len(products_with_no_match)}")
print(f"Products in Firebase but no inventory data: {len(matched_but_no_inventory)}")

if updated_products:
    print(f"\nFirst 20 updated products:")
    for product in updated_products[:20]:
        print(f"  - {product['sku']}: {product['total_stock']} units in {product['warehouses']}")

if products_with_no_match:
    print(f"\nFirst 20 products with inventory but not in Firebase:")
    for sku in products_with_no_match[:20]:
        total = sum(inventory_data['inventory_by_product'][sku].values())
        print(f"  - {sku}: {total} units")

if matched_but_no_inventory[:20]:
    print(f"\nFirst 20 Firebase products without inventory:")
    for sku in matched_but_no_inventory[:20]:
        print(f"  - {sku}")

# Save detailed update log
with open('inventory_update_detailed_log.json', 'w', encoding='utf-8') as f:
    json.dump({
        'timestamp': datetime.now().isoformat(),
        'updated_count': updates_count,
        'updated_products': updated_products,
        'unmatched_inventory': products_with_no_match,
        'firebase_without_inventory': matched_but_no_inventory,
        'summary': {
            'total_inventory_products': len(inventory_data['inventory_by_product']),
            'total_firebase_products': len(existing_products),
            'products_with_skus': len(sku_to_firebase_key),
            'successfully_updated': updates_count
        }
    }, f, ensure_ascii=False, indent=2)

print(f"\nDetailed log saved to inventory_update_detailed_log.json")