import pandas as pd
import json

# Read the Excel file
df = pd.read_excel('D:/Flutter App/09.12.25 INVENTARIO MEXICO.xlsx', sheet_name='INVENTARIOS')

print("DataFrame shape:", df.shape)
print("\nFirst 30 rows to understand structure:")
print(df.head(30).to_string())

print("\n" + "="*80)
print("Analyzing structure...")

# Look for warehouse markers
print("\nRows containing 'Almac' or warehouse indicators:")
for idx, row in df.iterrows():
    row_str = ' '.join([str(x) for x in row if pd.notna(x)])
    if 'almac' in row_str.lower() or '999' in row_str:
        print(f"Row {idx}: {row.tolist()}")

# Based on the data shown, it seems like '999 MERCANCIA APARTADA' might be a warehouse
# Let's extract all product data
print("\n" + "="*80)
print("Extracting product inventory...")

inventory = {}
# Skip header rows and start from actual data
data_start = False
for idx, row in df.iterrows():
    if idx < 7:  # Skip header rows
        continue
    
    sku = str(row.iloc[0]).strip() if pd.notna(row.iloc[0]) else None
    stock = row.iloc[2]
    
    if sku and pd.notna(stock):
        # Clean SKU
        sku = sku.replace("'", "").strip()
        # Skip non-product rows
        if not any(word in sku.lower() for word in ['almac', 'código', 'nombre', 'existencia', 'inventario']):
            try:
                stock_int = int(float(stock))
                inventory[sku] = stock_int
            except (ValueError, TypeError):
                pass

print(f"\nTotal products with inventory: {len(inventory)}")
print("\nFirst 20 products:")
for i, (sku, stock) in enumerate(list(inventory.items())[:20]):
    print(f"  {sku}: {stock} units")

# Save the inventory data
output = {
    'warehouse': 'MEXICO',  # Single warehouse for Mexico location
    'inventory': inventory,
    'total_products': len(inventory)
}

with open('mexico_inventory_clean.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

print(f"\nData saved to mexico_inventory_clean.json")