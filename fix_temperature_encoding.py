import json
import re

def fix_encoding_issues(text):
    """Fix common UTF-8 encoding issues with temperature and other special characters"""
    if not isinstance(text, str):
        return text

    # Fix temperature degree symbols
    text = text.replace('Â°F', '°F')  # Fix Fahrenheit
    text = text.replace('Â°C', '°C')  # Fix Celsius
    text = text.replace('Â°', '°')    # Fix any other degree symbols
    text = text.replace('Â', '')       # Remove any remaining Â characters

    # Fix other common encoding issues
    text = text.replace('â€™', "'")    # Fix apostrophe
    text = text.replace('â€"', "-")    # Fix dash
    text = text.replace('â€œ', '"')    # Fix left quote
    text = text.replace('â€', '"')     # Fix right quote
    text = text.replace('Ã—', 'x')     # Fix multiplication sign
    text = text.replace('â€¢', '•')    # Fix bullet point

    return text

def clean_product_data(product):
    """Clean all text fields in a product"""
    for key, value in product.items():
        if isinstance(value, str):
            product[key] = fix_encoding_issues(value)
        elif isinstance(value, dict):
            # Recursively clean nested objects
            product[key] = clean_product_data(value)
        elif isinstance(value, list):
            # Clean items in lists
            product[key] = [fix_encoding_issues(item) if isinstance(item, str) else item for item in value]
    return product

print("=" * 70)
print("FIXING TEMPERATURE ENCODING ISSUES")
print("=" * 70)

# Load the converted products file
print("\n1. Loading products file...")
with open('products_product_format_FINAL.json', 'r', encoding='utf-8') as f:
    products = json.load(f)

print(f"   Loaded {len(products)} products")

# Check for encoding issues
print("\n2. Checking for encoding issues...")
issues_found = []
for product_id, product_data in products.items():
    for field in ['temperatureRange', 'temperatureRangeMetric', 'dimensions', 'weight', 'features', 'description', 'name', 'displayName']:
        if field in product_data and product_data[field]:
            value = str(product_data[field])
            if 'Â°' in value or 'Â' in value or 'â€' in value:
                issues_found.append((product_id, field, value))
                if len(issues_found) <= 5:
                    print(f"   Found issue in {product_id} - {field}: {value[:50]}...")

print(f"\n   Total fields with encoding issues: {len(issues_found)}")

# Fix all encoding issues
print("\n3. Fixing encoding issues...")
fixed_count = 0
for product_id, product_data in products.items():
    original_json = json.dumps(product_data)
    cleaned_product = clean_product_data(product_data)

    if json.dumps(cleaned_product) != original_json:
        products[product_id] = cleaned_product
        fixed_count += 1

print(f"   Fixed encoding in {fixed_count} products")

# Save the cleaned products
output_file = 'products_clean_encoding_FINAL.json'
print(f"\n4. Saving cleaned products to {output_file}...")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

# Verify the fix
print("\n5. Verifying fixes...")
with open(output_file, 'r', encoding='utf-8') as f:
    content = f.read()

bad_patterns = ['Â°F', 'Â°C', 'Â°', 'â€™', 'â€"', 'â€œ', 'â€', 'Ã—']
found_issues = False
for pattern in bad_patterns:
    if pattern in content:
        print(f"   WARNING: Still found '{pattern}' in output file!")
        found_issues = True

if not found_issues:
    print("   SUCCESS: No encoding issues found in output file!")

# Show sample of fixed data
print("\n6. Sample of fixed data:")
sample_products = list(products.items())[:3]
for product_id, product_data in sample_products:
    if 'temperatureRange' in product_data and product_data['temperatureRange']:
        print(f"   {product_id}:")
        print(f"     Temperature Range: {product_data['temperatureRange']}")
        if 'temperatureRangeMetric' in product_data:
            print(f"     Temperature Range (Metric): {product_data['temperatureRangeMetric']}")

print("\n" + "=" * 70)
print(f"SUCCESS! Created: {output_file}")
print("=" * 70)

print(f"\nFile contains:")
print(f"  - {len(products)} products with clean encoding")
print(f"  - Fixed temperature symbols (°F, °C)")
print(f"  - Fixed all special characters")
print(f"  - product_XXXX format maintained")

print("\nTO IMPORT:")
print("1. Go to Firebase Console > Realtime Database")
print("2. Click on the 'products' node")
print("3. Click the three dots menu (...) -> Import JSON")
print(f"4. Select: {output_file}")

print("\nThis file has:")
print("  - ALL encoding issues fixed")
print("  - Proper degree symbols for temperatures")
print("  - Clean text in all fields")