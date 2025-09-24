import json
import requests
from datetime import datetime

# Read the inventory updates file
with open('firebase_inventory_updates.json', 'r', encoding='utf-8') as f:
    inventory_data = json.load(f)

print("=" * 70)
print("WAREHOUSE STOCK DATA UPLOAD PREPARATION")
print("=" * 70)

# Transform the data into proper Firebase format
# The inventory file has paths like "products/product_0049/warehouseStock"
# We need to group by product and create complete product updates

products_to_update = {}

for path, value in inventory_data.items():
    parts = path.split('/')
    if len(parts) >= 2 and parts[0] == 'products':
        product_id = parts[1]

        if product_id not in products_to_update:
            products_to_update[product_id] = {}

        # Extract the field name (last part of path)
        if len(parts) == 3:
            field_name = parts[2]
            products_to_update[product_id][field_name] = value

print(f"\nFound {len(products_to_update)} products with stock data")

# Show sample of products with stock
print("\nSample products with warehouse stock:")
count = 0
for product_id, data in list(products_to_update.items())[:5]:
    if 'warehouseStock' in data:
        print(f"\n{product_id}:")
        print(f"  Total Stock: {data.get('totalStock', 0)}")
        print(f"  Available Stock: {data.get('availableStock', 0)}")
        if 'warehouseStock' in data:
            print("  Warehouses:")
            for warehouse, stock in data['warehouseStock'].items():
                print(f"    {warehouse}: {stock['available']} available, {stock['reserved']} reserved")

# Create update file for Firebase
firebase_updates = {}
for product_id, updates in products_to_update.items():
    for field, value in updates.items():
        firebase_updates[f"products/{product_id}/{field}"] = value

# Save the updates file
output_file = 'firebase_warehouse_stock_updates.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(firebase_updates, f, indent=2, ensure_ascii=False)

print("\n" + "=" * 70)
print("UPLOAD INSTRUCTIONS")
print("=" * 70)

print(f"\n✅ Created update file: {output_file}")
print(f"   Contains {len(firebase_updates)} field updates for {len(products_to_update)} products")

print("\n📝 To upload this data to Firebase:")

print("\nOPTION 1 - Using Firebase CLI (RECOMMENDED):")
print("firebase database:update / firebase_warehouse_stock_updates.json")

print("\nOPTION 2 - Using curl:")
print('curl -X PATCH "https://taquotes-default-rtdb.firebaseio.com/.json" -d @firebase_warehouse_stock_updates.json')

print("\nOPTION 3 - Manual update via Firebase Console:")
print("1. Go to https://console.firebase.google.com/project/taquotes/database")
print("2. For each product, add the warehouseStock, totalStock, and availableStock fields")

print("\n⚠️ IMPORTANT:")
print("- This will UPDATE existing products with stock data")
print("- It will NOT overwrite other product fields")
print("- Make sure to backup your database before updating")

print("\n" + "=" * 70)