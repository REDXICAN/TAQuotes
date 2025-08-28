import json

print("EMERGENCY: Consolidating products...")

# Load the FULL database
with open('firebase_products_current.json', 'r') as f:
    all_products = json.load(f)

# Load the cleaned asterisk products
with open('products_asterisks_fixed.json', 'r') as f:
    cleaned_products = json.load(f)

print(f"Original products count: {len(all_products)}")
print(f"Cleaned asterisk products: {len(cleaned_products)}")

# List of old SKUs with asterisks that need to be removed
old_asterisk_skus = [
    "TGF-72SDH*-N",
    "TGF-35SDH*-N", 
    "TGM-15SDH*-N6",
    "TGM-35SDH*-N",
    "TGM-72SDH*-N",
    "TGF-23SDH*-N",
    "TGM-47SD*-N",
    "TGF-47SDH*-N",
    "TGM-15SD*-N6",
    "TGM-47SDH*-N",
    "TGM-23SDH*-N6",
    "TGM-5SD*-N6",
    "TGM-72SD*-N",
    "TGM-20SD*-N6",
    "TGM-7SD*-N6",
    "TGM-35SD*-N",
    "TGM-12SD*-N6",
    "TGM-23SD*-N6",
    "TGM-10SD*-N6"
]

# Remove old products with asterisks
for old_sku in old_asterisk_skus:
    if old_sku in all_products:
        del all_products[old_sku]
        print(f"Removed old: {old_sku}")

# Add the cleaned products
for clean_sku, product in cleaned_products.items():
    all_products[clean_sku] = product
    print(f"Added cleaned: {clean_sku}")

print(f"\nFINAL products count: {len(all_products)}")

# Save the consolidated database
with open('FULL_PRODUCTS_RESTORED.json', 'w') as f:
    json.dump(all_products, f, indent=2)

print("\n✅ Saved to FULL_PRODUCTS_RESTORED.json")
print("This file contains ALL products with asterisks cleaned")
print("\nIMPORT THIS TO /products NODE IN FIREBASE")