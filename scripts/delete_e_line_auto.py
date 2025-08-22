import firebase_admin
from firebase_admin import credentials, db
import json
import os
import sys

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Initialize Firebase Admin SDK
# Check if service account key exists
if os.path.exists('../taquotes-firebase-adminsdk-fbsvc-ae05f60f37.json'):
    cred = credentials.Certificate('../taquotes-firebase-adminsdk-fbsvc-ae05f60f37.json')
elif os.path.exists('taquotes-firebase-adminsdk-fbsvc-ae05f60f37.json'):
    cred = credentials.Certificate('taquotes-firebase-adminsdk-fbsvc-ae05f60f37.json')
else:
    print('❌ Error: Firebase admin key not found')
    exit(1)

firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com'
})

def delete_e_line_products():
    print('🔍 Fetching all products from database...')
    
    try:
        # Get reference to products
        ref = db.reference('products')
        products_data = ref.get()
        
        if not products_data:
            print('❌ No products found in database')
            return
        
        print(f'✅ Found {len(products_data)} total products\n')
        
        # Find E line products
        e_line_products = {}
        
        for key, product in products_data.items():
            sku = product.get('sku', '')
            model = product.get('model', '')
            name = product.get('name', '')
            product_type = product.get('productType', '')
            
            # Check if it's an E line product - be more specific
            # Only delete products with E- prefix or -E suffix in SKU
            if (sku.endswith('-E-N') or 
                sku.endswith('-E-N6') or
                sku.endswith('-E-SVC-N') or
                'PRCBE-' in sku or  # PRCBE line
                'TCBE-' in sku or   # TCBE line
                '-E-' in sku):      # Any E variant
                e_line_products[key] = product
        
        if not e_line_products:
            print('✅ No E line products found in database')
            return
        
        print(f'🔍 Found {len(e_line_products)} E line products to delete:\n')
        
        # List E line products
        for i, (key, product) in enumerate(e_line_products.items(), 1):
            print(f"{i}. SKU: {product.get('sku')} | Model: {product.get('model')} | Name: {product.get('name')}")
        
        print(f'\n🗑️  AUTO-DELETING {len(e_line_products)} E line products...')
        
        # Delete each E line product
        deleted = 0
        failed = 0
        failed_keys = []
        
        for key in e_line_products.keys():
            try:
                db.reference(f'products/{key}').delete()
                deleted += 1
                print(f'  ✅ Deleted: {e_line_products[key].get("sku")}')
            except Exception as e:
                failed += 1
                failed_keys.append(key)
                print(f'  ❌ Failed: {e_line_products[key].get("sku")} - Error: {e}')
        
        print('\n📊 Deletion Summary:')
        print(f'  ✅ Successfully deleted: {deleted} products')
        if failed > 0:
            print(f'  ❌ Failed to delete: {failed} products')
            print(f'     Failed keys: {failed_keys}')
        
        # Verify remaining products
        remaining_products = db.reference('products').get() or {}
        print(f'\n📊 Database now contains {len(remaining_products)} products (was {len(products_data)})')
        
        # Double-check no E line products remain
        remaining_e_line = []
        for key, product in remaining_products.items():
            sku = product.get('sku', '')
            if ('PRCBE-' in sku or 'TCBE-' in sku or 
                sku.endswith('-E-N') or sku.endswith('-E-N6') or
                '-E-' in sku):
                remaining_e_line.append(sku)
        
        if remaining_e_line:
            print(f'  ⚠️  Warning: {len(remaining_e_line)} E line products may still remain:')
            for sku in remaining_e_line[:5]:  # Show first 5
                print(f'     - {sku}')
        else:
            print('  ✅ All E line products successfully removed')
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    delete_e_line_products()
    print('\n✅ Script completed')