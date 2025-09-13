import json

print("=" * 60)
print("E SERIES DELETION - MANUAL METHOD")
print("=" * 60)

# Read the database
with open('FULL_PRODUCTS_RESTORED.json', 'r') as f:
    products = json.load(f)

# Find E series products
e_series_to_delete = {}
for product_id, product in products.items():
    sku = product.get('sku', '') or product.get('model', '')
    if sku.upper().startswith('E'):
        e_series_to_delete[product_id] = sku

print(f"\nFound {len(e_series_to_delete)} E series products to delete:")
for product_id, sku in sorted(e_series_to_delete.items(), key=lambda x: x[1]):
    print(f"  {sku} (ID: {product_id})")

print("\n" + "=" * 60)
print("OPTION 1: Delete via Firebase Console (Recommended)")
print("=" * 60)
print("1. Go to: https://console.firebase.google.com/project/taquotes/database/taquotes-default-rtdb/data")
print("2. Navigate to the 'products' node")
print("3. Search or scroll to find each product ID listed above")
print("4. Click the X button next to each product to delete it")

print("\n" + "=" * 60)
print("OPTION 2: Delete via Firebase CLI Commands")
print("=" * 60)
print("Run these commands one by one:\n")

for product_id, sku in sorted(e_series_to_delete.items(), key=lambda x: x[1]):
    print(f'firebase database:remove "/products/{product_id}" -y')

print("\n" + "=" * 60)
print("OPTION 3: Create a new database without E series")
print("=" * 60)

# Create a cleaned database
cleaned_products = {}
for product_id, product in products.items():
    sku = product.get('sku', '') or product.get('model', '')
    if not sku.upper().startswith('E'):
        cleaned_products[product_id] = product

print(f"Creating cleaned database file with {len(cleaned_products)} products (excluding E series)...")

with open('products_without_e_series.json', 'w') as f:
    json.dump(cleaned_products, f, indent=2)

print("\n✅ Created 'products_without_e_series.json'")
print("\nTo replace all products with this cleaned version:")
print("1. Go to Firebase Console")
print("2. Navigate to the 'products' node")
print("3. Click the three dots menu and select 'Import JSON'")
print("4. Upload 'products_without_e_series.json'")
print("5. ⚠️  WARNING: This will REPLACE ALL products, removing E series")

print("\n" + "=" * 60)
print(f"Summary: {len(e_series_to_delete)} E series products will be removed")
print(f"Remaining products: {len(cleaned_products)}")
print("=" * 60)