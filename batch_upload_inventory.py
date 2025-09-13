import json
import subprocess
import time

# Load the inventory data
with open('firebase_inventory_update.json', 'r', encoding='utf-8') as f:
    inventory_updates = json.load(f)

print(f"Starting batch upload of {len(inventory_updates)} products to Firebase...")
print("="*80)

# Counter for progress
success_count = 0
error_count = 0
errors = []

# Process each product
for i, (sku, data) in enumerate(inventory_updates.items(), 1):
    try:
        # Prepare the update data
        update_data = {
            'warehouseStock': data['warehouseStock'],
            'totalStock': data['totalStock'],
            'availableStock': data['availableStock']
        }
        
        # Convert to JSON string for command line
        json_str = json.dumps(update_data).replace('"', '\\"').replace('$', '\\$')
        
        # Build the Firebase CLI command
        cmd = f'firebase database:update "/products/{sku}" "{json_str}"'
        
        # Execute the command
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            success_count += 1
            print(f"[{i}/{len(inventory_updates)}] ✓ Updated {sku}")
        else:
            error_count += 1
            errors.append(f"{sku}: {result.stderr}")
            print(f"[{i}/{len(inventory_updates)}] ✗ Failed {sku}: {result.stderr[:50]}")
        
        # Rate limiting to avoid overwhelming Firebase
        if i % 10 == 0:
            time.sleep(1)
            
    except Exception as e:
        error_count += 1
        errors.append(f"{sku}: {str(e)}")
        print(f"[{i}/{len(inventory_updates)}] ✗ Error {sku}: {str(e)[:50]}")
    
    # Progress update every 50 items
    if i % 50 == 0:
        print(f"\nProgress: {i}/{len(inventory_updates)} products processed")
        print(f"Success: {success_count}, Errors: {error_count}\n")

# Final summary
print("\n" + "="*80)
print("UPLOAD COMPLETE")
print("="*80)
print(f"Total products processed: {len(inventory_updates)}")
print(f"Successfully updated: {success_count}")
print(f"Errors: {error_count}")

if errors:
    print("\nErrors encountered:")
    for error in errors[:10]:  # Show first 10 errors
        print(f"  - {error}")
    if len(errors) > 10:
        print(f"  ... and {len(errors) - 10} more errors")
    
    # Save errors to file
    with open('inventory_upload_errors.log', 'w') as f:
        for error in errors:
            f.write(f"{error}\n")
    print("\nFull error log saved to inventory_upload_errors.log")