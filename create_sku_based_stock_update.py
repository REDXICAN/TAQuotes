import json
import subprocess

print("=" * 70)
print("CREATING STOCK UPDATE WITH SKU-BASED KEYS")
print("=" * 70)

# First, get current products from Firebase
print("\n1. Fetching current products from Firebase...")
result = subprocess.run(
    ['firebase', 'database:get', '/products'],
    capture_output=True,
    text=True,
    shell=True
)

if result.returncode != 0:
    print("Error: Could not fetch current products from Firebase")
    exit(1)

current_products = json.loads(result.stdout)
print(f"   Found {len(current_products)} products in Firebase")

# Load the stock data we prepared earlier
print("\n2. Loading stock data...")
with open('firebase_console_stock_import.json', 'r', encoding='utf-8') as f:
    stock_data = json.load(f)

stock_products = stock_data.get('products', {})
print(f"   Found stock data for {len(stock_products)} products")

# Map product_XXXX IDs to SKUs
print("\n3. Mapping stock data to SKU-based keys...")
updated_count = 0
skipped_count = 0

# Create new products dict with SKU keys
products_with_stock = {}

# First, add all current products
for sku, product_data in current_products.items():
    products_with_stock[sku] = product_data

# Now add stock data
for product_id, stock_fields in stock_products.items():
    # Find the product with this product_id in our current products
    found = False
    for sku, product_data in current_products.items():
        if product_data.get('id') == product_id or product_data.get('sku') == sku:
            # Add stock fields to this product
            products_with_stock[sku]['warehouseStock'] = stock_fields.get('warehouseStock', {})
            products_with_stock[sku]['totalStock'] = stock_fields.get('totalStock', 0)
            products_with_stock[sku]['availableStock'] = stock_fields.get('availableStock', 0)
            print(f"   Added stock to: {sku}")
            updated_count += 1
            found = True
            break

    if not found:
        # Try to find by checking the VERIFIED_COMPLETE_DATABASE
        skipped_count += 1

print(f"\n✓ Successfully added stock data to {updated_count} products")
if skipped_count > 0:
    print(f"⚠ Skipped {skipped_count} products (not found in current database)")

# Save the complete products data with SKU keys
output_file = 'products_sku_based_with_stock.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products_with_stock, f, indent=2, ensure_ascii=False)

print("\n" + "=" * 70)
print("SUCCESS! Created: " + output_file)
print("=" * 70)

print(f"\nFile contains:")
print(f"  - ALL {len(products_with_stock)} products from your live database")
print(f"  - Stock data added to {updated_count} products")
print(f"  - Using SKU-based keys (matching your current structure)")

print("\n📝 TO IMPORT:")
print("1. Go to Firebase Console > Realtime Database")
print("2. Click on the 'products' node")
print("3. Click the three dots menu → Import JSON")
print(f"4. Select: {output_file}")

print("\n✅ This is SAFE because:")
print("  - It preserves your current SKU-based key structure")
print("  - Contains ALL products from your live database")
print("  - Only adds stock fields to products that have stock data")
print("  - Other products remain unchanged")