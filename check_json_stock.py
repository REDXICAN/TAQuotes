import json

# Load the final JSON file
json_file = r"C:\Users\andre\Downloads\taquotes-products-with-stock-final.json"

print("=" * 70)
print("CHECKING STOCK IN FINAL JSON FILE")
print("=" * 70)

with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)

# Count products with stock
products_with_stock = []
total_stock = 0

for key, product in products.items():
    stock = product.get('stock', 0)
    if stock > 0:
        products_with_stock.append({
            'sku': product.get('sku', 'N/A'),
            'stock': stock
        })
        total_stock += stock

print(f"\nTotal products in JSON: {len(products)}")
print(f"Products with stock > 0: {len(products_with_stock)}")
print(f"Total stock units: {total_stock}")

# Sort by stock and show top 20
products_with_stock.sort(key=lambda x: x['stock'], reverse=True)

print(f"\nTOP 20 PRODUCTS BY STOCK IN JSON FILE:")
print("-" * 50)
for i, item in enumerate(products_with_stock[:20], 1):
    print(f"{i:2}. {item['sku']:<25} Stock: {item['stock']}")

print(f"\n[CONFIRMED] The JSON file has {len(products_with_stock)} products with stock updated.")
print(f"File location: {json_file}")