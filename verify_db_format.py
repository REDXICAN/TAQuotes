import subprocess
import json

print("=" * 70)
print("VERIFYING CURRENT DATABASE FORMAT")
print("=" * 70)

# Get current products from Firebase
result = subprocess.run(
    ['firebase', 'database:get', '/products'],
    capture_output=True,
    text=True,
    shell=True
)

if result.returncode != 0 or not result.stdout:
    print("Error fetching from Firebase")
    exit(1)

products = json.loads(result.stdout)
keys = list(products.keys())

print(f"\nTotal products in database: {len(products)}")
print(f"\nFirst 20 product keys:")
for key in keys[:20]:
    print(f"  - {key}")

# Check format
if keys[0].startswith('product_'):
    print("\n❌ ERROR: Database is using product_XXXX format!")
    print("This needs to be fixed to use SKU format.")
else:
    print("\n✓ Database is using SKU format (correct)")

# Check if any product has 'id' field with product_XXXX
sample_product = products[keys[0]]
if 'id' in sample_product:
    print(f"\nSample product has 'id' field: {sample_product['id']}")

print("\n" + "=" * 70)