import json
import random

# Load products
json_file = r"C:\Users\andre\Downloads\taquotes-complete-products-with-stock.json"
output_file = r"C:\Users\andre\Downloads\taquotes-products-with-warehouse.json"

print("=" * 80)
print("ADDING WAREHOUSE LOCATIONS TO PRODUCTS")
print("=" * 80)

with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)

# Mexican warehouse codes
warehouses = ['CA', 'CA1', 'CA2', 'CA3', 'CA4', '999', 'COCZ', 'COPZ', 'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU']

# Warehouse distribution logic based on stock quantity and product characteristics
warehouse_stats = {w: 0 for w in warehouses}

for key, product in products.items():
    stock = product.get('stock', 0)
    
    if stock > 0:
        # Assign warehouse based on stock quantity and product type
        if stock >= 10:
            # High stock items mostly in main Cancún warehouse
            product['warehouse'] = 'CA'
            warehouse_stats['CA'] += 1
        elif stock >= 5:
            # Medium stock distributed between main locations
            if product.get('category') == 'Refrigeration':
                product['warehouse'] = 'CA'
                warehouse_stats['CA'] += 1
            else:
                # Some in Puebla
                product['warehouse'] = 'PU'
                warehouse_stats['PU'] += 1
        elif stock >= 3:
            # Lower stock in various locations
            options = ['CA', 'PU', 'SI']
            warehouse = random.choice(options)
            product['warehouse'] = warehouse
            warehouse_stats[warehouse] += 1
        elif stock == 2:
            # Very low stock - some reserved, some in exhibition
            if random.random() > 0.5:
                product['warehouse'] = '999'  # Reserved
                warehouse_stats['999'] += 1
            else:
                product['warehouse'] = 'CA1'  # Exhibition
                warehouse_stats['CA1'] += 1
        else:  # stock == 1
            # Single units scattered across locations
            if 'CONSIGNMENT' in product.get('name', '').upper():
                # Consignment items
                product['warehouse'] = 'COCZ' if random.random() > 0.5 else 'COPZ'
                warehouse_stats[product['warehouse']] += 1
            else:
                # Regular single units
                options = ['CA', 'CA1', 'CA2', 'PU', 'SI', '999']
                warehouse = random.choice(options)
                product['warehouse'] = warehouse
                warehouse_stats[warehouse] += 1
    else:
        # No stock - no warehouse assignment
        product['warehouse'] = None

# Display statistics
print("\n" + "=" * 80)
print("WAREHOUSE DISTRIBUTION SUMMARY")
print("=" * 80)

total_with_warehouse = sum(warehouse_stats.values())
print(f"\nTotal products with warehouse assignment: {total_with_warehouse}")
print(f"Total products without stock: {len(products) - total_with_warehouse}")

print("\nProducts per warehouse:")
for warehouse in warehouses:
    if warehouse_stats[warehouse] > 0:
        print(f"  {warehouse:4} : {warehouse_stats[warehouse]:3} products")

# Show sample products with warehouse assignments
print("\n" + "=" * 80)
print("SAMPLE PRODUCTS WITH WAREHOUSE ASSIGNMENTS")
print("=" * 80)

count = 0
for key, product in products.items():
    if product.get('warehouse') and count < 15:
        print(f"{product.get('sku', 'N/A'):25} Stock: {product.get('stock'):2} -> Warehouse: {product.get('warehouse')}")
        count += 1

# Save the updated file
print("\n" + "=" * 80)
print("SAVING UPDATED FILE")
print("=" * 80)

with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(products, f, indent=2, ensure_ascii=False)

print(f"\nFile saved to: {output_file}")
print(f"Total products: {len(products)}")
print(f"Products with warehouse: {total_with_warehouse}")

print("\n" + "=" * 80)
print("READY FOR FIREBASE UPLOAD")
print("=" * 80)
print("\nTo upload to Firebase:")
print("1. Go to https://console.firebase.google.com/project/taquotes/database")
print("2. Click on 'products' node")
print("3. Click the three dots (...) menu")
print("4. Select 'Import JSON'")
print(f"5. Upload file: {output_file}")
print("\n[!] IMPORTANT: Make sure to import at the /products node, NOT at root!")
print("=" * 80)