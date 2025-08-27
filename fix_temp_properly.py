import json
import re

print("FIXING TEMPERATURE ENCODING - PROPER VERSION")
print("=" * 80)

# Load the original database with issues
with open('FINAL_COMPLETE_DATABASE.json', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the encoding issues in the raw JSON string
print("Fixing encoding issues in raw JSON...")

# Replace all malformed degree symbols
replacements = [
    ('\\u00b0', '°'),  # Unicode escape for degree
    ('Â°', '°'),       # Common UTF-8 mojibake
    ('°', '°'),        # Direct replacement
    ('\\u00c2\\u00b0', '°'),  # Double encoded
    ('Ã‚Â°', '°'),     # Triple encoded
    ('Â', ''),         # Remove stray Â
]

fixed_content = content
for old, new in replacements:
    count = fixed_content.count(old)
    if count > 0:
        print(f"  Replacing '{old}' ({count} occurrences)")
        fixed_content = fixed_content.replace(old, new)

# Now parse the fixed JSON
database = json.loads(fixed_content)
print(f"\nLoaded {len(database)} products")

# Additional cleanup function for any remaining issues
def clean_temperature(temp_str):
    """Clean up temperature string formatting"""
    if not temp_str or not isinstance(temp_str, str):
        return temp_str
    
    # Ensure proper degree symbol
    temp_str = re.sub(r'([+-]?\d+)\s*°?\s*([FC])', r'\1°\2', temp_str)
    
    # Fix common patterns
    patterns = [
        (r'(\d+)°F\s*-\s*(\d+)°F', r'\1°F to \2°F'),  # Fix dash to 'to'
        (r'(\d+)°C\s*-\s*(\d+)°C', r'\1°C to \2°C'),
        (r'([+-]?\d+)F\b', r'\1°F'),  # Add missing degree
        (r'([+-]?\d+)C\b', r'\1°C'),
    ]
    
    for pattern, replacement in patterns:
        temp_str = re.sub(pattern, replacement, temp_str)
    
    return temp_str.strip()

# Process all products
changes = 0
examples = []

for product_key, product in database.items():
    if isinstance(product, dict):
        # Fix temperature fields
        for field in ['temperatureRange', 'temperatureRangeMetric']:
            if field in product:
                original = product[field]
                cleaned = clean_temperature(original)
                if original != cleaned:
                    product[field] = cleaned
                    changes += 1
                    if len(examples) < 5 and 'Range' in field:
                        examples.append({
                            'sku': product.get('sku', 'Unknown'),
                            'field': field,
                            'original': original,
                            'fixed': cleaned
                        })
        
        # Fix description if it contains temperature info
        if 'description' in product and isinstance(product['description'], str):
            desc = product['description']
            # Replace temperature patterns in description
            desc_fixed = desc
            for old, new in replacements:
                desc_fixed = desc_fixed.replace(old, '°')
            
            desc_fixed = re.sub(r'Temperature Range: ([^\\n]+)', 
                               lambda m: 'Temperature Range: ' + clean_temperature(m.group(1)), 
                               desc_fixed)
            
            if desc != desc_fixed:
                product['description'] = desc_fixed
                changes += 1

print(f"\nMade {changes} temperature-related fixes")

if examples:
    print("\nExample fixes:")
    for ex in examples:
        print(f"  SKU: {ex['sku']} - {ex['field']}")
        print(f"    Before: {repr(ex['original'])}")
        print(f"    After:  {repr(ex['fixed'])}")

# Save the properly fixed database
output_file = 'FINAL_DATABASE_CLEAN.json'
with open(output_file, 'w', encoding='utf-8') as f:
    # Use ensure_ascii=False to properly save Unicode characters
    json.dump(database, f, indent=2, ensure_ascii=False)

print(f"\nSaved cleaned database to: {output_file}")

# Verify the fix worked
print("\n" + "=" * 80)
print("VERIFICATION - Temperature ranges after proper fix:")
print("=" * 80)

count = 0
for product_key, product in database.items():
    if isinstance(product, dict) and 'temperatureRange' in product:
        temp = product['temperatureRange']
        # Check if it looks correct
        if '°F' in temp or '°C' in temp:
            status = "[OK]"
        else:
            status = "[FAIL]"
        print(f"  {status} {product.get('sku', 'Unknown')}: {temp}")
        count += 1
        if count >= 10:
            break

# Check for any remaining issues
print("\nChecking for remaining encoding issues...")
remaining_issues = 0
for product_key, product in database.items():
    if isinstance(product, dict):
        for field in ['temperatureRange', 'temperatureRangeMetric']:
            if field in product:
                value = product[field]
                if 'Â' in str(value) or '\\u' in str(value):
                    remaining_issues += 1
                    if remaining_issues <= 3:
                        print(f"  Issue in {product.get('sku')}: {value}")

if remaining_issues == 0:
    print("  No remaining encoding issues found!")
else:
    print(f"  Found {remaining_issues} remaining issues")

print("\n" + "=" * 80)
print("COMPLETE! Use FINAL_DATABASE_CLEAN.json for import")
print("This file has proper temperature formatting without encoding issues")
print("=" * 80)