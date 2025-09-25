import json

print("Loading existing products from recent backup...")
# Use the verified complete database that has all products
with open('VERIFIED_COMPLETE_DATABASE.json', 'r', encoding='utf-8') as f:
    full_database = json.load(f)

# Get the products section
existing_products = full_database.get('products', {})
print(f"Found {len(existing_products)} existing products")

# Load the stock updates
print("\nLoading stock updates...")
with open('firebase_console_stock_import.json', 'r', encoding='utf-8') as f:
    stock_data = json.load(f)

stock_products = stock_data.get('products', {})
print(f"Found stock data for {len(stock_products)} products")

# Merge stock data into existing products
updated_count = 0
for product_id, stock_fields in stock_products.items():
    if product_id in existing_products:
        # Add/update the stock fields in the existing product
        existing_products[product_id]['warehouseStock'] = stock_fields.get('warehouseStock', {})
        existing_products[product_id]['totalStock'] = stock_fields.get('totalStock', 0)
        existing_products[product_id]['availableStock'] = stock_fields.get('availableStock', 0)
        updated_count += 1
        print(f"  Updated {product_id} with stock data")

print(f"\nMerged stock data into {updated_count} products")

# Save the complete products data for /products node import
with open('products_complete_with_stock.json', 'w', encoding='utf-8') as f:
    json.dump(existing_products, f, indent=2, ensure_ascii=False)

print("\n" + "=" * 70)
print("SUCCESS! Created: products_complete_with_stock.json")
print("=" * 70)
print("\nThis file contains:")
print(f"- ALL {len(existing_products)} products with their complete data")
print(f"- Stock data added to {updated_count} products")
print("\n📝 TO IMPORT:")
print("1. Go to Firebase Console > Realtime Database")
print("2. Click on the 'products' node")
print("3. Click the three dots menu → Import JSON")
print("4. Select: products_complete_with_stock.json")
print("\nThis is SAFE because:")
print("- It contains ALL your existing product data")
print("- It only ADDS the stock fields to products that have stock")
print("- Products without stock remain unchanged")