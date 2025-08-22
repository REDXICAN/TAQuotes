import firebase_admin
from firebase_admin import credentials, storage, db
import time

# Initialize Firebase Admin SDK
SERVICE_ACCOUNT_PATH = r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json'

# Initialize Firebase
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com',
    'storageBucket': 'taquotes.firebasestorage.app'
})

# Get storage bucket
bucket = storage.bucket()

print("Fetching all uploaded files from Firebase Storage...")
# Get all blobs in storage
all_blobs = {}
thumbnail_blobs = {}
screenshot_blobs = {}

for blob in bucket.list_blobs():
    if 'thumbnails/' in blob.name:
        # Extract SKU from thumbnail path
        # Format: thumbnails/SKU_suffix/SKU_suffix.jpg
        parts = blob.name.replace('thumbnails/', '').split('/')
        if len(parts) >= 2:
            folder = parts[0]
            # Remove suffix to get base SKU
            sku = folder.replace('_Left', '').replace('_Right', '').replace('_empty', '').replace('_full', '')
            if sku not in thumbnail_blobs:
                thumbnail_blobs[sku] = blob.public_url
                print(f"Found thumbnail for {sku}")
    elif 'screenshots/' in blob.name:
        # Extract SKU from screenshot path
        # Format: screenshots/SKU/SKU P.1.png
        parts = blob.name.replace('screenshots/', '').split('/')
        if len(parts) >= 1:
            sku = parts[0]
            if 'P.1' in blob.name:  # Only use P.1 for imageUrl
                screenshot_blobs[sku] = blob.public_url
                print(f"Found screenshot for {sku}")

print(f"\nFound {len(thumbnail_blobs)} unique thumbnails")
print(f"Found {len(screenshot_blobs)} screenshots")

# Update database
print("\nUpdating database with URLs...")
ref = db.reference('products')
products = ref.get()

if not products:
    print("No products found in database!")
    exit(1)

updated_count = 0
batch_updates = {}

for product_id, product_data in products.items():
    sku = product_data.get('sku') or product_data.get('model')
    if not sku:
        continue
    
    updates = {}
    
    # Check if we have a thumbnail for this SKU
    if sku in thumbnail_blobs:
        updates['thumbnailUrl'] = thumbnail_blobs[sku]
    
    # Check if we have a screenshot for this SKU
    if sku in screenshot_blobs:
        updates['imageUrl'] = screenshot_blobs[sku]
    
    if updates:
        batch_updates[product_id] = updates
        updated_count += 1
        print(f"Will update {sku}: thumbnail={'thumbnailUrl' in updates}, screenshot={'imageUrl' in updates}")

# Apply all updates in batches
print(f"\nApplying {updated_count} updates to database...")
for product_id, updates in batch_updates.items():
    try:
        ref.child(product_id).update(updates)
    except Exception as e:
        print(f"Failed to update {product_id}: {e}")

print(f"\n[COMPLETE] Updated {updated_count} products with image URLs")
print(f"Products now have Firebase Storage URLs and should display images properly.")