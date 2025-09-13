import json
import pandas as pd
import re

# File paths
json_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
output_file = r"C:\Users\andre\Downloads\taquotes-products-with-stock.json"

print("=" * 70)
print("UPDATING PRODUCTS WITH STOCK FROM EXCEL")
print("=" * 70)

# Load products from JSON
print("\nLoading products from JSON...")
with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)
print(f"Total products in JSON: {len(products)}")

# Load Excel inventory data
print("\nLoading Excel inventory data...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=3)

# Extract inventory data
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
            
            # Normalize SKU for matching (remove hyphens, spaces, convert to upper)
            normalized_sku = sku_str.upper().replace('-', '').replace(' ', '')
            inventory_map[normalized_sku] = {
                'original_sku': sku_str,
                'stock': stock_val
            }

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

# Update products with stock information
print("\nMatching products with inventory...")
updated_count = 0
no_match_count = 0
match_details = []

for product_key, product_data in products.items():
    product_sku = product_data.get('sku', '')
    
    if product_sku:
        # Normalize product SKU
        normalized_product_sku = normalize_sku(product_sku)
        
        # Try to find a match in inventory
        stock_found = False
        for inv_normalized_sku, inv_data in inventory_map.items():
            # Check for exact match or if one contains the other
            if (normalized_product_sku == inv_normalized_sku or
                inv_normalized_sku in normalized_product_sku or
                normalized_product_sku in inv_normalized_sku):
                
                product_data['stock'] = inv_data['stock']
                updated_count += 1
                stock_found = True
                
                if updated_count <= 20:  # Show first 20 matches
                    match_details.append(f"  {product_sku} -> {inv_data['original_sku']} (stock: {inv_data['stock']})")
                break
        
        if not stock_found:
            # Set stock to 0 if not found
            product_data['stock'] = 0
            no_match_count += 1
    else:
        # No SKU, set stock to 0
        product_data['stock'] = 0
        no_match_count += 1

# Print match details
if match_details:
    print("\nSample matches found:")
    for detail in match_details:
        print(detail)

print(f"\n" + "=" * 70)
print(f"UPDATE SUMMARY:")
print(f"  Products updated with stock from Excel: {updated_count}")
print(f"  Products set to 0 stock (not found): {no_match_count}")
print(f"  Total products processed: {len(products)}")
print("=" * 70)

# Save updated products
print(f"\nSaving updated products to:\n{output_file}")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

print("\n[SUCCESS] Products updated with stock information!")
print(f"Output file: {output_file}")

# Show sample of final data
print("\nSample of updated products:")
sample_count = 0
for key, data in products.items():
    if sample_count < 10:
        stock_val = data.get('stock', 0)
        status = "FROM EXCEL" if stock_val > 0 else "NOT FOUND"
        print(f"  {data.get('sku', 'N/A'):<20} Stock: {stock_val:>4} [{status}]")
        sample_count += 1
    else:
        break