import json
import re

print("=" * 80)
print("FIXING TEMPERATURE ENCODING ISSUES IN FIREBASE DATA")
print("=" * 80)

# Read the database
with open('FULL_PRODUCTS_RESTORED.json', 'r', encoding='utf-8') as f:
    products = json.load(f)

print(f"Loaded {len(products)} products")

# Track changes
total_fixes = 0
examples = []

# Fix encoding issues in all text fields
def fix_encoding(text):
    """Fix common UTF-8 encoding issues"""
    if not text or not isinstance(text, str):
        return text
    
    original = text
    
    # Fix the specific Â° issue (this is UTF-8 interpreted as Windows-1252)
    # The pattern Â° appears when UTF-8 degree symbol is misinterpreted
    text = text.replace('Â°C', '°C')
    text = text.replace('Â°F', '°F')
    text = text.replace('Â°', '°')
    
    # Fix other common encoding issues
    text = text.replace('Ã‚Â°', '°')  # Double encoding
    text = text.replace('Ã‚', '')  # Remove Ã‚
    text = text.replace('Â', '')  # Remove standalone Â
    
    # Fix degree symbols that might be corrupted
    text = re.sub(r'(\d+)\s*Â\s*°\s*([CF])', r'\1°\2', text)
    text = re.sub(r'(\d+)Â°([CF])', r'\1°\2', text)
    
    # Ensure spaces around "to" in temperature ranges
    text = re.sub(r'(\d+°[CF])\s*to\s*(\d+°[CF])', r'\1 to \2', text)
    text = re.sub(r'(-?\d+°[CF])\s*to\s*(-?\d+°[CF])', r'\1 to \2', text)
    
    # Clean up any double spaces
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text

# Process each product
fixed_products = {}
for product_id, product in products.items():
    fixed_product = {}
    product_changed = False
    
    for key, value in product.items():
        if isinstance(value, str):
            fixed_value = fix_encoding(value)
            if fixed_value != value:
                product_changed = True
                if 'temperature' in key.lower() and len(examples) < 10:
                    examples.append({
                        'sku': product.get('sku', product.get('model', 'Unknown')),
                        'field': key,
                        'before': value,
                        'after': fixed_value
                    })
            fixed_product[key] = fixed_value
        else:
            fixed_product[key] = value
    
    if product_changed:
        total_fixes += 1
    
    fixed_products[product_id] = fixed_product

print(f"\nFixed encoding issues in {total_fixes} products")

if examples:
    print("\nExamples of fixes:")
    for ex in examples:
        print(f"\n  SKU: {ex['sku']}")
        print(f"  Field: {ex['field']}")
        print(f"  Before: {ex['before']}")
        print(f"  After:  {ex['after']}")

# Save the fixed products
output_file = 'products_fixed_encoding_final.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(fixed_products, f, indent=2, ensure_ascii=False)

print(f"\nSaved to: {output_file}")

# Also create a products node wrapper for Firebase
firebase_data = {"products": fixed_products}
firebase_file = 'firebase_products_fixed.json'
with open(firebase_file, 'w', encoding='utf-8') as f:
    json.dump(firebase_data, f, indent=2, ensure_ascii=False)

print(f"Saved Firebase import file to: {firebase_file}")

# Verify some samples
print("\n" + "=" * 80)
print("VERIFICATION - Sample temperature values after fix:")
print("=" * 80)

count = 0
for product_id, product in fixed_products.items():
    if 'temperatureRange' in product and product['temperatureRange']:
        sku = product.get('sku', product.get('model', 'Unknown'))
        print(f"  {sku}: {product['temperatureRange']}")
        count += 1
        if count >= 10:
            break

print("\n" + "=" * 80)
print("INSTRUCTIONS TO FIX FIREBASE:")
print("=" * 80)
print("Option 1: Replace all products")
print("  1. Go to Firebase Console: https://console.firebase.google.com/project/taquotes/database")
print("  2. Navigate to 'products' node")
print("  3. Click ⋮ menu → Import JSON")
print("  4. Upload 'products_fixed_encoding_final.json'")
print("")
print("Option 2: Import with wrapper")
print("  1. Same as above but at root level")
print("  2. Upload 'firebase_products_fixed.json'")
print("")
print("⚠️  BACKUP FIRST: firebase database:get /products > backup.json")