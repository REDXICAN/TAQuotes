import pandas as pd
import json

# File paths
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
json_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"

# Load JSON to get sample SKUs
print("Loading JSON products...")
with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)

# Get sample SKUs from JSON
json_skus = []
for key, product in products.items():
    if 'sku' in product:
        json_skus.append(product['sku'])
    if len(json_skus) >= 10:
        break

print(f"\nSample SKUs from JSON products:")
for sku in json_skus:
    print(f"  {sku}")

# Read Excel with different parameters
print(f"\n\nAnalyzing Excel file structure...")
print("=" * 60)

# Try different ways to read the Excel
for skip_rows in [0, 1, 2, 3, 4]:
    print(f"\n--- Reading with skiprows={skip_rows} ---")
    try:
        df = pd.read_excel(excel_file, sheet_name=0, skiprows=skip_rows)
        print(f"Shape: {df.shape}")
        print(f"Columns: {df.columns.tolist()}")
        print("\nFirst 10 rows (showing only non-null SKU-like values):")
        
        # Look for SKU-like values in the first column
        for i in range(min(10, len(df))):
            val = df.iloc[i, 0] if not pd.isna(df.iloc[i, 0]) else None
            stock = df.iloc[i, 2] if len(df.columns) > 2 and not pd.isna(df.iloc[i, 2]) else None
            
            if val and str(val).strip() and not str(val).startswith('Almac') and 'digo' not in str(val):
                # Try to clean the value
                cleaned_val = str(val).strip().replace("'", "")
                print(f"  Row {i}: SKU='{cleaned_val}', Stock={stock}")
        
    except Exception as e:
        print(f"Error: {e}")

# Now read with the best skiprows value and analyze actual data
print("\n\n" + "=" * 60)
print("Reading actual inventory data...")
df = pd.read_excel(excel_file, sheet_name=0, skiprows=2)

# Filter out header rows and empty rows
inventory_data = []
for i, row in df.iterrows():
    sku = row.iloc[0] if not pd.isna(row.iloc[0]) else None
    name = row.iloc[1] if len(df.columns) > 1 and not pd.isna(row.iloc[1]) else None
    stock = row.iloc[2] if len(df.columns) > 2 and not pd.isna(row.iloc[2]) else None
    
    if sku and str(sku).strip():
        sku_str = str(sku).strip().replace("'", "")
        # Skip header rows and non-product rows
        if (not sku_str.startswith('Almac') and 
            'digo' not in sku_str and 
            'Existencia' not in str(stock) and
            sku_str != '999' and
            len(sku_str) > 2):
            
            try:
                stock_val = int(float(str(stock))) if stock and str(stock).replace('.', '').replace('-', '').isdigit() else 0
            except:
                stock_val = 0
                
            inventory_data.append({
                'sku': sku_str,
                'name': str(name) if name else '',
                'stock': stock_val
            })

print(f"\nFound {len(inventory_data)} valid inventory items")
print("\nFirst 20 inventory items:")
for item in inventory_data[:20]:
    print(f"  SKU: {item['sku']:<20} Stock: {item['stock']}")

# Try to match with JSON SKUs
print("\n\nMatching inventory SKUs with product SKUs...")
matches = 0
for inv_item in inventory_data:
    inv_sku = inv_item['sku'].upper().replace('-', '').replace(' ', '')
    for key, product in products.items():
        if 'sku' in product:
            prod_sku = product['sku'].upper().replace('-', '').replace(' ', '')
            if inv_sku == prod_sku or inv_sku in prod_sku or prod_sku in inv_sku:
                matches += 1
                print(f"  Match found: {inv_item['sku']} -> {product['sku']} (stock: {inv_item['stock']})")
                if matches >= 10:
                    break
    if matches >= 10:
        break

if matches == 0:
    print("  No direct matches found. SKU formats might be different.")
    print("\n  Checking for partial matches...")
    
    # Try more aggressive matching
    for inv_item in inventory_data[:20]:
        for key, product in products.items():
            if 'sku' in product:
                # Check if any part of the SKUs match
                if any(part in product['sku'].upper() for part in inv_item['sku'].upper().split('-') if len(part) > 2):
                    print(f"    Partial match: {inv_item['sku']} might relate to {product['sku']}")
                    matches += 1
                    if matches >= 5:
                        break
        if matches >= 5:
            break