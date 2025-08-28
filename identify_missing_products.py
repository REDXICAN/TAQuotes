import pandas as pd
import json
import re

# Read Excel
excel_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\2024 List Price Norbaja Copy.xlsx"
df = pd.read_excel(excel_path, header=None)

# Extract all SKUs and prices from Excel
excel_products = {}
for idx in range(7, len(df)):
    sku = df.iloc[idx, 0]  # Column A: SKU
    price = df.iloc[idx, 1]  # Column B: Price
    
    if pd.notna(sku) and pd.notna(price):
        sku_str = str(sku).strip()
        # Filter valid SKUs
        if (sku_str and 
            '-' in sku_str and 
            len(sku_str) < 50 and
            not sku_str.startswith('*') and
            not any(word in sku_str.lower() for word in ['series', 'optional', 'available', 'please', 'display', 'back bars', 'beer', 'bottle', 'milk coolers'])):
            
            try:
                price_val = float(price)
                excel_products[sku_str] = price_val
            except:
                pass

print(f"Found {len(excel_products)} products in Excel")

# Load current database with SKU keys
with open('DATABASE_WITH_SKU_KEYS.json', 'r') as f:
    current_db = json.load(f)

# Find missing products
missing_products = {}
for sku, price in excel_products.items():
    # Clean SKU for comparison (remove parentheses content)
    base_sku = re.sub(r'\([^)]*\)', '', sku).strip()
    
    # Check if SKU exists in database
    found = False
    for db_sku in current_db.keys():
        db_base = re.sub(r'\([^)]*\)', '', db_sku).strip()
        if db_base == base_sku:
            found = True
            break
    
    if not found:
        missing_products[sku] = price

print(f"\nMissing products: {len(missing_products)}")

# Save missing products list
with open('missing_products_to_add.json', 'w') as f:
    json.dump(missing_products, f, indent=2)

# Also save as text for easy reading
with open('missing_products_list.txt', 'w') as f:
    f.write(f"=== {len(missing_products)} MISSING PRODUCTS ===\n\n")
    for sku, price in sorted(missing_products.items()):
        f.write(f"{sku}: ${price}\n")

print("\nFirst 20 missing products:")
for sku, price in list(missing_products.items())[:20]:
    print(f"  {sku}: ${price}")

print(f"\nSaved to:")
print("  - missing_products_to_add.json")
print("  - missing_products_list.txt")