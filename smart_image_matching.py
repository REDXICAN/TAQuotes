import json
import os
import re
from pathlib import Path
from difflib import get_close_matches

print("SMART IMAGE MATCHING FOR COMPLEX SKUs")
print("=" * 80)

# Load the final database to get all SKUs
with open('FINAL_COMPLETE_DATABASE.json', 'r', encoding='utf-8') as f:
    products = json.load(f)

print(f"Total products in database: {len(products)}")

# Define asset paths
thumbnails_path = Path(r'D:\Flutter App\TAQuotes\assets\thumbnails')
screenshots_path = Path(r'D:\Flutter App\TAQuotes\assets\screenshots')

# Get all available thumbnail folders
thumbnail_folders = {}
if thumbnails_path.exists():
    for folder in thumbnails_path.iterdir():
        if folder.is_dir():
            # Store both original and cleaned version
            thumbnail_folders[folder.name] = folder.name
            thumbnail_folders[folder.name.upper()] = folder.name

print(f"Found {len(set(thumbnail_folders.values()))} unique thumbnail folders")

# Get all available screenshot folders
screenshot_folders = {}
if screenshots_path.exists():
    for folder in screenshots_path.iterdir():
        if folder.is_dir():
            screenshot_folders[folder.name] = folder.name
            screenshot_folders[folder.name.upper()] = folder.name

print(f"Found {len(set(screenshot_folders.values()))} unique screenshot folders")

def normalize_sku(sku):
    """Normalize SKU for better matching"""
    sku = sku.upper()
    
    # Remove specific patterns but keep the base
    # Handle parentheses content
    sku = re.sub(r'\([^)]*\)', '', sku)  # Remove everything in parentheses
    
    # Handle asterisks
    sku = sku.replace('*', '')
    
    # Remove common suffixes
    sku = re.sub(r'-(L|R|AL|AR|LR|RL|LW|GL|FL|CL|FCL|SL|FB|N|SH|CRT|RI|PT|RT|GS|SG|GSSG)$', '', sku)
    
    # Clean up extra hyphens and spaces
    sku = re.sub(r'-+', '-', sku)  # Multiple hyphens to single
    sku = sku.strip('-').strip()
    
    return sku

def find_best_match(sku, folder_dict):
    """Find the best matching folder for a SKU"""
    sku_upper = sku.upper()
    
    # Direct match
    if sku_upper in folder_dict:
        return folder_dict[sku_upper]
    
    # Try normalized version
    normalized = normalize_sku(sku)
    if normalized in folder_dict:
        return folder_dict[normalized]
    
    # Try without parentheses content
    if '(' in sku:
        base_sku = re.sub(r'\([^)]*\)', '', sku_upper).strip()
        if base_sku in folder_dict:
            return folder_dict[base_sku]
        
        # Try with just the parentheses part removed but keeping hyphens
        base_sku2 = re.sub(r'\([^)]*\)', '', sku_upper)
        base_sku2 = re.sub(r'-+', '-', base_sku2).strip('-')
        if base_sku2 in folder_dict:
            return folder_dict[base_sku2]
    
    # For asterisk SKUs, try without asterisk
    if '*' in sku:
        no_asterisk = sku_upper.replace('*', '')
        if no_asterisk in folder_dict:
            return folder_dict[no_asterisk]
    
    # Try removing specific complex patterns
    patterns_to_try = [
        # For PST-48-18-D2R(L)-FB-N, try PST-48-18
        re.sub(r'-D\d+R?\([^)]*\).*$', '', sku_upper),
        # For PRO-26R-GS(SG)-PT-N(-L), try PRO-26R
        re.sub(r'-[A-Z]{2,}\([^)]*\).*$', '', sku_upper),
        # Try just the first two segments
        '-'.join(sku_upper.split('-')[:2]) if '-' in sku_upper else None,
        # Try first three segments
        '-'.join(sku_upper.split('-')[:3]) if sku_upper.count('-') >= 2 else None,
    ]
    
    for pattern in patterns_to_try:
        if pattern and pattern in folder_dict:
            return folder_dict[pattern]
    
    # Use fuzzy matching as last resort
    close_matches = get_close_matches(normalized, folder_dict.keys(), n=1, cutoff=0.8)
    if close_matches:
        return folder_dict[close_matches[0]]
    
    return None

# Analyze products with smart matching
results = {
    'has_thumbnail': [],
    'has_screenshot_only': [],
    'has_nothing': [],
    'smart_matched_thumbnail': [],
    'smart_matched_screenshot': []
}

print("\n" + "=" * 80)
print("ANALYZING WITH SMART MATCHING...")
print("=" * 80)

