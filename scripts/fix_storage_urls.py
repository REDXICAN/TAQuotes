import firebase_admin
from firebase_admin import credentials, db
import sys
import re

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Initialize Firebase Admin SDK
cred = credentials.Certificate('../taquotes-firebase-adminsdk-fbsvc-ae05f60f37.json')
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com'
})

def fix_storage_urls():
    """Convert Google Storage URLs to Firebase Storage URLs."""
    
    print('🔍 Fixing Firebase Storage URLs in database...\n')
    
    try:
        # Get reference to products
        ref = db.reference('products')
        products_data = ref.get()
        
        if not products_data:
            print('❌ No products found in database')
            return
        
        print(f'✅ Found {len(products_data)} total products\n')
        
        # Pattern to match Google Storage URLs
        storage_pattern = r'https://storage\.googleapis\.com/taquotes\.firebasestorage\.app/'
        firebase_pattern = 'https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/'
        
        products_to_fix = []
        
        for key, product in products_data.items():
            needs_update = False
            updates = {}
            
            # Check thumbnailUrl
            thumbnail_url = product.get('thumbnailUrl', '')
            if thumbnail_url and 'storage.googleapis.com/taquotes.firebasestorage.app' in thumbnail_url:
                # Convert to Firebase Storage format
                # From: https://storage.googleapis.com/taquotes.firebasestorage.app/thumbnails/SKU/file.jpg
                # To: https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/thumbnails%2FSKU%2Ffile.jpg?alt=media
                
                # Extract the path after the bucket
                path = thumbnail_url.replace('https://storage.googleapis.com/taquotes.firebasestorage.app/', '')
                # URL encode the path (replace / with %2F)
                encoded_path = path.replace('/', '%2F')
                # Create new Firebase Storage URL
                new_url = f'https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/{encoded_path}?alt=media'
                
                updates['thumbnailUrl'] = new_url
                needs_update = True
            
            # Check imageUrl
            image_url = product.get('imageUrl', '')
            if image_url and 'storage.googleapis.com/taquotes.firebasestorage.app' in image_url:
                path = image_url.replace('https://storage.googleapis.com/taquotes.firebasestorage.app/', '')
                encoded_path = path.replace('/', '%2F')
                new_url = f'https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/{encoded_path}?alt=media'
                
                updates['imageUrl'] = new_url
                needs_update = True
            
            # Check imageUrl2
            image_url2 = product.get('imageUrl2', '')
            if image_url2 and 'storage.googleapis.com/taquotes.firebasestorage.app' in image_url2:
                path = image_url2.replace('https://storage.googleapis.com/taquotes.firebasestorage.app/', '')
                encoded_path = path.replace('/', '%2F')
                new_url = f'https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/{encoded_path}?alt=media'
                
                updates['imageUrl2'] = new_url
                needs_update = True
            
            if needs_update:
                products_to_fix.append({
                    'key': key,
                    'sku': product.get('sku', ''),
                    'updates': updates
                })
        
        if not products_to_fix:
            print('✅ All products already have correct Firebase Storage URLs')
            return
        
        print(f'🔧 Found {len(products_to_fix)} products to fix\n')
        
        # Update products with correct URLs
        fixed = 0
        failed = 0
        
        for product in products_to_fix:
            try:
                # Update the product with new URLs
                ref.child(product['key']).update(product['updates'])
                fixed += 1
                print(f"✅ Fixed: {product['sku']}")
            except Exception as e:
                failed += 1
                print(f"❌ Failed: {product['sku']} - Error: {e}")
        
        print(f'\n📊 Summary:')
        print(f'  ✅ Successfully fixed: {fixed} products')
        if failed > 0:
            print(f'  ❌ Failed to fix: {failed} products')
        
        # Verify the fix
        print('\n🔍 Verifying fix...')
        updated_products = ref.get()
        wrong_format = 0
        
        for key, product in updated_products.items():
            thumbnail_url = product.get('thumbnailUrl', '')
            image_url = product.get('imageUrl', '')
            image_url2 = product.get('imageUrl2', '')
            
            if ('storage.googleapis.com/taquotes.firebasestorage.app' in thumbnail_url or
                'storage.googleapis.com/taquotes.firebasestorage.app' in image_url or
                'storage.googleapis.com/taquotes.firebasestorage.app' in image_url2):
                wrong_format += 1
        
        print(f'  📊 Products still with wrong URL format: {wrong_format}')
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    fix_storage_urls()
    print('\n✅ Script completed')