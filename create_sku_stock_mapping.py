import json
import subprocess

print("=" * 70)
print("CREATING PROPER SKU-BASED STOCK UPDATE")
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

# Load the VERIFIED database to get SKU mappings
print("\n2. Loading product mappings from backup...")
with open('VERIFIED_COMPLETE_DATABASE.json', 'r', encoding='utf-8') as f:
    backup_data = json.load(f)
backup_products = backup_data.get('products', {})

# Create mapping from product_id to SKU
id_to_sku_map = {}
for product_id, product_data in backup_products.items():
    sku = product_data.get('sku')
    if sku:
        id_to_sku_map[product_id] = sku

print(f"   Created mapping for {len(id_to_sku_map)} products")

# Load the stock data
print("\n3. Loading stock data...")
with open('firebase_console_stock_import.json', 'r', encoding='utf-8') as f:
    stock_data = json.load(f)

stock_products = stock_data.get('products', {})
print(f"   Found stock data for {len(stock_products)} products")

# Create the final products dict with current data
print("\n4. Adding stock data to products...")
products_with_stock = dict(current_products)  # Start with current products
updated_count = 0
not_found = []

for product_id, stock_fields in stock_products.items():
    # Get the SKU for this product_id
    sku = id_to_sku_map.get(product_id)

    if sku and sku in products_with_stock:
        # Add stock fields to this product
        products_with_stock[sku]['warehouseStock'] = stock_fields.get('warehouseStock', {})
        products_with_stock[sku]['totalStock'] = stock_fields.get('totalStock', 0)
        products_with_stock[sku]['availableStock'] = stock_fields.get('availableStock', 0)
        print(f"   Added stock to: {sku} (from {product_id})")
        updated_count += 1
    else:
        not_found.append((product_id, sku))

print(f"\nSuccessfully added stock data to {updated_count} products")
if not_found:
    print(f"Could not find {len(not_found)} products in current database:")
    for pid, sku in not_found[:5]:
        print(f"  - {pid} -> {sku or 'No SKU'}")

# Save the complete products data with SKU keys
output_file = 'products_sku_based_with_stock_FINAL.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products_with_stock, f, indent=2, ensure_ascii=False)

print("\n" + "=" * 70)
print("SUCCESS! Created: " + output_file)
print("=" * 70)

print(f"\nFile contains:")
print(f"  - ALL {len(products_with_stock)} products from your live database")
print(f"  - Stock data added to {updated_count} products")
print(f"  - Using SKU-based keys (matching your current structure)")

print("\nTO IMPORT:")
print("1. Go to Firebase Console > Realtime Database")
print("2. Click on the 'products' node")
print("3. Click the three dots menu (Import JSON)")
print(f"4. Select: {output_file}")

print("\nThis is SAFE because:")
print("  - It uses your current SKU-based key structure")
print("  - Contains ALL products from your live database")
print("  - Only adds 3 stock fields to products that have stock")
print("  - All other data remains unchanged")