import json
import os
from pathlib import Path

print("FINDING MISSING IMAGES AND MAPPING TO SKUs")
print("=" * 80)

# Load the final database to get all SKUs
with open('FINAL_COMPLETE_DATABASE.json', 'r', encoding='utf-8') as f:
    products = json.load(f)

print(f"Total products in database: {len(products)}")

# Define asset paths
thumbnails_path = Path(r'D:\Flutter App\TAQuotes\assets\thumbnails')
screenshots_path = Path(r'D:\Flutter App\TAQuotes\assets\screenshots')

# Get all available thumbnail folders
thumbnail_folders = set()
if thumbnails_path.exists():
    for folder in thumbnails_path.iterdir():
        if folder.is_dir():
            thumbnail_folders.add(folder.name.upper())

print(f"Found {len(thumbnail_folders)} thumbnail folders")

# Get all available screenshot folders
screenshot_folders = set()
if screenshots_path.exists():
    for folder in screenshots_path.iterdir():
        if folder.is_dir():
            screenshot_folders.add(folder.name.upper())

print(f"Found {len(screenshot_folders)} screenshot folders")

# Analyze each product
missing_images = []
found_thumbnails = []
found_screenshots = []
using_screenshot_fallback = []

# SKU cleaning function
def clean_sku(sku):
    """Remove common suffixes and clean SKU for matching"""
    sku = sku.upper()
    # Remove common suffixes
    suffixes_to_remove = [
        '(-L)', '(-R)', '(-AL)', '(-AR)', '(-LR)', '(-RL)',
        '(-L)(-R)', '(-AL)(-AR)', '(-LR)(-RL)',
        '_LEFT', '_RIGHT', '_L', '_R'
    ]
    for suffix in suffixes_to_remove:
        if suffix in sku:
            sku = sku.replace(suffix, '')
    return sku.strip()

# Alternative SKU patterns
def get_sku_variants(sku):
    """Generate possible SKU variants for matching"""
    base_sku = clean_sku(sku)
    variants = [
        base_sku,
        base_sku.replace('-', '_'),
        base_sku.replace('_', '-'),
        base_sku + '_Left',
        base_sku + '_Right',
        base_sku + '-L',
        base_sku + '-R'
    ]
    
    # For PRO series, try without parentheses
    if 'PRO-' in base_sku:
        clean = base_sku.replace('(', '').replace(')', '')
        variants.append(clean)
    
    return variants

print("\nAnalyzing products...")

for product_key, product in products.items():
    sku = product.get('sku', '')
    if not sku:
        continue
    
    sku_upper = sku.upper()
    sku_variants = get_sku_variants(sku)
    
    # Check for thumbnail
    thumbnail_found = False
    for variant in sku_variants:
        if variant in thumbnail_folders:
            thumbnail_found = True
            found_thumbnails.append({
                'sku': sku,
                'folder': variant,
                'path': f'assets/thumbnails/{variant}/{variant}.jpg'
            })
            break
    
    # Check for screenshot
    screenshot_found = False
    screenshot_folder = None
    for variant in sku_variants:
        if variant in screenshot_folders:
            screenshot_found = True
            screenshot_folder = variant
            found_screenshots.append({
                'sku': sku,
                'folder': variant,
                'path': f'assets/screenshots/{variant}/{variant} P.1.png'
            })
            break
    
    # If no thumbnail but has screenshot, use screenshot as fallback
    if not thumbnail_found and screenshot_found:
        using_screenshot_fallback.append({
            'sku': sku,
            'screenshot_folder': screenshot_folder,
            'fallback_path': f'assets/screenshots/{screenshot_folder}/{screenshot_folder} P.1.png'
        })
    
    # If neither found, mark as missing
    if not thumbnail_found and not screenshot_found:
        missing_images.append({
            'sku': sku,
            'product_name': product.get('name', 'Unknown'),
            'category': product.get('category', 'Unknown')
        })

