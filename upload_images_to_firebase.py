import os
import firebase_admin
from firebase_admin import credentials, storage, db
import mimetypes
from pathlib import Path
import time

# Initialize Firebase Admin SDK
SERVICE_ACCOUNT_PATH = r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json'

# Check if service account file exists
if not os.path.exists(SERVICE_ACCOUNT_PATH):
    print("ERROR: Firebase service account key not found!")
    print("Please download it from Firebase Console:")
    print("1. Go to https://console.firebase.google.com/project/taquotes/settings/serviceaccounts/adminsdk")
    print("2. Click 'Generate New Private Key'")
    print("3. Save it as 'firebase-admin-key.json' in the Flutter App folder")
    exit(1)

# Initialize Firebase
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com',
    'storageBucket': 'taquotes.firebasestorage.app'
})

# Get storage bucket
bucket = storage.bucket()

def upload_images_from_folder(local_folder, storage_folder):
    """Upload all images from a local folder to Firebase Storage"""
    uploaded_count = 0
    failed_count = 0
    skipped_count = 0
    
    # Get all image files
    image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
    
    for root, dirs, files in os.walk(local_folder):
        for file in files:
            file_path = os.path.join(root, file)
            file_ext = Path(file).suffix.lower()
            
            if file_ext in image_extensions:
                # Create storage path maintaining folder structure
                relative_path = os.path.relpath(file_path, local_folder)
                storage_path = f"{storage_folder}/{relative_path}".replace('\\', '/')
                
                try:
                    # Check if file already exists in storage
                    blob = bucket.blob(storage_path)
                    if blob.exists():
                        print(f"[SKIP] Already exists: {storage_path}")
                        skipped_count += 1
                        continue
                    
                    # Upload file
                    blob.upload_from_filename(file_path)
                    
                    # Set content type
                    content_type, _ = mimetypes.guess_type(file_path)
                    if content_type:
                        blob.content_type = content_type
                        blob.patch()
                    
                    # Make publicly accessible
                    blob.make_public()
                    
                    uploaded_count += 1
                    print(f"[OK] Uploaded: {storage_path}")
                    
                    # Rate limiting to avoid overwhelming the API
                    if uploaded_count % 10 == 0:
                        print(f"   Progress: {uploaded_count} uploaded, {skipped_count} skipped...")
                        time.sleep(1)  # Brief pause every 10 uploads
                        
                except Exception as e:
                    print(f"[FAIL] Failed: {storage_path} - Error: {e}")
                    failed_count += 1
    
    return uploaded_count, failed_count, skipped_count

def update_product_image_urls():
    """Update products in database with Firebase Storage URLs"""
    print("\n[INFO] Updating product database with image URLs...")
    
    # Get all products from database
    ref = db.reference('products')
    products = ref.get()
    
    if not products:
        print("No products found in database!")
        return
    
    updated_count = 0
    
    for product_id, product_data in products.items():
        sku = product_data.get('sku') or product_data.get('model')
        if not sku:
            continue
        
        # Generate Firebase Storage URLs for this product
        # Check for thumbnail with various suffixes
        thumbnail_url = None
        screenshot_url = None
        
        # Try to find thumbnail
        for suffix in ['_Left', '_Right', '_empty', '']:
            folder_name = f"{sku}{suffix}"
            blob_path = f"thumbnails/{folder_name}/{folder_name}.jpg"
            blob = bucket.blob(blob_path)
            
            if blob.exists():
                thumbnail_url = blob.public_url
                break
        
        # Try to find screenshot
        screenshot_blob_path = f"screenshots/{sku}/{sku} P.1.png"
        screenshot_blob = bucket.blob(screenshot_blob_path)
        if screenshot_blob.exists():
            screenshot_url = screenshot_blob.public_url
        
        # Update product with URLs if found
        updates = {}
        if thumbnail_url:
            updates['thumbnailUrl'] = thumbnail_url
        if screenshot_url:
            updates['imageUrl'] = screenshot_url
            
        if updates:
            try:
                ref.child(product_id).update(updates)
                updated_count += 1
                print(f"[OK] Updated {sku} with image URLs")
            except Exception as e:
                print(f"[FAIL] Failed to update {sku}: {e}")
    
    print(f"\n[OK] Updated {updated_count} products with image URLs")

def main():
    print("=" * 60)
    print("FIREBASE STORAGE IMAGE UPLOAD SCRIPT")
    print("=" * 60)
    
    # Define paths
    thumbnails_path = r'C:\Users\andre\Desktop\-- Flutter App\assets\thumbnails'
    screenshots_path = r'C:\Users\andre\Desktop\-- Flutter App\assets\screenshots'
    
    # Check if folders exist
    if not os.path.exists(thumbnails_path):
        print(f"[ERROR] Thumbnails folder not found: {thumbnails_path}")
        return
    
    if not os.path.exists(screenshots_path):
        print(f"[ERROR] Screenshots folder not found: {screenshots_path}")
        return
    
    print("\n[INFO] Starting upload process...")
    print("This may take a while for 3,500+ images...\n")
    
    # Upload thumbnails
    print("[INFO] Uploading THUMBNAILS...")
    print("-" * 40)
    thumb_uploaded, thumb_failed, thumb_skipped = upload_images_from_folder(
        thumbnails_path, 'thumbnails'
    )
    
    print(f"\n[SUMMARY] Thumbnails:")
    print(f"   Uploaded: {thumb_uploaded}")
    print(f"   Skipped: {thumb_skipped}")
    print(f"   Failed: {thumb_failed}")
    
    # Upload screenshots
    print("\n[INFO] Uploading SCREENSHOTS...")
    print("-" * 40)
    screen_uploaded, screen_failed, screen_skipped = upload_images_from_folder(
        screenshots_path, 'screenshots'
    )
    
    print(f"\n[SUMMARY] Screenshots:")
    print(f"   Uploaded: {screen_uploaded}")
    print(f"   Skipped: {screen_skipped}")
    print(f"   Failed: {screen_failed}")
    
    # Update database with URLs
    update_product_image_urls()
    
    # Final summary
    print("\n" + "=" * 60)
    print("UPLOAD COMPLETE!")
    print("=" * 60)
    print(f"Total Uploaded: {thumb_uploaded + screen_uploaded}")
    print(f"Total Skipped: {thumb_skipped + screen_skipped}")
    print(f"Total Failed: {thumb_failed + screen_failed}")
    
    # Generate sample URLs for testing
    print("\n[INFO] Sample Image URLs for Testing:")
    print("-" * 40)
    
    # Get a sample product
    ref = db.reference('products')
    sample_product = ref.order_by_key().limit_to_first(1).get()
    if sample_product:
        for product_id, product_data in sample_product.items():
            if 'thumbnailUrl' in product_data:
                print(f"Thumbnail: {product_data['thumbnailUrl']}")
            if 'imageUrl' in product_data:
                print(f"Screenshot: {product_data['imageUrl']}")
    
    print("\n[OK] Images are now hosted on Firebase Storage!")
    print("[OK] Database has been updated with image URLs")
    print("[OK] Next step: Update Flutter app to use these URLs")

if __name__ == "__main__":
    main()