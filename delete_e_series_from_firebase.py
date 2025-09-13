import json
import subprocess
import time

print("=" * 60)
print("E SERIES PRODUCTS DELETION FROM FIREBASE")
print("=" * 60)

# First, let's identify all E series products
print("\n1. Reading local database to identify E series products...")
with open('FULL_PRODUCTS_RESTORED.json', 'r') as f:
    products = json.load(f)

e_series_ids = []
e_series_skus = []

for product_id, product in products.items():
    sku = product.get('sku', '') or product.get('model', '')
    if sku.upper().startswith('E'):
        e_series_ids.append(product_id)
        e_series_skus.append(sku)

print(f"\nFound {len(e_series_ids)} E series products to delete:")
for sku in sorted(e_series_skus):
    print(f"  - {sku}")

if len(e_series_ids) == 0:
    print("\nNo E series products found. Exiting.")
    exit()

# Confirm deletion
print("\n" + "=" * 60)
print("⚠️  WARNING: This will DELETE these products from Firebase!")
print("=" * 60)
response = input("\nAre you SURE you want to delete these E series products? (type 'yes' to confirm): ")

if response.lower() != 'yes':
    print("\nDeletion cancelled.")
    exit()

# Delete each product from Firebase
print("\n2. Deleting E series products from Firebase...")
deleted_count = 0
failed_count = 0

for product_id in e_series_ids:
    sku = products[product_id].get('sku', '') or products[product_id].get('model', '')
    print(f"\nDeleting {sku} (ID: {product_id})...", end="")
    
    # Use Firebase CLI to delete each product
    cmd = f'firebase database:remove "/products/{product_id}" --confirm'
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(" ✅ Deleted")
            deleted_count += 1
        else:
            print(f" ❌ Failed: {result.stderr}")
            failed_count += 1
    except Exception as e:
        print(f" ❌ Error: {e}")
        failed_count += 1
    
    # Small delay to avoid overwhelming Firebase
    time.sleep(0.5)

print("\n" + "=" * 60)
print("DELETION COMPLETE")
print("=" * 60)
print(f"✅ Successfully deleted: {deleted_count} products")
if failed_count > 0:
    print(f"❌ Failed to delete: {failed_count} products")

print("\nRemaining products in database: ~" + str(828 - deleted_count))
print("\n✨ E series products have been removed from Firebase!")