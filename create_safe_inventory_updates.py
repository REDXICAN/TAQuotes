import json
from datetime import datetime

# Load the matching results
print("Loading SKU matches...")
with open('sku_matching_results.json', 'r', encoding='utf-8') as f:
    results = json.load(f)

matches = results['matches']
print(f"Found {len(matches)} matched products")

# Create update commands for Firebase
updates = {}
summary = []

for match in matches:
    firebase_key = match['firebase_key']
    firebase_sku = match['firebase_sku']
    inventory_sku = match['inventory_sku']
    warehouses = match['warehouses']
    
    # Calculate totals
    warehouse_stock = {}
    total_stock = 0
    available_stock = 0
    
    for warehouse_code, quantity in warehouses.items():
        is_reserved = (warehouse_code == '999')
        warehouse_stock[warehouse_code] = {
            'available': quantity,
            'reserved': quantity if is_reserved else 0,
            'lastUpdate': datetime.now().isoformat()
        }
        total_stock += quantity
        if not is_reserved:
            available_stock += quantity
    
    # Add to updates
    updates[f"products/{firebase_key}/warehouseStock"] = warehouse_stock
    updates[f"products/{firebase_key}/totalStock"] = total_stock
    updates[f"products/{firebase_key}/availableStock"] = available_stock
    
    # Add to summary
    summary.append({
        'firebase_sku': firebase_sku,
        'inventory_sku': inventory_sku,
        'firebase_key': firebase_key,
        'total_stock': total_stock,
        'available_stock': available_stock,
        'reserved_stock': warehouses.get('999', 0),
        'warehouses': list(warehouses.keys())
    })

# Save the updates to a file
with open('firebase_inventory_updates.json', 'w', encoding='utf-8') as f:
    json.dump(updates, f, ensure_ascii=False, indent=2)

print(f"\nCreated firebase_inventory_updates.json with {len(updates)} update paths")

# Save a readable summary
with open('inventory_update_summary.json', 'w', encoding='utf-8') as f:
    json.dump({
        'timestamp': datetime.now().isoformat(),
        'total_products': len(matches),
        'products': summary
    }, f, ensure_ascii=False, indent=2)

print("Created inventory_update_summary.json for review")

# Print summary
print("\n" + "="*80)
print("INVENTORY UPDATE SUMMARY")
print("="*80)
print(f"Products to update: {len(matches)}")
print(f"\nFirst 10 products:")
for item in summary[:10]:
    print(f"  {item['firebase_sku']}:")
    print(f"    Total: {item['total_stock']} units")
    print(f"    Available: {item['available_stock']} units")
    print(f"    Reserved (999): {item['reserved_stock']} units")
    print(f"    Warehouses: {', '.join(item['warehouses'])}")

print("\n" + "="*80)
print("INSTRUCTIONS TO UPDATE FIREBASE:")
print("="*80)
print("""
1. Review the files:
   - firebase_inventory_updates.json: Contains the exact updates for Firebase
   - inventory_update_summary.json: Human-readable summary

2. To apply updates in Firebase Console:
   a. Go to https://console.firebase.google.com/project/taquotes/database
   b. Click on the three dots menu → "Import JSON"
   c. Upload firebase_inventory_updates.json
   d. Choose "Merge" (NOT Replace) to add inventory without affecting other data

3. Alternative: Use Firebase CLI
   firebase database:update / firebase_inventory_updates.json

This will ONLY add inventory data to the 83 matched products.
It will NOT delete or modify any other data.
""")

# Create a smaller test file with just 5 products for testing
test_updates = dict(list(updates.items())[:15])  # 5 products × 3 fields = 15 updates
with open('firebase_inventory_test_5_products.json', 'w', encoding='utf-8') as f:
    json.dump(test_updates, f, ensure_ascii=False, indent=2)

print("Also created firebase_inventory_test_5_products.json with first 5 products for testing")