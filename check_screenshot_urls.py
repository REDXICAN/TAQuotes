import firebase_admin
from firebase_admin import credentials, storage, db

# Initialize Firebase
cred = credentials.Certificate(r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json')
app = firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com',
    'storageBucket': 'taquotes.firebasestorage.app'
}, name='checker3')

# Check database for screenshot URLs
ref = db.reference('products', app=app)
products = ref.order_by_key().limit_to_first(10).get()

print("Checking screenshot URLs in database:")
print("-" * 80)

for pid, product in products.items():
    sku = product.get('sku') or product.get('model')
    image_url = product.get('imageUrl')
    
    if image_url:
        print(f"{sku}: {image_url}")
    else:
        print(f"{sku}: NO SCREENSHOT URL")

# Check what's actually in storage for screenshots
bucket = storage.bucket(app=app)
print("\n\nChecking actual screenshots in Firebase Storage:")
print("-" * 80)

screenshot_count = 0
for blob in bucket.list_blobs(prefix='screenshots/'):
    screenshot_count += 1
    if screenshot_count <= 10:
        print(f"Found: {blob.name}")
    if screenshot_count == 10:
        print("...")
        
print(f"\nTotal screenshots in storage: {screenshot_count}")

# Check for P.2 files
p2_count = 0
for blob in bucket.list_blobs(prefix='screenshots/'):
    if 'P.2' in blob.name:
        p2_count += 1
        if p2_count <= 5:
            print(f"P.2 found: {blob.name}")

print(f"\nTotal P.2 screenshots: {p2_count}")

firebase_admin.delete_app(app)