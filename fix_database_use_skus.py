import json
import requests

print("FIXING DATABASE TO USE ACTUAL SKUs AS KEYS...")

# Get current products from Firebase
response = requests.get("https://taquotes-default-rtdb.firebaseio.com/products.json")
current_products = response.json()

print(f"Current products count: {len(current_products)}")

# Restructure to use SKUs as keys
fixed_products = {}
skipped = 0
duplicates = []

for key, product in current_products.items():
    if product and isinstance(product, dict) and 'sku' in product:
        sku = product['sku']
        if sku:
            if sku in fixed_products:
                print(f"WARNING: Duplicate SKU found: {sku}")
                duplicates.append(sku)
            else:
                fixed_products[sku] = product
        else:
            print(f"WARNING: Product {key} has no SKU")
            skipped += 1
    else:
        print(f"WARNING: Invalid product at {key}")
        skipped += 1

print(f"\n=== RESULTS ===")
print(f"Original products: {len(current_products)}")
print(f"Fixed products: {len(fixed_products)}")
print(f"Skipped (no SKU): {skipped}")
print(f"Duplicates found: {len(duplicates)}")

if duplicates:
    print("\nDuplicate SKUs:")
    for sku in duplicates[:10]:
        print(f"  - {sku}")

# Save the fixed database
with open('DATABASE_WITH_SKU_KEYS.json', 'w') as f:
    json.dump(fixed_products, f, indent=2)

print(f"\n✅ Saved to DATABASE_WITH_SKU_KEYS.json")
print("\nThis database uses actual SKUs as keys instead of product_0000")
print("\nIMPORT THIS TO /products IN FIREBASE")