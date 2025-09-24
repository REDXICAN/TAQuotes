import json
import subprocess

# Product specifications gathered from web research
specs_updates = {
    "JUF-44D-N": {
        "dimensions": "44\"W x 32-1/4\"D x 30\"H",
        "dimensionsMetric": "111.8cm W x 81.9cm D x 76.2cm H",
        "capacity": "11 cu. ft.",
        "voltage": "115V",
        "amperage": "2.6 amps",
        "phase": "1",
        "frequency": "60Hz",
        "plugType": "NEMA 5-15P",
        "compressor": "1/2 HP",
        "refrigerant": "R290 Hydrocarbon",
        "temperatureRange": "-10°F to 0°F",
        "temperatureRangeMetric": "-23°C to -18°C",
        "doors": 1,
        "shelves": 2,
        "features": "LED interior lighting, stainless steel door, PE coated wire shelves",
        "certifications": "cETLus, ETL-Sanitation"
    },
    "JUF-93D-N": {
        "dimensions": "93\"W x 32-1/4\"D x 30\"H",
        "dimensionsMetric": "236.2cm W x 81.9cm D x 76.2cm H",
        "capacity": "30 cu. ft.",
        "voltage": "115V",
        "amperage": "7.1 amps",
        "phase": "1",
        "frequency": "60Hz",
        "plugType": "NEMA 5-15P",
        "compressor": "2/3 HP",
        "refrigerant": "R290 Hydrocarbon",
        "temperatureRange": "-10°F to 0°F",
        "temperatureRangeMetric": "-23°C to -18°C",
        "doors": 3,
        "shelves": 6,
        "features": "LED interior lighting, stainless steel doors, PE coated wire shelves",
        "certifications": "cETLus, ETL-Sanitation"
    },
    "JUR-36-N6": {
        "dimensions": "35-3/8\"W x 28-1/2\"D x 33-3/4\"H",
        "dimensionsMetric": "89.9cm W x 72.4cm D x 85.7cm H",
        "capacity": "7 cu. ft.",
        "voltage": "115V",
        "amperage": "3 amps",
        "phase": "1",
        "frequency": "60Hz",
        "plugType": "NEMA 5-15P",
        "compressor": "1/4 HP",
        "refrigerant": "R600a Hydrocarbon",
        "temperatureRange": "33°F to 39°F",
        "temperatureRangeMetric": "1°C to 4°C",
        "doors": 1,
        "shelves": 1,
        "features": "LED lighting, digital temperature control, ADA compliant, ENERGY STAR certified",
        "certifications": "cETLus, ETL-Sanitation, ENERGY STAR",
        "price": 3099.00
    },
    "PRCBE-36F-N": {
        "dimensions": "36\"L x 33-1/2\"D x 21-3/8\"H",
        "dimensionsMetric": "91.4cm L x 85.1cm D x 54.3cm H",
        "capacity": "4.6 cu. ft.",
        "voltage": "115V",
        "amperage": "3.2 amps",
        "phase": "1",
        "frequency": "60Hz",
        "plugType": "NEMA 5-15P",
        "compressor": "1/4 HP",
        "refrigerant": "R290 Hydrocarbon",
        "temperatureRange": "-10°F to 0°F",
        "temperatureRangeMetric": "-23°C to -18°C",
        "doors": 2,  # drawers
        "features": "Digital temperature display, self-cleaning condenser, marine drip guard edge, 788 lbs equipment capacity",
        "certifications": "ETL-Sanitation, cETLus",
        "price": 7189.50
    },
    "PRCBE-48R-N": {
        "dimensions": "48\"L x 33-1/2\"D x 21-3/8\"H",
        "dimensionsMetric": "121.9cm L x 85.1cm D x 54.3cm H",
        "capacity": "6.83 cu. ft.",
        "voltage": "115V",
        "amperage": "3.2 amps",
        "phase": "1",
        "frequency": "60Hz",
        "plugType": "NEMA 5-15P",
        "compressor": "1/4 HP",
        "refrigerant": "R290 Hydrocarbon",
        "temperatureRange": "33°F to 39°F",
        "temperatureRangeMetric": "1°C to 4°C",
        "doors": 2,  # drawers
        "features": "Digital temperature display, self-cleaning condenser, marine drip guard edge, 788 lbs equipment capacity",
        "certifications": "ETL-Sanitation, cETLus"
    }
}

print("Fetching current products from Firebase...")
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
print(f"Found {len(current_products)} products in database")

# Update products with new specs
updated_count = 0
for sku, specs in specs_updates.items():
    if sku in current_products:
        # Update the product with new specs
        for field, value in specs.items():
            current_products[sku][field] = value
        updated_count += 1
        print(f"Updated specs for: {sku}")
    else:
        print(f"SKU not found in database: {sku}")

print(f"\nUpdated {updated_count} products with new specifications")

# Save the updated products
output_file = 'products_with_updated_specs.json'
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(current_products, f, indent=2, ensure_ascii=False)

print("\n" + "=" * 70)
print(f"SUCCESS! Created: {output_file}")
print("=" * 70)
print("\nTO IMPORT:")
print("1. Go to Firebase Console > Realtime Database")
print("2. Click on the 'products' node")
print("3. Click the three dots menu → Import JSON")
print(f"4. Select: {output_file}")
print("\nThis file contains:")
print(f"- ALL {len(current_products)} products from your database")
print(f"- Updated specifications for {updated_count} products")
print("- New technical details including dimensions, electrical specs, and features")