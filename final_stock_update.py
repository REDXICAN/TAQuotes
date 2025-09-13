import json
import pandas as pd
import re

# File paths
json_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
output_file = r"C:\Users\andre\Downloads\taquotes-products-with-stock-final.json"

print("=" * 70)
print("FINAL STOCK UPDATE - ALL PRODUCTS")
print("=" * 70)

# Load products from JSON
print("\nLoading products from JSON...")
with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)
print(f"Total products in JSON: {len(products)}")

# Load Excel inventory data
print("\nLoading Excel inventory data...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract inventory data - create a normalized map
inventory_map = {}
for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    stock = row.iloc[2] if len(df.columns) > 2 else None
    
    if sku and str(sku).strip():
        sku_str = str(sku).strip().replace("'", "")
        # Skip non-product rows
        if (not sku_str.startswith('Almac') and 
            'digo' not in sku_str and 
            sku_str != '999' and
            len(sku_str) > 2):
            
            try:
                # Convert stock to integer
                if pd.notna(stock):
                    stock_val = int(float(str(stock)))
                else:
                    stock_val = 0
            except:
                stock_val = 0
            
            # Store with normalized key for matching
            normalized_sku = sku_str.upper().replace('-', '').replace(' ', '')
            inventory_map[normalized_sku] = stock_val

print(f"Found {len(inventory_map)} items in Excel inventory")

# Function to normalize SKU for matching
def normalize_sku(sku):
    """Normalize SKU by removing hyphens, spaces, parentheses and converting to uppercase"""
    if not sku:
        return ""
    # Remove common suffixes and special characters
    normalized = sku.upper()
    normalized = re.sub(r'[-()\s]', '', normalized)
    # Remove common suffixes like AL, AR
    normalized = re.sub(r'(AL|AR)$', '', normalized)
    return normalized

# Update ALL products
print("\nUpdating all products...")
updated_count = 0
zero_count = 0

for product_key, product_data in products.items():
    product_sku = product_data.get('sku', '')
    
    if product_sku:
        # Normalize product SKU
        normalized_product_sku = normalize_sku(product_sku)
        
        # Try to find a match in inventory
        stock_found = False
        for inv_normalized_sku, stock_val in inventory_map.items():
            # Check for exact match or if one contains the other
            if (normalized_product_sku == inv_normalized_sku or
                inv_normalized_sku in normalized_product_sku or
                normalized_product_sku in inv_normalized_sku):
                
                product_data['stock'] = stock_val
                if stock_val > 0:
                    updated_count += 1
                else:
                    zero_count += 1
                stock_found = True
                break
        
        if not stock_found:
            # Set stock to 0 if not found in Excel
            product_data['stock'] = 0
            zero_count += 1
    else:
        # No SKU, set stock to 0
        product_data['stock'] = 0
        zero_count += 1

print(f"\n" + "=" * 70)
print(f"UPDATE COMPLETE:")
print(f"  Products with stock > 0: {updated_count}")
print(f"  Products with stock = 0: {zero_count}")
print(f"  Total products processed: {len(products)}")
print("=" * 70)

# Save updated products
print(f"\nSaving final updated products to:\n{output_file}")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

print("\n[SUCCESS] All products updated with stock information!")
print("Products not found in Excel have been set to stock = 0")

# Show summary
total_stock = sum(p.get('stock', 0) for p in products.values())
print(f"\nFINAL SUMMARY:")
print(f"  Total products: {len(products)}")
print(f"  Products with stock: {updated_count}")
print(f"  Products without stock: {zero_count}")
print(f"  Total stock units: {total_stock}")

# Show sample
print("\nSample of products (first 15):")
for i, (key, data) in enumerate(products.items()):
    if i >= 15:
        break
    stock_val = data.get('stock', 0)
    status = f"Stock: {stock_val}"
    print(f"  {data.get('sku', 'N/A'):<20} {status}")

print(f"\nOutput saved to: {output_file}")