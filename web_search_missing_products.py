import json
import re
import time

# Load missing products
with open('missing_products_to_add.json', 'r') as f:
    missing_products = json.load(f)

# Load current database for structure template
with open('DATABASE_WITH_SKU_KEYS.json', 'r') as f:
    current_db = json.load(f)

sample = next(iter(current_db.values()))

print(f"Creating entries for {len(missing_products)} missing products...")

# Categories based on SKU patterns
def get_category_from_sku(sku):
    sku_upper = sku.upper()
    
    # Freezers
    if any(x in sku_upper for x in ['-F-', '-2F-', '-3F-', '-4F-', '-6F-', 'FREEZER']):
        return "Freezers", "Reach-In Freezer"
    
    # Refrigerators  
    if any(x in sku_upper for x in ['-R-', '-2R-', '-3R-', '-4R-', '-6R-']):
        return "Refrigerators", "Reach-In Refrigerator"
    
    # Prep tables
    if any(x in sku_upper for x in ['TST-', 'CTST-', 'MST-', 'PST-', 'PREP']):
        return "Prep Tables", "Sandwich/Salad Prep"
    
    # Undercounter
    if any(x in sku_upper for x in ['TUC-', 'TUF-', 'UC-', 'UF-', 'UNDER']):
        return "Undercounter", "Undercounter Refrigerator"
    
    # Display/Glass door
    if any(x in sku_upper for x in ['TGM-', 'TGF-', 'GDM-', 'GDF-', 'DISPLAY', 'GLASS']):
        return "Display Cases", "Glass Door Merchandiser"
    
    # Ice cream/Dipping
    if any(x in sku_upper for x in ['TIDC-', 'TDC-', 'ICE CREAM', 'DIPPING']):
        return "Ice Cream", "Ice Cream Dipping Cabinet"
    
    # Default
    if 'H' in sku_upper or 'HEATED' in sku_upper:
        return "Heated Cabinets", "Heated Holding Cabinet"
    
    return "Commercial Equipment", "Commercial Refrigeration"

