import pandas as pd
import json

# Read the Excel file
df = pd.read_excel('D:/Flutter App/09.12.25 INVENTARIO MEXICO.xlsx', sheet_name='INVENTARIOS')

# Find warehouse indicators
warehouses = []
current_warehouse = None
inventory_data = {}

for idx, row in df.iterrows():
    # Check if this row indicates a warehouse
    if pd.notna(row.iloc[0]) and 'Almac' in str(row.iloc[0]):
        current_warehouse = str(row.iloc[0]).replace('Almacén:', '').strip()
        if current_warehouse and current_warehouse != 'nan':
            warehouses.append(current_warehouse)
            inventory_data[current_warehouse] = {}
    
    # Check if this looks like a product row (has SKU and stock count)
    elif current_warehouse and pd.notna(row.iloc[0]) and pd.notna(row.iloc[2]):
        try:
            sku = str(row.iloc[0]).strip()
            stock = float(row.iloc[2])
            # Skip header rows and non-product rows
            if sku and not any(word in sku.lower() for word in ['código', 'nombre', 'existencia', 'almac']):
                # Remove quotes if present
                sku = sku.replace("'", "").strip()
                if sku and sku != 'nan':
                    inventory_data[current_warehouse][sku] = int(stock)
        except (ValueError, TypeError):
            pass

# Print results
print("WAREHOUSES FOUND:")
for wh in warehouses:
    print(f"  - {wh}")

print(f"\nTotal warehouses: {len(warehouses)}")

# Count products per warehouse
print("\nProducts per warehouse:")
for wh, products in inventory_data.items():
    print(f"  {wh}: {len(products)} products")

# Sample of inventory data
print("\nSample inventory data (first 5 products per warehouse):")
for wh, products in inventory_data.items():
    print(f"\n{wh}:")
    for i, (sku, stock) in enumerate(list(products.items())[:5]):
        print(f"  {sku}: {stock} units")

# Save to JSON for reference
with open('mexico_inventory_data.json', 'w', encoding='utf-8') as f:
    json.dump({
        'warehouses': warehouses,
        'inventory': inventory_data,
        'total_products': sum(len(products) for products in inventory_data.values())
    }, f, ensure_ascii=False, indent=2)

print("\nData saved to mexico_inventory_data.json")