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
elif os.path.exists('../firebase-admin-key.json'):
    cred = credentials.Certificate('../firebase-admin-key.json')
elif os.path.exists('firebase-admin-key.json'):
    cred = credentials.Certificate('firebase-admin-key.json')
else:
    print('❌ Error: Firebase admin key not found')
    print('Please download the service account key from Firebase Console:')
    print('1. Go to Firebase Console > Project Settings > Service Accounts')
    print('2. Click "Generate new private key"')
    print('3. Save the file as firebase-admin-key.json in the project root')
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
            
            # Check if it's an E line product
            if (sku.endswith('-E') or 
                'E-' in sku or
                model.endswith('-E') or 
                'E-' in model or
                'e series' in product_type.lower() or
                'e-series' in product_type.lower() or
                'e series' in name.lower() or
                'e-series' in name.lower()):
                e_line_products[key] = product
        
        if not e_line_products:
            print('✅ No E line products found in database')
            return
        
        print(f'🔍 Found {len(e_line_products)} E line products:\n')
        
        # List E line products
        for i, (key, product) in enumerate(e_line_products.items(), 1):
            print(f"{i}. SKU: {product.get('sku')} | Model: {product.get('model')} | Name: {product.get('name')}")
        
        print(f'\n⚠️  WARNING: This will permanently delete {len(e_line_products)} E line products!')
        confirmation = input('Type "DELETE" to confirm deletion, or press Enter to cancel: ').strip()
        
        if confirmation.upper() != 'DELETE':
            print('❌ Deletion cancelled')
            return
        
        print('\n🗑️  Deleting E line products...')
        
        # Delete each E line product
        deleted = 0
        failed = 0
        
        for key in e_line_products.keys():
            try:
                db.reference(f'products/{key}').delete()
                deleted += 1
                print(f'  ✅ Deleted product with key: {key}')
            except Exception as e:
                failed += 1
                print(f'  ❌ Failed to delete product with key: {key} - Error: {e}')
        
        print('\n📊 Deletion Summary:')
        print(f'  ✅ Successfully deleted: {deleted} products')
        if failed > 0:
            print(f'  ❌ Failed to delete: {failed} products')
        
        # Verify remaining products
        remaining_products = db.reference('products').get() or {}
        print(f'\n📊 Database now contains {len(remaining_products)} products')
        
        # Double-check no E line products remain
        remaining_e_line = 0
        for product in remaining_products.values():
            sku = product.get('sku', '')
            model = product.get('model', '')
            if (sku.endswith('-E') or 'E-' in sku or 
                model.endswith('-E') or 'E-' in model):
                remaining_e_line += 1
        
        if remaining_e_line > 0:
            print(f'  ⚠️  Warning: {remaining_e_line} E line products may still remain')
        else:
            print('  ✅ All E line products successfully removed')
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    delete_e_line_products()
    print('\n✅ Script completed')