import json

# Read the path-based updates file
with open('firebase_warehouse_stock_updates.json', 'r', encoding='utf-8') as f:
    path_updates = json.load(f)

# Convert to nested structure for Firebase Console
products = {}

for path, value in path_updates.items():
    parts = path.split('/')

    if len(parts) >= 2 and parts[0] == 'products':
        product_id = parts[1]

        if product_id not in products:
            products[product_id] = {}

        if len(parts) == 3:
            # Direct field like warehouseStock, totalStock, availableStock
            field_name = parts[2]
            products[product_id][field_name] = value

# Create the final structure for console import
console_format = {
    "products": products
}

# Save for console import
with open('firebase_console_stock_import.json', 'w', encoding='utf-8') as f:
    json.dump(console_format, f, indent=2, ensure_ascii=False)

print("Created firebase_console_stock_import.json for Firebase Console import")
print(f"This will update {len(products)} products with stock data")
print("\nInstructions:")
print("1. Go to Firebase Console > Realtime Database")
print("2. Click on the root node '/'")
print("3. Click the three dots menu → Import JSON")
print("4. Select firebase_console_stock_import.json")
print("5. This will merge the stock data into your existing products")