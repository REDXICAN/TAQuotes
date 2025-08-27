import json
import re

print("FIXING TEMPERATURE RANGE ENCODING ISSUES")
print("=" * 80)

# Load the final database
with open('FINAL_COMPLETE_DATABASE.json', 'r', encoding='utf-8') as f:
    database = json.load(f)

print(f"Loaded {len(database)} products")

# Function to fix temperature strings
def fix_temperature(temp_str):
    """Fix temperature encoding issues"""
    if not temp_str:
        return temp_str
    
    # Common encoding issues with degree symbol
    replacements = [
        ('Â°', '°'),  # Common UTF-8 issue
        ('°', '°'),   # Already correct
        ('Ã‚Â°', '°'), # Double encoding issue
        ('Â', ''),     # Remove stray Â
        ('  ', ' '),   # Fix double spaces
    ]
    
    fixed = temp_str
    for old, new in replacements:
        fixed = fixed.replace(old, new)
    
    # Ensure proper formatting
    # Should be like: "33°F to 38°F" or "-10°F to 0°F"
    # Fix patterns like "33F" to "33°F"
    fixed = re.sub(r'(\d+)\s*F\b', r'\1°F', fixed)
    fixed = re.sub(r'(\d+)\s*C\b', r'\1°C', fixed)
    
    # Fix patterns where degree is separated
    fixed = re.sub(r'(\d+)\s+°\s+([FC])', r'\1°\2', fixed)
    
    # Clean up spacing
    fixed = re.sub(r'\s+', ' ', fixed).strip()
    
    return fixed

# Track changes
changes_made = 0
examples = []

# Fix all temperature fields in products
for product_key, product in database.items():
    if isinstance(product, dict):
        # Fix temperatureRange
        if 'temperatureRange' in product:
            original = product['temperatureRange']
            fixed = fix_temperature(original)
            if original != fixed:
                product['temperatureRange'] = fixed
                changes_made += 1
                if len(examples) < 5:
                    examples.append({
                        'sku': product.get('sku', 'Unknown'),
                        'original': original,
                        'fixed': fixed
                    })
        
        # Fix temperatureRangeMetric
        if 'temperatureRangeMetric' in product:
            original = product['temperatureRangeMetric']
            fixed = fix_temperature(original)
            if original != fixed:
                product['temperatureRangeMetric'] = fixed
                changes_made += 1
        
        # Also fix in description field if it contains temperature
        if 'description' in product and '°' in str(product['description']):
            original = product['description']
            fixed = fix_temperature(original)
            if original != fixed:
                product['description'] = fixed
                changes_made += 1

print(f"\nFixed {changes_made} temperature fields")

if examples:
    print("\nExamples of fixes:")
    for ex in examples:
        print(f"  SKU: {ex['sku']}")
        print(f"    Original: {ex['original']}")
        print(f"    Fixed: {ex['fixed']}")

# Save the fixed database
output_file = 'FINAL_DATABASE_FIXED_TEMP.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(database, f, indent=2, ensure_ascii=False)

print(f"\nSaved fixed database to: {output_file}")

# Verify a few products
print("\n" + "=" * 80)
print("VERIFICATION - Sample temperature ranges after fix:")
print("=" * 80)

sample_count = 0
for product_key, product in database.items():
    if isinstance(product, dict) and 'temperatureRange' in product:
        print(f"  {product.get('sku', 'Unknown')}: {product['temperatureRange']}")
        sample_count += 1
        if sample_count >= 10:
            break

print("\n" + "=" * 80)
print("COMPLETE! Temperature ranges have been fixed.")
print(f"Use this file for import: {output_file}")
print("=" * 80)