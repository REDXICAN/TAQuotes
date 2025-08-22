import firebase_admin
from firebase_admin import credentials, db
import json
import sys

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Initialize Firebase Admin SDK
cred = credentials.Certificate('../taquotes-firebase-adminsdk-fbsvc-ae05f60f37.json')
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com'
})

def check_thumbnail_urls():
    print('🔍 Checking thumbnail URLs in database...\n')
    
    try:
        # Get reference to products
        ref = db.reference('products')
        products_data = ref.get()
        
        if not products_data:
            print('❌ No products found in database')
            return
        
        print(f'✅ Found {len(products_data)} total products\n')
        
        # Count products with and without thumbnail URLs
        with_thumbnail = 0
        without_thumbnail = 0
        with_image_url = 0
        with_both = 0
        missing_all = 0
        
        products_without_thumbnail = []
        
        for key, product in products_data.items():
            sku = product.get('sku', '')
            thumbnail_url = product.get('thumbnailUrl', '')
            image_url = product.get('imageUrl', '')
            
            has_thumbnail = thumbnail_url and thumbnail_url.strip() != ''
            has_image = image_url and image_url.strip() != ''
            
            if has_thumbnail:
                with_thumbnail += 1
            else:
                without_thumbnail += 1
                products_without_thumbnail.append({
                    'key': key,
                    'sku': sku,
                    'name': product.get('name', ''),
                    'model': product.get('model', '')
                })
            
            if has_image:
                with_image_url += 1
                
            if has_thumbnail and has_image:
                with_both += 1
                
            if not has_thumbnail and not has_image:
                missing_all += 1
        
        print('📊 Summary:')
        print(f'  ✅ Products WITH thumbnailUrl: {with_thumbnail}')
        print(f'  ❌ Products WITHOUT thumbnailUrl: {without_thumbnail}')
        print(f'  📷 Products with imageUrl: {with_image_url}')
        print(f'  🎯 Products with BOTH: {with_both}')
        print(f'  ⚠️  Products missing ALL images: {missing_all}\n')
        
        if products_without_thumbnail:
            print(f'🔍 First 10 products WITHOUT thumbnailUrl:')
            for i, product in enumerate(products_without_thumbnail[:10], 1):
                print(f"{i}. SKU: {product['sku']} | Model: {product['model']} | Name: {product['name'][:50]}")
            
            if len(products_without_thumbnail) > 10:
                print(f'... and {len(products_without_thumbnail) - 10} more')
        
        # Check a sample of thumbnail URLs to see if they're valid Firebase Storage URLs
        print('\n🔍 Checking thumbnail URL format (first 5):')
        sample_count = 0
        for key, product in products_data.items():
            if sample_count >= 5:
                break
            thumbnail_url = product.get('thumbnailUrl', '')
            if thumbnail_url:
                sample_count += 1
                sku = product.get('sku', '')
                if 'firebasestorage.app' in thumbnail_url or 'storage.googleapis.com' in thumbnail_url:
                    print(f"✅ {sku}: Valid Firebase Storage URL")
                else:
                    print(f"❌ {sku}: Invalid URL format - {thumbnail_url[:100]}")
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    check_thumbnail_urls()
    print('\n✅ Check completed')