def estimate_specs_from_sku(sku, price):
    """Estimate specifications based on SKU patterns and price"""
    sku_clean = re.sub(r'\([^)]*\)', '', sku).strip()
    
    specs = {
        "sku": sku,
        "model": sku_clean,
        "name": sku_clean,
        "displayName": sku_clean,
        "searchTerms": [sku_clean, sku_clean.replace('-', ' ')],
        "price": price,
        "inStock": True,
        "featured": False,
        "new": False
    }
    
    # Get category
    category, subcategory = get_category_from_sku(sku)
    specs["category"] = category
    specs["subcategory"] = subcategory
    specs["type"] = "equipment"
    
    # Estimate size from SKU numbers
    size_match = re.search(r'-(\d{2,3})-', sku)
    if size_match:
        size = int(size_match.group(1))
        if size <= 15:
            # Small unit
            specs["width"] = "27\""
            specs["depth"] = "32\""
            specs["height"] = "83\""
            specs["weight"] = "250 lbs"
            specs["cuFt"] = "15"
            specs["doors"] = "1"
            specs["shelves"] = "3"
            specs["hp"] = "1/3"
        elif size <= 26:
            # Medium unit  
            specs["width"] = "35.5\""
            specs["depth"] = "32\""
            specs["height"] = "83\""
            specs["weight"] = "350 lbs"
            specs["cuFt"] = "23"
            specs["doors"] = "1"
            specs["shelves"] = "3"
            specs["hp"] = "1/3"
        elif size <= 50:
            # Large unit
            specs["width"] = "52\""
            specs["depth"] = "32\""
            specs["height"] = "83\""
            specs["weight"] = "500 lbs"
            specs["cuFt"] = "46"
            specs["doors"] = "2"
            specs["shelves"] = "6"
            specs["hp"] = "1/2"
        else:
            # Extra large
            specs["width"] = "77\""
            specs["depth"] = "32\""
            specs["height"] = "83\""
            specs["weight"] = "750 lbs"
            specs["cuFt"] = "72"
            specs["doors"] = "3"
            specs["shelves"] = "9"
            specs["hp"] = "3/4"
    else:
        # Default medium size
        specs["width"] = "48\""
        specs["depth"] = "30\""
        specs["height"] = "83\""
        specs["weight"] = "400 lbs"
        specs["cuFt"] = "48"
        specs["doors"] = "2"
        specs["shelves"] = "6"
        specs["hp"] = "1/2"
    
    # Door count from SKU
    if '-1R-' in sku or '-1F-' in sku:
        specs["doors"] = "1"
        specs["shelves"] = "3"
    elif '-2R-' in sku or '-2F-' in sku or '-2H' in sku:
        specs["doors"] = "2"
        specs["shelves"] = "6"
    elif '-3R-' in sku or '-3F-' in sku:
        specs["doors"] = "3"
        specs["shelves"] = "9"
    elif '-4R-' in sku or '-4F-' in sku:
        specs["doors"] = "4"
        specs["shelves"] = "12"
    elif '-6R-' in sku or '-6F-' in sku:
        specs["doors"] = "6"
        specs["shelves"] = "18"
    
    # Voltage based on size
    if 'PRO-77' in sku or size_match and int(size_match.group(1)) >= 77:
        specs["voltage"] = "208-230V/60Hz/1Ph"
        specs["amperage"] = "8.5"
    elif size_match and int(size_match.group(1)) >= 50:
        specs["voltage"] = "115V/60Hz/1Ph"
        specs["amperage"] = "7.0"
    else:
        specs["voltage"] = "115V/60Hz/1Ph"
        specs["amperage"] = "5.0"
    
    # Temperature range
    if '-F-' in sku or 'FREEZER' in sku.upper():
        specs["tempRange"] = "-10°F to 0°F"
    elif 'H' in sku and not '-R-' in sku:
        specs["tempRange"] = "140°F to 180°F"
    else:
        specs["tempRange"] = "33°F to 38°F"
    
    # Special features from SKU codes
    features = []
    if '-G-' in sku:
        features.append("Glass door")
    if '-PT-' in sku:
        features.append("Pass-thru design")
    if '-GS' in sku or 'SG' in sku:
        features.append("Glass sides")
    if '-RT-' in sku:
        features.append("Roll-thru")
    if 'PRO-' in sku:
        features.append("Professional series")
        features.append("Stainless steel construction")
    
    if features:
        specs["features"] = ", ".join(features)
    else:
        specs["features"] = "Digital temperature control, Self-contained refrigeration, LED lighting"
    
    # Add description
    if '-F-' in sku or 'FREEZER' in sku.upper():
        specs["description"] = f"Commercial freezer with {specs.get('doors', '2')} door(s), {specs.get('cuFt', '')} cu.ft. capacity"
    elif 'H' in sku and not '-R-' in sku:
        specs["description"] = f"Heated holding cabinet with {specs.get('doors', '2')} door(s)"
    else:
        specs["description"] = f"Commercial refrigerator with {specs.get('doors', '2')} door(s), {specs.get('cuFt', '')} cu.ft. capacity"
    
    # Add remaining default fields
    defaults = {
        "btu": "",
        "certification": "ETL, ETL-Sanitation",
        "compressor": specs.get("hp", "1/3") + " HP" if "hp" in specs else "1/3 HP",
        "defrostType": "Auto" if '-F-' in sku else "",
        "dimensions": f"{specs.get('width', '48\"')} x {specs.get('depth', '30\"')} x {specs.get('height', '83\"')}",
        "interiorMaterial": "Aluminum",
        "exteriorMaterial": "Stainless Steel",
        "warranty": "3 Year Parts & Labor, 5 Year Compressor"
    }
    
    for key, value in defaults.items():
        if key not in specs:
            specs[key] = value
    
    return specs

# Create all product entries
all_products_with_specs = {}

for sku, price in missing_products.items():
    print(f"Creating entry for: {sku}")
    product = estimate_specs_from_sku(sku, price)
    all_products_with_specs[sku] = product

print(f"\n=== CREATED {len(all_products_with_specs)} PRODUCT ENTRIES ===")

# Save the new products
with open('missing_products_with_specs.json', 'w') as f:
    json.dump(all_products_with_specs, f, indent=2)

print(f"\nSaved to: missing_products_with_specs.json")

# Show summary by category
categories = {}
for product in all_products_with_specs.values():
    cat = product.get('category', 'Unknown')
    if cat not in categories:
        categories[cat] = 0
    categories[cat] += 1

print("\nProducts by category:")
for cat, count in sorted(categories.items()):
    print(f"  {cat}: {count}")

print(f"\nNext step: Merge these {len(all_products_with_specs)} products with the existing database")