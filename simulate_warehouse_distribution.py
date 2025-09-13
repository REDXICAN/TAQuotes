import json
import random

# Load products with stock
json_file = r"C:\Users\andre\Downloads\taquotes-complete-products-with-stock.json"

print("=" * 80)
print("SIMULATING WAREHOUSE DISTRIBUTION FOR MEXICO")
print("=" * 80)

with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)

# Mexican warehouse codes from your system
warehouses = {
    'CA': 'Cancún Main',
    'CA1': 'Cancún Exhibición', 
    'CA2': 'Cancún Equipos a Prueba',
    'CA3': 'Cancún Laboratorio',
    'CA4': 'Cancún Área de Ajuste',
    '999': 'Mercancía Apartada (Reserved)',
    'COCZ': 'Consignación Cancún Zicor',
    'COPZ': 'Consignación Puebla Zicor',
    'MEE': 'México Equipment',
    'PU': 'Puebla',
    'SI': 'Sinaloa',
    'XCA': 'Extra Cancún',
    'XPU': 'Extra Puebla'
}

# Count products with stock
products_with_stock = {k: v for k, v in products.items() if v.get('stock', 0) > 0}
print(f"\nTotal products with stock: {len(products_with_stock)}")
print(f"Total stock units: {sum(p.get('stock', 0) for p in products_with_stock.values())}")

# Simulate a realistic distribution
warehouse_distribution = {}
for code in warehouses:
    warehouse_distribution[code] = {
        'products': 0,
        'units': 0,
        'samples': []
    }

# Distribute products across warehouses (simulating what might be in Excel)
for key, product in products_with_stock.items():
    stock = product.get('stock', 0)
    if stock > 0:
        # Main warehouse gets most stock
        if stock > 5:
            # Distribute across multiple warehouses
            warehouse_distribution['CA']['products'] += 1
            warehouse_distribution['CA']['units'] += stock - 2
            
            # Some in exhibition
            if random.random() > 0.7:
                warehouse_distribution['CA1']['products'] += 1
                warehouse_distribution['CA1']['units'] += 1
            
            # Some reserved
            if random.random() > 0.8:
                warehouse_distribution['999']['products'] += 1
                warehouse_distribution['999']['units'] += 1
        else:
            # Small quantities in single warehouse
            if random.random() > 0.5:
                warehouse_distribution['CA']['products'] += 1
                warehouse_distribution['CA']['units'] += stock
            else:
                warehouse_distribution['PU']['products'] += 1
                warehouse_distribution['PU']['units'] += stock

print("\n" + "=" * 80)
print("WAREHOUSE DISTRIBUTION SUMMARY")
print("=" * 80)

for code, name in warehouses.items():
    if warehouse_distribution[code]['units'] > 0:
        print(f"\n{code} - {name}:")
        print(f"  Products: {warehouse_distribution[code]['products']}")
        print(f"  Units: {warehouse_distribution[code]['units']}")

print("\n" + "=" * 80)
print("\nNote: Since we only have simple stock totals, the dashboard will show")
print("all stock under the main warehouses. To show distributed inventory,")
print("we would need the actual warehouse columns from the Excel file.")
print("=" * 80)