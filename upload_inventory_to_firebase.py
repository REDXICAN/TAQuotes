import json
import requests
from typing import Dict, Any

# Load the inventory data we extracted
with open('mexico_warehouse_inventory.json', 'r', encoding='utf-8') as f:
    inventory_data = json.load(f)

print("Loaded inventory data:")
print(f"- Total products: {inventory_data['total_products']}")
print(f"- Total warehouses: {inventory_data['total_warehouses']}")

# Prepare the update for Firebase
# We'll update each product with its warehouse stock information
products_update = {}

for sku, warehouses in inventory_data['inventory_by_product'].items():
    # Create warehouseStock object for this product
    warehouse_stock = {}
    for warehouse_code, quantity in warehouses.items():
        warehouse_stock[warehouse_code] = {
            'available': quantity,
            'reserved': quantity if warehouse_code == '999' else 0,
            'lastUpdate': {'$date': '2025-09-12T12:00:00.000Z'}
        }
    
    products_update[sku] = {
        'warehouseStock': warehouse_stock,
        'totalStock': sum(warehouses.values()),
        'availableStock': sum(q for w, q in warehouses.items() if w != '999')
    }

# Create a file with Firebase update commands
print("\nCreating Firebase update script...")

# Save as JSON for manual import or API usage
with open('firebase_inventory_update.json', 'w', encoding='utf-8') as f:
    json.dump(products_update, f, ensure_ascii=False, indent=2)

print(f"\nCreated firebase_inventory_update.json with {len(products_update)} products")
print("\nSample update for first 5 products:")
for i, (sku, data) in enumerate(list(products_update.items())[:5]):
    print(f"\n{sku}:")
    print(f"  Total Stock: {data['totalStock']}")
    print(f"  Available Stock: {data['availableStock']}")
    print(f"  Warehouses: {list(data['warehouseStock'].keys())}")

print("\n" + "="*80)
print("INSTRUCTIONS TO UPDATE FIREBASE:")
print("="*80)
print("""
Option 1: Update via Firebase Console
1. Go to https://console.firebase.google.com/project/taquotes/database
2. Navigate to the 'products' node
3. For each product that needs inventory, update its warehouseStock field

Option 2: Update via Firebase CLI (Recommended)
Run these commands to update specific products:
""")

# Generate sample update commands for first few products
for i, (sku, data) in enumerate(list(products_update.items())[:3]):
    warehouse_json = json.dumps(data['warehouseStock']).replace('"', '\\"')
    print(f'firebase database:update "/products/{sku}" \'{{ "warehouseStock": {json.dumps(data["warehouseStock"])} }}\'')
    if i >= 2:
        break

print("\nNote: The inventory data is ready in firebase_inventory_update.json")