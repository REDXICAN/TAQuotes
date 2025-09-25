import subprocess
import json

print("Fetching current database structure...")
print("\nATTEMPT 1: Using firebase CLI to get products...")

# Try to get products
result = subprocess.run(
    ['firebase', 'database:get', '/products'],
    capture_output=True,
    text=True,
    shell=True
)

if result.returncode == 0 and result.stdout:
    try:
        products = json.loads(result.stdout)
        if products:
            keys = list(products.keys())[:10]
            print(f"\nCurrent Firebase product keys (first 10):")
            for key in keys:
                sku = products[key].get('sku', 'No SKU')
                print(f"  Key: {key} -> SKU: {sku}")

            print(f"\nTotal products in Firebase: {len(products)}")

            # Check key format
            if keys and keys[0].startswith('product_'):
                print("\n✓ Database uses product_XXXX format (CORRECT)")
            else:
                print(f"\n⚠ Database uses different format: {keys[0] if keys else 'No keys'}")
    except:
        print("Could not parse Firebase response")
else:
    print("Could not fetch from Firebase. You may need to:")
    print("1. Manually check Firebase Console at:")
    print("   https://console.firebase.google.com/project/taquotes/database")
    print("2. Look at the products node to see the key format")
    print("3. Keys should be: product_0000, product_0001, etc.")