print(f"\n[DONE] Analysis complete!")
print(f"  - Products with thumbnails: {len(found_thumbnails)}")
print(f"  - Products with screenshots: {len(found_screenshots)}")
print(f"  - Using screenshot fallback: {len(using_screenshot_fallback)}")
print(f"  - Completely missing images: {len(missing_images)}")

# Show products using screenshot fallback
if using_screenshot_fallback:
    print(f"\n[SCREENSHOT FALLBACK] PRODUCTS USING SCREENSHOT FALLBACK ({len(using_screenshot_fallback)}):")
    print("-" * 80)
    for item in using_screenshot_fallback[:10]:
        print(f"  SKU: {item['sku']}")
        print(f"    -> Using: {item['fallback_path']}")
    if len(using_screenshot_fallback) > 10:
        print(f"  ... and {len(using_screenshot_fallback) - 10} more")

# Show missing images
if missing_images:
    print(f"\n[MISSING] COMPLETELY MISSING IMAGES ({len(missing_images)}):")
    print("-" * 80)
    
    # Group by category
    by_category = {}
    for item in missing_images:
        cat = item['category']
        if cat not in by_category:
            by_category[cat] = []
        by_category[cat].append(item)
    
    for category, items in sorted(by_category.items()):
        print(f"\n{category} ({len(items)} products):")
        for item in items[:5]:
            print(f"  - {item['sku']}: {item['product_name']}")
        if len(items) > 5:
            print(f"  ... and {len(items) - 5} more")

# Create image mapping update file
print("\n" + "=" * 80)
print("CREATING IMAGE MAPPING UPDATE")
print("=" * 80)

# Create update script for missing images
update_mappings = {}

for item in using_screenshot_fallback:
    sku = item['sku']
    screenshot_path = item['fallback_path']
    
    # Find product in database
    for product_key, product in products.items():
        if product.get('sku') == sku:
            update_mappings[product_key] = {
                'sku': sku,
                'thumbnailUrl': f"https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2F{item['screenshot_folder']}%2F{item['screenshot_folder']}%20P.1.png?alt=media",
                'imageUrl': f"https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2F{item['screenshot_folder']}%2F{item['screenshot_folder']}%20P.1.png?alt=media"
            }
            break

# Save mappings
output_file = 'image_fallback_mappings.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump({
        'fallback_mappings': update_mappings,
        'missing_completely': missing_images,
        'using_screenshot_fallback': using_screenshot_fallback,
        'summary': {
            'total_products': len(products),
            'have_thumbnails': len(found_thumbnails),
            'have_screenshots': len(found_screenshots),
            'using_fallback': len(using_screenshot_fallback),
            'missing_all': len(missing_images)
        }
    }, f, indent=2)

print(f"\nSaved image analysis to: {output_file}")

# Generate fix script
print("\nGenerating fix script...")

fix_script = """// Fix missing thumbnails by using screenshot fallbacks
const updateMissingThumbnails = () => {
  const fallbacks = {
"""

for sku, mapping in list(update_mappings.items())[:10]:
    fix_script += f"""    "{mapping['sku']}": {{
      thumbnailUrl: "{mapping['thumbnailUrl']}",
      imageUrl: "{mapping['imageUrl']}"
    }},
"""

fix_script += """  };
  
  // Apply fallbacks in your image widget
  const getProductImage = (sku) => {
    return fallbacks[sku] || null;
  };
};
"""

with open('fix_missing_thumbnails.js', 'w') as f:
    f.write(fix_script)

print("\n" + "=" * 80)
print("SUMMARY:")
print(f"  [OK] {len(found_thumbnails)} products have thumbnails")
print(f"  [OK] {len(using_screenshot_fallback)} can use screenshot as fallback")
print(f"  [MISSING] {len(missing_images)} have no images at all")
print("\nFiles created:")
print("  - image_fallback_mappings.json (complete analysis)")
print("  - fix_missing_thumbnails.js (fix script)")
print("=" * 80)