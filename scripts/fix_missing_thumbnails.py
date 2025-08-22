import firebase_admin
from firebase_admin import credentials, db
import sys

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Initialize Firebase Admin SDK
cred = credentials.Certificate('../taquotes-firebase-adminsdk-fbsvc-ae05f60f37.json')
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com'
})

def fix_missing_thumbnails():
    print('🔍 Fixing missing thumbnail URLs in database...\n')
    
    try:
        # Get reference to products
        ref = db.reference('products')
        products_data = ref.get()
        
        if not products_data:
            print('❌ No products found in database')
            return
        
        print(f'✅ Found {len(products_data)} total products\n')
        
        # Find products without thumbnailUrl but with imageUrl
        products_to_fix = []
        
        for key, product in products_data.items():
            thumbnail_url = product.get('thumbnailUrl', '')
            image_url = product.get('imageUrl', '')
            
            # If no thumbnail but has image URL, use image as thumbnail
            if (not thumbnail_url or thumbnail_url.strip() == '') and image_url and image_url.strip() != '':
                products_to_fix.append({
                    'key': key,
                    'sku': product.get('sku', ''),
                    'image_url': image_url
                })
        
        if not products_to_fix:
            print('✅ All products already have thumbnail URLs or no image URLs to use')
            return
        
        print(f'🔧 Found {len(products_to_fix)} products to fix\n')
        
        # Update products with missing thumbnails
        fixed = 0
        failed = 0
        
        for product in products_to_fix:
            try:
                # Update the product with thumbnailUrl = imageUrl
                ref.child(product['key']).update({
                    'thumbnailUrl': product['image_url']
                })
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
        without_thumbnail = 0
        
        for key, product in updated_products.items():
            thumbnail_url = product.get('thumbnailUrl', '')
            if not thumbnail_url or thumbnail_url.strip() == '':
                without_thumbnail += 1
        
        print(f'  📊 Products still without thumbnailUrl: {without_thumbnail}')
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    fix_missing_thumbnails()
    print('\n✅ Script completed')