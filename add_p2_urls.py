import firebase_admin
from firebase_admin import credentials, storage, db

# Initialize Firebase
cred = credentials.Certificate(r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json')
app = firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com',
    'storageBucket': 'taquotes.firebasestorage.app'
}, name='p2updater')

# Get storage bucket
bucket = storage.bucket(app=app)

print("Collecting P.2 screenshot URLs from Firebase Storage...")

# Collect all P.2 screenshots
p2_screenshots = {}
for blob in bucket.list_blobs(prefix='screenshots/'):
    if 'P.2' in blob.name:
        # Extract SKU from path
        parts = blob.name.replace('screenshots/', '').split('/')
        if len(parts) >= 1:
            sku = parts[0]
            p2_screenshots[sku] = blob.public_url
            print(f"Found P.2 for {sku}")

print(f"\nFound {len(p2_screenshots)} P.2 screenshots")

# Update database with P.2 URLs
print("\nUpdating database with P.2 screenshot URLs...")
ref = db.reference('products', app=app)
products = ref.get()

if not products:
    print("No products found in database!")
    exit(1)

updated_count = 0
for product_id, product_data in products.items():
    sku = product_data.get('sku') or product_data.get('model')
    if not sku:
        continue
    
    # Check if we have a P.2 screenshot for this SKU
    if sku in p2_screenshots:
        try:
            # Add imageUrl2 field for P.2 screenshot
            ref.child(product_id).update({
                'imageUrl2': p2_screenshots[sku]
            })
            updated_count += 1
            print(f"Updated {sku} with P.2 URL")
        except Exception as e:
            print(f"Failed to update {sku}: {e}")

print(f"\n[COMPLETE] Updated {updated_count} products with P.2 screenshot URLs")

firebase_admin.delete_app(app)