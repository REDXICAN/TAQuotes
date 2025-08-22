import firebase_admin
from firebase_admin import credentials, db

# Initialize Firebase
cred = credentials.Certificate(r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json')
app = firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com'
}, name='verifier')

# Check database
ref = db.reference('products', app=app)
products = ref.get()

# Count products with each type of URL
with_p1 = 0
with_p2 = 0
with_thumb = 0
total = len(products)

print("Checking first 5 products as examples:")
print("-" * 50)
for i, (pid, p) in enumerate(products.items()):
    if i >= 5:
        break
    sku = p.get('sku', p.get('model'))
    has_p1 = 'imageUrl' in p
    has_p2 = 'imageUrl2' in p
    has_thumb = 'thumbnailUrl' in p
    
    print(f"{sku}:")
    print(f"  P.1 screenshot (imageUrl): {has_p1}")
    print(f"  P.2 screenshot (imageUrl2): {has_p2}")
    print(f"  Thumbnail: {has_thumb}")

# Count all
for pid, p in products.items():
    if 'imageUrl' in p:
        with_p1 += 1
    if 'imageUrl2' in p:
        with_p2 += 1
    if 'thumbnailUrl' in p:
        with_thumb += 1

print("\n" + "=" * 50)
print("SUMMARY:")
print(f"Total products: {total}")
print(f"Products with P.1 screenshot (imageUrl): {with_p1}")
print(f"Products with P.2 screenshot (imageUrl2): {with_p2}")
print(f"Products with thumbnail: {with_thumb}")

firebase_admin.delete_app(app)