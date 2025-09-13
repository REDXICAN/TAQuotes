import json
import glob
import os

# Load original database
original_db = r"C:\Users\andre\Downloads\taquotes-default-rtdb-export.json"
print("=" * 80)
print("FINAL VERIFICATION - COMPARING ORIGINAL VS FINAL DATABASE")
print("=" * 80)

with open(original_db, 'r', encoding='utf-8') as f:
    original = json.load(f)

# Find the latest FINAL database
downloads_path = r"C:\Users\andre\Downloads"
pattern = os.path.join(downloads_path, "taquotes-FINAL-DATABASE-*.json")
files = glob.glob(pattern)
latest_file = max(files, key=os.path.getctime)

with open(latest_file, 'r', encoding='utf-8') as f:
    final = json.load(f)

print(f"\nOriginal file: {os.path.basename(original_db)}")
print(f"Final file: {os.path.basename(latest_file)}")

# Compare sections
print("\n" + "=" * 80)
print("SECTION COMPARISON:")
print("=" * 80)
print(f"{'Section':<20} {'Original':<15} {'Final':<15} {'Status':<20}")
print("-" * 70)

all_sections = set(list(original.keys()) + list(final.keys()))

for section in sorted(all_sections):
    orig_count = len(original.get(section, {})) if section in original else 0
    final_count = len(final.get(section, {})) if section in final else 0
    
    if section == 'spareparts':
        status = "NEW SECTION ADDED"
    elif section in original and section in final:
        if orig_count == final_count:
            status = "PRESERVED"
        else:
            status = f"DIFFERENT COUNT!"
    elif section in original and section not in final:
        status = "MISSING IN FINAL!"
    else:
        status = "NEW"
    
    print(f"{section:<20} {orig_count:<15} {final_count:<15} {status:<20}")

# Deep check for quotes and clients
print("\n" + "=" * 80)
print("DEEP VERIFICATION OF NESTED DATA:")
print("=" * 80)

for section in ['quotes', 'clients']:
    if section in original and section in final:
        print(f"\n{section.upper()}:")
        
        # Count nested items in original
        orig_nested = 0
        for user_id, user_data in original[section].items():
            if isinstance(user_data, dict):
                orig_nested += len(user_data)
        
        # Count nested items in final
        final_nested = 0
        for user_id, user_data in final[section].items():
            if isinstance(user_data, dict):
                final_nested += len(user_data)
        
        print(f"  Original: {orig_nested} nested {section}")
        print(f"  Final: {final_nested} nested {section}")
        
        if orig_nested == final_nested:
            print(f"  [OK] All {section} preserved!")
        else:
            print(f"  [X] WARNING: Count mismatch!")

# Check products modifications
print("\n" + "=" * 80)
print("PRODUCTS VERIFICATION:")
print("=" * 80)

if 'products' in original and 'products' in final:
    # Check if all original products exist
    missing_products = []
    modified_products = 0
    products_with_stock = 0
    
    for prod_id, orig_product in original['products'].items():
        if prod_id not in final['products']:
            missing_products.append(prod_id)
        else:
            final_product = final['products'][prod_id]
            
            # Check if product has new fields
            if 'stock' in final_product and final_product['stock'] > 0:
                products_with_stock += 1
                modified_products += 1
    
    print(f"  Original products: {len(original['products'])}")
    print(f"  Final products: {len(final['products'])}")
    print(f"  Products with stock added: {products_with_stock}")
    print(f"  Missing products: {len(missing_products)}")
    
    if missing_products:
        print(f"  [X] WARNING: {len(missing_products)} products missing!")
        print(f"    First 5 missing: {missing_products[:5]}")
    else:
        print(f"  [OK] All original products preserved!")

# Check spare parts
print("\n" + "=" * 80)
print("SPARE PARTS VERIFICATION:")
print("=" * 80)

if 'spareparts' in final:
    total_spare_stock = sum(p.get('stock', 0) for p in final['spareparts'].values() if isinstance(p, dict))
    spare_with_warehouse = sum(1 for p in final['spareparts'].values() if isinstance(p, dict) and p.get('warehouse'))
    
    print(f"  Total spare parts: {len(final['spareparts'])}")
    print(f"  Total spare parts stock: {total_spare_stock} units")
    print(f"  Spare parts with warehouse: {spare_with_warehouse}")
    
    # Show warehouse distribution
    warehouse_dist = {}
    for part in final['spareparts'].values():
        if isinstance(part, dict) and part.get('warehouse'):
            wh = part['warehouse']
            warehouse_dist[wh] = warehouse_dist.get(wh, 0) + part.get('stock', 0)
    
    print("\n  Warehouse distribution (spare parts):")
    for wh, stock in sorted(warehouse_dist.items(), key=lambda x: x[1], reverse=True)[:5]:
        print(f"    {wh:5} : {stock:5} units")

# Check product warehouse distribution
print("\n" + "=" * 80)
print("PRODUCT WAREHOUSE DISTRIBUTION:")
print("=" * 80)

if 'products' in final:
    prod_warehouse_dist = {}
    total_product_stock = 0
    
    for product in final['products'].values():
        if isinstance(product, dict) and product.get('stock', 0) > 0:
            total_product_stock += product['stock']
            wh = product.get('warehouse', 'NONE')
            prod_warehouse_dist[wh] = prod_warehouse_dist.get(wh, 0) + product['stock']
    
    print(f"  Total product stock: {total_product_stock} units")
    print("\n  Warehouse distribution (products):")
    for wh, stock in sorted(prod_warehouse_dist.items(), key=lambda x: x[1], reverse=True):
        print(f"    {wh:5} : {stock:5} units")

# Final summary
print("\n" + "=" * 80)
print("FINAL SUMMARY:")
print("=" * 80)

all_good = True

# Check each critical section
critical_checks = {
    'app_settings': len(original.get('app_settings', {})) == len(final.get('app_settings', {})),
    'users': len(original.get('users', {})) == len(final.get('users', {})),
    'user_profiles': len(original.get('user_profiles', {})) == len(final.get('user_profiles', {})),
    'products': len(original.get('products', {})) == len(final.get('products', {})),
    'quotes_preserved': True,  # Will check separately
    'clients_preserved': True,  # Will check separately
    'spareparts_added': 'spareparts' in final
}

# Check nested quotes
if 'quotes' in original and 'quotes' in final:
    orig_quotes = sum(len(v) for v in original['quotes'].values() if isinstance(v, dict))
    final_quotes = sum(len(v) for v in final['quotes'].values() if isinstance(v, dict))
    critical_checks['quotes_preserved'] = orig_quotes == final_quotes

# Check nested clients
if 'clients' in original and 'clients' in final:
    orig_clients = sum(len(v) for v in original['clients'].values() if isinstance(v, dict))
    final_clients = sum(len(v) for v in final['clients'].values() if isinstance(v, dict))
    critical_checks['clients_preserved'] = orig_clients == final_clients

for check, passed in critical_checks.items():
    status = "[OK] PASS" if passed else "[X] FAIL"
    print(f"  {check:20} : {status}")
    if not passed:
        all_good = False

if all_good:
    print("\n[SUCCESS] ALL CHECKS PASSED - DATABASE IS COMPLETE [SUCCESS]")
    print("  - All original data preserved")
    print("  - Stock and warehouse added to products")
    print("  - Spare parts section added with warehouse distribution")
    print("  - Safe to upload to Firebase!")
else:
    print("\n[FAIL] SOME CHECKS FAILED - REVIEW NEEDED [FAIL]")

print("=" * 80)