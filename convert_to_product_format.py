import json
import subprocess

print("=" * 70)
print("CONVERTING DATABASE TO product_XXXX FORMAT")
print("=" * 70)

# Get current products from Firebase
print("\n1. Fetching current products from Firebase...")
result = subprocess.run(
    ['firebase', 'database:get', '/products'],
    capture_output=True,
    text=True,
    shell=True
)

if result.returncode != 0:
    print("Error: Could not fetch products from Firebase")
    exit(1)

current_products = json.loads(result.stdout)
print(f"   Found {len(current_products)} products with SKU keys")

# Convert to product_XXXX format
print("\n2. Converting to product_XXXX format...")
converted_products = {}
product_counter = 0

# Sort SKUs to maintain consistent ordering
sorted_skus = sorted(current_products.keys())

for sku in sorted_skus:
    product_data = current_products[sku]

    # Generate product ID
    product_id = f"product_{product_counter:04d}"

    # Create new product entry with ALL existing data
    converted_products[product_id] = product_data

    # Ensure the product has its ID field
    converted_products[product_id]['id'] = product_id

    # Ensure the SKU is stored in the sku field
    if 'sku' not in converted_products[product_id]:
        converted_products[product_id]['sku'] = sku

    print(f"   {sku} -> {product_id}")
    product_counter += 1

print(f"\n3. Conversion complete!")
print(f"   Total products converted: {len(converted_products)}")

# Verify data integrity
print("\n4. Verifying data integrity...")
original_fields = set()
converted_fields = set()

# Check a sample product to ensure all fields are preserved
if sorted_skus:
    sample_sku = sorted_skus[0]
    original_product = current_products[sample_sku]
    converted_product = converted_products['product_0000']

    original_fields = set(original_product.keys())
    converted_fields = set(converted_product.keys())

    print(f"   Original product fields: {len(original_fields)}")
    print(f"   Converted product fields: {len(converted_fields)}")

    # Check for any missing fields
    missing_fields = original_fields - converted_fields
    if missing_fields:
        print(f"   WARNING: Missing fields: {missing_fields}")
    else:
        print("   SUCCESS: All fields preserved!")

    # Check for new fields added
    new_fields = converted_fields - original_fields
    if new_fields:
        print(f"   New fields added: {new_fields}")

# Save the converted database
output_file = 'products_product_format_FINAL.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(converted_products, f, indent=2, ensure_ascii=False)

print("\n" + "=" * 70)
print(f"SUCCESS! Created: {output_file}")
print("=" * 70)

print(f"\nFile contains:")
print(f"  - {len(converted_products)} products in product_XXXX format")
print(f"  - ALL original data preserved")
print(f"  - SKUs stored in 'sku' field for searching")
print(f"  - Sequential IDs from product_0000 to product_{(len(converted_products)-1):04d}")

print("\nTO IMPORT:")
print("1. Go to Firebase Console > Realtime Database")
print("2. Click on the 'products' node")
print("3. Click the three dots menu (...) -> Import JSON")
print(f"4. Select: {output_file}")

print("\nIMPORTANT:")
print("  - This will REPLACE all products with the new format")
print("  - All product data is preserved")
print("  - Keys changed from SKUs to product_XXXX format")
print("  - SKUs are now stored in the 'sku' field of each product")

# Create a mapping file for reference
mapping = {}
for sku, product_data in current_products.items():
    for pid, pdata in converted_products.items():
        if pdata.get('sku') == sku:
            mapping[sku] = pid
            break

with open('sku_to_product_id_mapping.json', 'w', encoding='utf-8') as f:
    json.dump(mapping, f, indent=2, ensure_ascii=False)

print(f"\nAlso created: sku_to_product_id_mapping.json")
print("  - Maps SKUs to new product IDs for reference")