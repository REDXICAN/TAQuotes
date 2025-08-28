import json
import requests

# List of SKUs that have asterisks
skus_with_asterisks = [
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

print("Fetching products with asterisks...")

# Create a dictionary for the fixed products
fixed_products = {}

for sku in skus_with_asterisks:
    # Fetch the product
    url = f"https://taquotes-default-rtdb.firebaseio.com/products/{sku}.json"
    response = requests.get(url)
    
    if response.status_code == 200 and response.json():
        product_data = response.json()
        # Fix the SKU in the product data
        clean_sku = sku.replace('*', '')
        product_data['sku'] = clean_sku
        
        # Add to the fixed products with clean key
        fixed_products[clean_sku] = product_data
        print(f"  Got: {sku} -> {clean_sku}")

# Save to JSON file
with open('products_asterisks_fixed.json', 'w') as f:
    json.dump(fixed_products, f, indent=2)

print(f"\nSaved {len(fixed_products)} fixed products to products_asterisks_fixed.json")
print("\nProducts that need to be DELETED (with asterisks):")
for sku in skus_with_asterisks:
    print(f"  - {sku}")