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

# First, let's get all existing products from Firebase
print("\nFetching existing products from Firebase...")
response = requests.get(f"{FIREBASE_URL}/products.json")
if response.status_code != 200:
    print(f"Error fetching products: {response.status_code}")
    print(response.text)
    exit(1)

existing_products = response.json() or {}
print(f"Found {len(existing_products)} products in Firebase")

# Prepare updates for products that exist in both Firebase and inventory
updates_count = 0
updated_products = []
products_with_no_match = []

for sku, warehouses in inventory_data['inventory_by_product'].items():
    if sku in existing_products:
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
        
        print(f"Updating {sku}: {total_stock} total ({available_stock} available) across {len(warehouses)} warehouses")
        
        # Send update to Firebase
        update_response = requests.patch(
            f"{FIREBASE_URL}/products/{sku}.json",
            json=update_data
        )
        
        if update_response.status_code == 200:
            updates_count += 1
            updated_products.append(sku)
            print(f"  ✓ Updated successfully")
        else:
            print(f"  ✗ Failed to update: {update_response.status_code}")
        
        # Rate limiting
        if updates_count % 10 == 0:
            time.sleep(0.5)  # Small delay every 10 updates
    else:
        products_with_no_match.append(sku)

print("\n" + "="*80)
print("UPDATE COMPLETE")
print("="*80)
print(f"Successfully updated: {updates_count} products")
print(f"Products with inventory but not in Firebase: {len(products_with_no_match)}")

if updated_products:
    print("\nFirst 20 updated products:")
    for sku in updated_products[:20]:
        print(f"  - {sku}")

if products_with_no_match:
    print(f"\nFirst 20 products with no match in Firebase:")
    for sku in products_with_no_match[:20]:
        print(f"  - {sku}")
    
    # Save unmatched products for reference
    with open('products_not_in_firebase.json', 'w', encoding='utf-8') as f:
        json.dump({
            'skus': products_with_no_match,
            'count': len(products_with_no_match),
            'inventory_data': {sku: inventory_data['inventory_by_product'][sku] for sku in products_with_no_match}
        }, f, ensure_ascii=False, indent=2)
    print(f"\nUnmatched products saved to products_not_in_firebase.json")

# Save update log
with open('inventory_update_log.json', 'w', encoding='utf-8') as f:
    json.dump({
        'timestamp': datetime.now().isoformat(),
        'updated_count': updates_count,
        'updated_products': updated_products,
        'unmatched_products': products_with_no_match
    }, f, ensure_ascii=False, indent=2)

print(f"\nUpdate log saved to inventory_update_log.json")