import json
import subprocess

# Get current products
result = subprocess.run(['firebase', 'database:get', '/products'], capture_output=True, text=True, shell=True)
current_products = json.loads(result.stdout)

# Get list of current SKUs
current_skus = list(current_products.keys())
print(f"Current database has {len(current_skus)} products")
print(f"First 10 SKUs in current database:")
for sku in current_skus[:10]:
    print(f"  - {sku}")

# Load the stock data to see what SKUs it has
with open('firebase_inventory_updates.json', 'r', encoding='utf-8') as f:
    inventory_data = json.load(f)

# Extract unique product IDs from the inventory data
stock_product_ids = set()
for path in inventory_data.keys():
    parts = path.split('/')
    if len(parts) >= 2 and parts[0] == 'products':
        stock_product_ids.add(parts[1])

print(f"\nStock data contains {len(stock_product_ids)} products")
print("First 10 product IDs in stock data:")
for pid in list(stock_product_ids)[:10]:
    print(f"  - {pid}")

# Load backup to get SKU mappings
with open('VERIFIED_COMPLETE_DATABASE.json', 'r', encoding='utf-8') as f:
    backup = json.load(f)

# Map product IDs to SKUs
print("\nMapping product IDs to SKUs from backup:")
matched = 0
unmatched = 0
for pid in stock_product_ids:
    if pid in backup.get('products', {}):
        sku = backup['products'][pid].get('sku', 'No SKU')
        if sku in current_skus:
            print(f"  [FOUND] {pid} -> {sku} (EXISTS in current DB)")
            matched += 1
        else:
            print(f"  [MISSING] {pid} -> {sku} (NOT in current DB)")
            unmatched += 1

print(f"\nResults:")
print(f"  - {matched} products found in current database")
print(f"  - {unmatched} products NOT found in current database")

if unmatched > 0:
    print("\nWARNING: The SKUs in the stock data don't match the current database!")
    print("This might be because:")
    print("1. The backup file is from a different database version")
    print("2. Products were renamed or SKUs were changed")
    print("3. The current database uses different SKU format")