for product_key, product in products.items():
    sku = product.get('sku', '')
    if not sku:
        continue
    
    # Try to find thumbnail
    thumbnail_match = find_best_match(sku, thumbnail_folders)
    screenshot_match = find_best_match(sku, screenshot_folders)
    
    if thumbnail_match:
        if sku.upper() == thumbnail_match.upper():
            results['has_thumbnail'].append({
                'sku': sku,
                'folder': thumbnail_match,
                'type': 'direct'
            })
        else:
            results['smart_matched_thumbnail'].append({
                'sku': sku,
                'matched_to': thumbnail_match,
                'normalized': normalize_sku(sku)
            })
    elif screenshot_match:
        if sku.upper() == screenshot_match.upper():
            results['has_screenshot_only'].append({
                'sku': sku,
                'folder': screenshot_match,
                'type': 'direct'
            })
        else:
            results['smart_matched_screenshot'].append({
                'sku': sku,
                'matched_to': screenshot_match,
                'normalized': normalize_sku(sku)
            })
    else:
        results['has_nothing'].append({
            'sku': sku,
            'name': product.get('name', 'Unknown'),
            'category': product.get('category', 'Unknown'),
            'normalized': normalize_sku(sku)
        })

# Print detailed summary
print("\n" + "=" * 80)
print("DETAILED MATCHING RESULTS")
print("=" * 80)

print(f"\n1. PRODUCTS WITH THUMBNAILS: {len(results['has_thumbnail']) + len(results['smart_matched_thumbnail'])}")
print(f"   - Direct matches: {len(results['has_thumbnail'])}")
print(f"   - Smart matches: {len(results['smart_matched_thumbnail'])}")

if results['smart_matched_thumbnail']:
    print("\n   Examples of smart thumbnail matches:")
    for item in results['smart_matched_thumbnail'][:5]:
        print(f"     {item['sku']} -> {item['matched_to']}")

print(f"\n2. PRODUCTS WITH SCREENSHOTS ONLY: {len(results['has_screenshot_only']) + len(results['smart_matched_screenshot'])}")
print(f"   - Direct matches: {len(results['has_screenshot_only'])}")
print(f"   - Smart matches: {len(results['smart_matched_screenshot'])}")

if results['smart_matched_screenshot']:
    print("\n   Examples of smart screenshot matches:")
    for item in results['smart_matched_screenshot'][:5]:
        print(f"     {item['sku']} -> {item['matched_to']}")

print(f"\n3. PRODUCTS WITH NO IMAGES: {len(results['has_nothing'])}")

# Group missing by pattern
if results['has_nothing']:
    print("\n   Grouping by SKU patterns:")
    patterns = {}
    
    for item in results['has_nothing']:
        sku = item['sku']
        # Identify pattern
        if '*' in sku:
            pattern = "Contains asterisk (*)"
        elif '(' in sku and ')' in sku:
            pattern = "Contains parentheses ()"
        elif sku.count('-') > 4:
            pattern = "Complex multi-segment (5+ parts)"
        elif 'SD' in sku:
            pattern = "SD series"
        else:
            pattern = "Other"
        
        if pattern not in patterns:
            patterns[pattern] = []
        patterns[pattern].append(item)
    
    for pattern, items in sorted(patterns.items()):
        print(f"\n   {pattern}: {len(items)} products")
        for item in items[:3]:
            print(f"     - {item['sku']}: {item['name']}")
        if len(items) > 3:
            print(f"     ... and {len(items) - 3} more")

# Create mapping file with smart matches
mapping_data = {
    'summary': {
        'total_products': len(products),
        'with_thumbnail': len(results['has_thumbnail']) + len(results['smart_matched_thumbnail']),
        'with_screenshot_only': len(results['has_screenshot_only']) + len(results['smart_matched_screenshot']),
        'with_no_images': len(results['has_nothing']),
        'smart_matches': len(results['smart_matched_thumbnail']) + len(results['smart_matched_screenshot'])
    },
    'smart_thumbnail_mappings': {},
    'smart_screenshot_mappings': {},
    'missing_completely': results['has_nothing']
}

# Build smart mappings
for item in results['smart_matched_thumbnail']:
    mapping_data['smart_thumbnail_mappings'][item['sku']] = {
        'matched_folder': item['matched_to'],
        'thumbnailUrl': f"https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/thumbnails%2F{item['matched_to']}%2F{item['matched_to']}.jpg?alt=media"
    }

for item in results['smart_matched_screenshot']:
    mapping_data['smart_screenshot_mappings'][item['sku']] = {
        'matched_folder': item['matched_to'],
        'imageUrl': f"https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2F{item['matched_to']}%2F{item['matched_to']}%20P.1.png?alt=media"
    }

# Save results
with open('smart_image_mappings.json', 'w', encoding='utf-8') as f:
    json.dump(mapping_data, f, indent=2)

print("\n" + "=" * 80)
print("FINAL SUMMARY")
print("=" * 80)
print(f"Total Products: {len(products)}")
print(f"[OK] With Thumbnails: {len(results['has_thumbnail']) + len(results['smart_matched_thumbnail'])} ({(len(results['has_thumbnail']) + len(results['smart_matched_thumbnail']))/len(products)*100:.1f}%)")
print(f"[SCREENSHOT] Screenshot Only: {len(results['has_screenshot_only']) + len(results['smart_matched_screenshot'])} ({(len(results['has_screenshot_only']) + len(results['smart_matched_screenshot']))/len(products)*100:.1f}%)")
print(f"[MISSING] No Images: {len(results['has_nothing'])} ({len(results['has_nothing'])/len(products)*100:.1f}%)")
print(f"\n[SMART] Smart Matches Found: {len(results['smart_matched_thumbnail']) + len(results['smart_matched_screenshot'])}")
print("\nSaved to: smart_image_mappings.json")
print("=" * 80)