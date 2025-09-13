import pandas as pd
import json

# Read the Excel file
df = pd.read_excel('D:/Flutter App/09.12.25 INVENTARIO MEXICO.xlsx', sheet_name='INVENTARIOS')

print("Extracting warehouse inventory data...")

# Warehouse mapping
warehouse_map = {
    "'999": '999',  # Mercancía Apartada
    'CA1': 'CA1',   # Cancún Exhibición
    'CA': 'CA',     # Cancún
    'CA2': 'CA2',   # Cancún Equipos a Prueba
    'CA3': 'CA3',   # Cancún Laboratorio
    'CA4': 'CA4',   # Cancún Área de Ajuste
    'COCZ': 'COCZ', # Consignación Cancún Zicor
    'COPZ': 'COPZ', # Consignación Puebla Zicor
    'INT': 'INT',   # Internacional
    'MEE': 'MEE',   # México Proyectos Especiales
    'PU': 'PU',     # Puebla BINEX
    'SI': 'SI',     # Silao BINEX
    'XCA': 'XCA',   # Refrigeration X Cancún
    'XPU': 'XPU',   # Refrigeration X Puebla
}

# Initialize inventory structure
inventory_by_warehouse = {wh: {} for wh in warehouse_map.values()}
current_warehouse = None
inventory_by_product = {}

# Process each row
for idx, row in df.iterrows():
    # Check if this row indicates a warehouse
    row_str = str(row.iloc[0]) if pd.notna(row.iloc[0]) else ''
    
    # Check for warehouse markers
    if 'Almac' in row_str:
        # Next row should have warehouse code
        continue
    
    # Check if this is a warehouse code row
    found_warehouse = False
    for wh_key, wh_code in warehouse_map.items():
        if row_str.strip().startswith(wh_key):
            current_warehouse = wh_code
            found_warehouse = True
            print(f"Found warehouse: {wh_code}")
            break
    
    if found_warehouse:
        continue
    
    # Skip header rows and empty rows
    if idx < 7 or not current_warehouse:
        continue
    
    # Check if this is a product row
    sku = str(row.iloc[0]).strip() if pd.notna(row.iloc[0]) else None
    stock = row.iloc[2]
    
    if sku and pd.notna(stock):
        # Clean SKU
        sku = sku.replace("'", "").strip()
        
        # Skip non-product rows
        if not any(word in sku.lower() for word in ['almac', 'código', 'nombre', 'existencia', 'inventario', 'total']):
            try:
                stock_int = int(float(stock))
                if stock_int > 0:  # Only track items with stock
                    # Add to current warehouse
                    inventory_by_warehouse[current_warehouse][sku] = stock_int
                    
                    # Add to product summary
                    if sku not in inventory_by_product:
                        inventory_by_product[sku] = {}
                    inventory_by_product[sku][current_warehouse] = stock_int
                    
            except (ValueError, TypeError):
                pass

# Print summary
print("\n" + "="*80)
print("INVENTORY SUMMARY BY WAREHOUSE:")
for wh_code in warehouse_map.values():
    products = inventory_by_warehouse[wh_code]
    if products:
        total_units = sum(products.values())
        print(f"\n{wh_code} ({len(products)} products, {total_units} total units):")
        # Show first 5 products
        for i, (sku, stock) in enumerate(list(products.items())[:5]):
            print(f"  {sku}: {stock} units")
        if len(products) > 5:
            print(f"  ... and {len(products) - 5} more products")

print("\n" + "="*80)
print(f"TOTAL UNIQUE PRODUCTS: {len(inventory_by_product)}")
print("\nSample products with multi-warehouse stock:")
multi_warehouse_products = {sku: wh for sku, wh in inventory_by_product.items() if len(wh) > 1}
for i, (sku, warehouses) in enumerate(list(multi_warehouse_products.items())[:10]):
    print(f"\n{sku}:")
    for wh, stock in warehouses.items():
        print(f"  {wh}: {stock} units")

# Save to JSON
output = {
    'warehouses': list(warehouse_map.values()),
    'inventory_by_warehouse': inventory_by_warehouse,
    'inventory_by_product': inventory_by_product,
    'total_products': len(inventory_by_product),
    'total_warehouses': len([wh for wh in inventory_by_warehouse if inventory_by_warehouse[wh]])
}

with open('mexico_warehouse_inventory.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

print(f"\nData saved to mexico_warehouse_inventory.json")

# Create a simplified format for Firebase
firebase_products = []
for sku, warehouses in inventory_by_product.items():
    product_data = {
        'sku': sku,
        'warehouseStock': warehouses,
        'totalStock': sum(warehouses.values())
    }
    firebase_products.append(product_data)

with open('firebase_inventory_update.json', 'w', encoding='utf-8') as f:
    json.dump(firebase_products, f, ensure_ascii=False, indent=2)

print(f"Firebase format saved to firebase_inventory_update.json")