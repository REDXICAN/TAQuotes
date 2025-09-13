import json

# Read the database file
with open('FULL_PRODUCTS_RESTORED.json', 'r') as f:
    products = json.load(f)

# Count E series SKUs
e_series_skus = []
total_count = 0
all_skus = []

for key, product in products.items():
    sku = product.get('sku', '') or product.get('model', '')
    all_skus.append(sku)
    if sku.upper().startswith('E'):
        e_series_skus.append(sku)
        total_count += 1

# Sort the SKUs
e_series_skus.sort()
all_skus.sort()

print(f"Total products in database: {len(products)}")
print(f"Total E series products: {total_count}")

if total_count > 0:
    print(f"\nE series SKUs found:")
    for sku in e_series_skus:
        print(f"  - {sku}")

    # Group by E series type (first 3-4 characters)
    e_series_groups = {}
    for sku in e_series_skus:
        # Get the first part before any dash or number
        prefix = sku.split('-')[0] if '-' in sku else sku[:3]
        if prefix not in e_series_groups:
            e_series_groups[prefix] = []
        e_series_groups[prefix].append(sku)

    print(f"\n\nE series grouped by type:")
    for prefix, skus in sorted(e_series_groups.items()):
        print(f"\n{prefix}: {len(skus)} products")
        for sku in skus[:5]:  # Show first 5 of each group
            print(f"  - {sku}")
        if len(skus) > 5:
            print(f"  ... and {len(skus) - 5} more")
else:
    print("\nNo E series products found in the database.")
    print("\nShowing first 30 SKUs in database to verify:")
    for sku in all_skus[:30]:
        print(f"  - {sku}")