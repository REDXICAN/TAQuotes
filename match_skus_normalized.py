import json
import requests
import time
from datetime import datetime
import re

# Firebase database URL
FIREBASE_URL = "https://taquotes-default-rtdb.firebaseio.com"

def normalize_sku(sku):
    """Normalize SKU for matching - remove dashes, spaces, convert to uppercase"""
    if not sku:
        return ""
    # Remove dashes, spaces, and convert to uppercase
    normalized = re.sub(r'[-\s]', '', str(sku).upper())
    return normalized

# Load the inventory data
print("Loading inventory data...")
with open('mexico_warehouse_inventory.json', 'r', encoding='utf-8') as f:
    inventory_data = json.load(f)

# Get Firebase products
print("\nFetching Firebase products...")
response = requests.get(f"{FIREBASE_URL}/products.json")
existing_products = response.json() or {}

# Create normalized mappings
print("\nCreating normalized SKU mappings...")
firebase_normalized = {}  # normalized -> (original_sku, firebase_key)
inventory_normalized = {}  # normalized -> (original_sku, inventory_data)

# Map Firebase products
for firebase_key, product_data in existing_products.items():
    if product_data and isinstance(product_data, dict) and 'sku' in product_data:
        original_sku = product_data['sku']
        normalized = normalize_sku(original_sku)
        firebase_normalized[normalized] = (original_sku, firebase_key)

# Map inventory products
for sku, warehouses in inventory_data['inventory_by_product'].items():
    normalized = normalize_sku(sku)
    inventory_normalized[normalized] = (sku, warehouses)

# Find matches
print("\nFinding matches...")
matches = []
no_match_inventory = []
no_match_firebase = []

for norm_sku, (inv_sku, inv_data) in inventory_normalized.items():
    if norm_sku in firebase_normalized:
        fb_sku, fb_key = firebase_normalized[norm_sku]
        matches.append({
            'inventory_sku': inv_sku,
            'firebase_sku': fb_sku,
            'firebase_key': fb_key,
            'normalized': norm_sku,
            'warehouses': inv_data
        })
    else:
        no_match_inventory.append(inv_sku)

for norm_sku, (fb_sku, fb_key) in firebase_normalized.items():
    if norm_sku not in inventory_normalized:
        no_match_firebase.append(fb_sku)

print(f"\nResults:")
print(f"  Matches found: {len(matches)}")
print(f"  Inventory without Firebase match: {len(no_match_inventory)}")
print(f"  Firebase without inventory match: {len(no_match_firebase)}")

if matches:
    print(f"\nFirst 20 matches:")
    for match in matches[:20]:
        total = sum(match['warehouses'].values())
        print(f"  {match['inventory_sku']} <-> {match['firebase_sku']} = {total} units")
    
    # Now update Firebase with the matched inventory
    print(f"\n{'='*80}")
    print("UPDATING MATCHED PRODUCTS IN FIREBASE")
    print(f"{'='*80}")
    
    updates_count = 0
    for match in matches:
        firebase_key = match['firebase_key']
        warehouses = match['warehouses']
        
        # Prepare warehouse stock data
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
        
        # Update data
        update_data = {
            'warehouseStock': warehouse_stock,
            'totalStock': total_stock,
            'availableStock': available_stock
        }
        
        print(f"Updating {match['firebase_sku']} ({firebase_key}): {total_stock} units")
        
        # Send update to Firebase
        update_response = requests.patch(
            f"{FIREBASE_URL}/products/{firebase_key}.json",
            json=update_data
        )
        
        if update_response.status_code == 200:
            updates_count += 1
            print(f"  [OK] Updated successfully")
        else:
            print(f"  [FAIL] Failed: {update_response.status_code}")
        
        # Rate limiting
        if updates_count % 10 == 0:
            time.sleep(0.5)
    
    print(f"\n{'='*80}")
    print(f"UPDATE COMPLETE: {updates_count} products updated")
    print(f"{'='*80}")

else:
    print("\nNo matches found even with normalization!")
    print("\nSample inventory SKUs (first 10):")
    for sku in list(inventory_data['inventory_by_product'].keys())[:10]:
        print(f"  {sku} -> {normalize_sku(sku)}")
    
    print("\nSample Firebase SKUs (first 10):")
    count = 0
    for fb_key, product in existing_products.items():
        if product and 'sku' in product:
            sku = product['sku']
            print(f"  {sku} -> {normalize_sku(sku)}")
            count += 1
            if count >= 10:
                break

# Save results
with open('sku_matching_results.json', 'w', encoding='utf-8') as f:
    json.dump({
        'timestamp': datetime.now().isoformat(),
        'matches': matches,
        'match_count': len(matches),
        'no_match_inventory': no_match_inventory,
        'no_match_firebase': no_match_firebase
    }, f, ensure_ascii=False, indent=2)

print(f"\nResults saved to sku_matching_results.json")