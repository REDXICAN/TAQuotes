import json
import requests

# File with updated products including stock
json_file = r"C:\Users\andre\Downloads\taquotes-products-with-stock-final.json"

# Firebase database URL
firebase_url = "https://taquotes-default-rtdb.firebaseio.com/products.json"

print("=" * 70)
print("UPLOADING PRODUCTS WITH STOCK TO FIREBASE")
print("=" * 70)

# Load products with stock
print("\nLoading products with stock...")
with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)

print(f"Loaded {len(products)} products")

# Count products with stock
products_with_stock = sum(1 for p in products.values() if p.get('stock', 0) > 0)
total_stock = sum(p.get('stock', 0) for p in products.values())

print(f"\nProducts with stock > 0: {products_with_stock}")
print(f"Total stock units: {total_stock}")

# Show sample of products with stock
print("\nSample of products with stock:")
count = 0
for key, product in products.items():
    if product.get('stock', 0) > 0 and count < 10:
        print(f"  {product.get('sku', 'N/A')}: {product.get('stock', 0)} units")
        count += 1

print("\n" + "=" * 70)
print("IMPORTANT: Upload to Firebase")
print("=" * 70)
print("\nTo upload this data to Firebase, you have two options:")
print("\nOPTION 1 - Firebase Console (RECOMMENDED):")
print("1. Go to: https://console.firebase.google.com/project/taquotes/database")
print("2. Click on the 'products' node")
print("3. Click the three dots menu (...) next to 'products'")
print("4. Select 'Import JSON'")
print(f"5. Upload file: {json_file}")
print("\nOPTION 2 - Using Firebase CLI:")
print("firebase database:set /products taquotes-products-with-stock-final.json")
print("\nOPTION 3 - Using Python (requires authentication):")
print("You would need to set up Firebase Admin SDK with service account credentials")
print("\n" + "=" * 70)

# Create a smaller test file with just 5 products to verify
test_products = {}
count = 0
for key, product in products.items():
    if product.get('stock', 0) > 0 and count < 5:
        test_products[key] = product
        count += 1
    elif count >= 5:
        break

test_file = r"C:\Users\andre\Downloads\test-products-with-stock.json"
with open(test_file, 'w', encoding='utf-8') as f:
    json.dump(test_products, f, indent=2, ensure_ascii=False)

print(f"\nAlso created a test file with 5 products: {test_file}")
print("You can test with this smaller file first to verify the stock field works.")