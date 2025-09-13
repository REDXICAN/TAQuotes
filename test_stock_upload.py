import json

# Create a test file with just 10 products with varying stock levels
test_products = {
    "TEST-STOCK-001": {
        "sku": "TEST-STOCK-001",
        "model": "TEST-001",
        "name": "Test Product High Stock",
        "displayName": "Test High Stock",
        "description": "Product with 100 stock",
        "category": "Test",
        "price": 100.00,
        "stock": 100,
        "createdAt": "2025-01-01T00:00:00",
        "updatedAt": "2025-01-01T00:00:00"
    },
    "TEST-STOCK-002": {
        "sku": "TEST-STOCK-002", 
        "model": "TEST-002",
        "name": "Test Product Medium Stock",
        "displayName": "Test Medium Stock",
        "description": "Product with 50 stock",
        "category": "Test",
        "price": 200.00,
        "stock": 50,
        "createdAt": "2025-01-01T00:00:00",
        "updatedAt": "2025-01-01T00:00:00"
    },
    "TEST-STOCK-003": {
        "sku": "TEST-STOCK-003",
        "model": "TEST-003",
        "name": "Test Product Low Stock",
        "displayName": "Test Low Stock",
        "description": "Product with 10 stock",
        "category": "Test",
        "price": 300.00,
        "stock": 10,
        "createdAt": "2025-01-01T00:00:00",
        "updatedAt": "2025-01-01T00:00:00"
    },
    "TEST-STOCK-004": {
        "sku": "TEST-STOCK-004",
        "model": "TEST-004",
        "name": "Test Product No Stock",
        "displayName": "Test No Stock",
        "description": "Product with 0 stock",
        "category": "Test",
        "price": 400.00,
        "stock": 0,
        "createdAt": "2025-01-01T00:00:00",
        "updatedAt": "2025-01-01T00:00:00"
    },
    "TEST-STOCK-005": {
        "sku": "TEST-STOCK-005",
        "model": "TEST-005",
        "name": "Test Product Very High Stock",
        "displayName": "Test Very High Stock",
        "description": "Product with 500 stock",
        "category": "Test",
        "price": 500.00,
        "stock": 500,
        "createdAt": "2025-01-01T00:00:00",
        "updatedAt": "2025-01-01T00:00:00"
    }
}

# Save test file
test_file = r"C:\Users\andre\Downloads\test-stock-products.json"
with open(test_file, 'w', encoding='utf-8') as f:
    json.dump(test_products, f, indent=2, ensure_ascii=False)

print("=" * 70)
print("TEST PRODUCTS WITH STOCK CREATED")
print("=" * 70)
print(f"\nCreated {len(test_products)} test products with varying stock levels:")
for key, product in test_products.items():
    print(f"  {product['sku']}: {product['stock']} units")

print(f"\nFile saved to: {test_file}")
print("\nTo test stock sorting:")
print("1. Upload this file to Firebase at the /products node")
print("2. Check if these products appear at the top sorted by stock")
print("3. Expected order: TEST-STOCK-005 (500), TEST-STOCK-001 (100), TEST-STOCK-002 (50), TEST-STOCK-003 (10), TEST-STOCK-004 (0)")

print("\n" + "=" * 70)
print("ALTERNATIVE: Check existing products")
print("=" * 70)
print("\nOr check if your existing products have stock in Firebase:")
print("1. Go to https://console.firebase.google.com/project/taquotes/database")
print("2. Click on 'products' node")
print("3. Check any product (e.g., TWR-28SD-N)")
print("4. Look for 'stock' field - it should show a number")
print("\nIf 'stock' field is missing, you need to upload the updated JSON file.")