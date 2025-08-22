import os
import firebase_admin
from firebase_admin import credentials, storage, db
import mimetypes
from pathlib import Path

# Initialize Firebase Admin SDK
SERVICE_ACCOUNT_PATH = r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json'

# Check if service account file exists
if not os.path.exists(SERVICE_ACCOUNT_PATH):
    print("ERROR: Firebase service account key not found!")
    exit(1)

# Initialize Firebase
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com',
    'storageBucket': 'taquotes.firebasestorage.app'
})

# Get storage bucket
bucket = storage.bucket()

def upload_sample_images():
    """Upload just a few sample images to test"""
    print("Uploading sample images to Firebase Storage...")
    
    # Define sample SKUs to upload
    sample_skus = ['PRO-12R-N', 'TSR-23SD-N6', 'CRT-77-1R-N']
    
    thumbnails_path = r'C:\Users\andre\Desktop\-- Flutter App\assets\thumbnails'
    screenshots_path = r'C:\Users\andre\Desktop\-- Flutter App\assets\screenshots'
    
    uploaded_urls = []
    
    for sku in sample_skus:
        print(f"\nProcessing {sku}...")
        
        # Try thumbnails with different suffixes
        for suffix in ['_Left', '_Right', '_empty', '']:
            folder_name = f"{sku}{suffix}"
            local_thumb_path = os.path.join(thumbnails_path, folder_name, f"{folder_name}.jpg")
            
            if os.path.exists(local_thumb_path):
                storage_path = f"thumbnails/{folder_name}/{folder_name}.jpg"
                
                try:
                    blob = bucket.blob(storage_path)
                    blob.upload_from_filename(local_thumb_path)
                    
                    # Set content type
                    blob.content_type = 'image/jpeg'
                    blob.patch()
                    
                    # Make publicly accessible
                    blob.make_public()
                    
                    print(f"  [OK] Uploaded thumbnail: {storage_path}")
                    print(f"     URL: {blob.public_url}")
                    uploaded_urls.append(blob.public_url)
                    break
                except Exception as e:
                    print(f"  [FAIL] Failed thumbnail: {e}")
        
        # Try screenshot
        screenshot_path = os.path.join(screenshots_path, sku, f"{sku} P.1.png")
        if os.path.exists(screenshot_path):
            storage_path = f"screenshots/{sku}/{sku} P.1.png"
            
            try:
                blob = bucket.blob(storage_path)
                blob.upload_from_filename(screenshot_path)
                
                # Set content type
                blob.content_type = 'image/png'
                blob.patch()
                
                # Make publicly accessible
                blob.make_public()
                
                print(f"  [OK] Uploaded screenshot: {storage_path}")
                print(f"     URL: {blob.public_url}")
                uploaded_urls.append(blob.public_url)
            except Exception as e:
                print(f"  [FAIL] Failed screenshot: {e}")
    
    # Update database for these sample products
    print("\nUpdating database with URLs...")
    ref = db.reference('products')
    products = ref.get()
    
    updated_count = 0
    for product_id, product_data in products.items():
        sku = product_data.get('sku') or product_data.get('model')
        if sku in sample_skus:
            # Find URLs for this SKU
            thumbnail_url = None
            screenshot_url = None
            
            for url in uploaded_urls:
                if 'thumbnails' in url and sku in url:
                    thumbnail_url = url
                elif 'screenshots' in url and sku in url:
                    screenshot_url = url
            
            updates = {}
            if thumbnail_url:
                updates['thumbnailUrl'] = thumbnail_url
            if screenshot_url:
                updates['imageUrl'] = screenshot_url
            
            if updates:
                ref.child(product_id).update(updates)
                updated_count += 1
                print(f"  [OK] Updated {sku} in database")
    
    print(f"\nSAMPLE UPLOAD COMPLETE!")
    print(f"  - Uploaded {len(uploaded_urls)} images")
    print(f"  - Updated {updated_count} products in database")
    print(f"\nSample URLs for testing:")
    for url in uploaded_urls[:3]:
        print(f"  {url}")

if __name__ == "__main__":
    upload_sample_images()