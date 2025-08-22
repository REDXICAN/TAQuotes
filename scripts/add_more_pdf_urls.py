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

def add_more_pdf_urls():
    """Add PDF URLs to more products in the database."""
    
    print('🔍 Adding PDF URLs to more products in database...\n')
    
    try:
        # Get reference to products
        ref = db.reference('products')
        products_data = ref.get()
        
        if not products_data:
            print('❌ No products found in database')
            return
        
        print(f'✅ Found {len(products_data)} total products\n')
        
        # SKUs to add PDF URLs to (using actual SKUs from the database)
        target_skus = [
            'CRT-77-1R-N',
            'CRT-77-2R-N', 
            'CTST-1200-N',
            'CTST-1500-N',
            'EF72-3-N-V',
            'ER19-1-N6-V',
            'EST-28-N6-V',
            'JUR-48-N6',
            'MUR-48-N'
        ]
        
        updated = 0
        already_has = 0
        not_found = 0
        
        for key, product in products_data.items():
            sku = product.get('sku', '')
            
            if sku in target_skus:
                pdf_url = product.get('pdfUrl', '')
                
                if pdf_url:
                    already_has += 1
                    print(f"✔️ {sku} already has PDF URL")
                else:
                    # Add PDF URL
                    new_pdf_url = f'https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/pdfs%2F{sku}.pdf?alt=media'
                    
                    try:
                        ref.child(key).update({
                            'pdfUrl': new_pdf_url
                        })
                        updated += 1
                        print(f"✅ Added PDF URL for: {sku}")
                    except Exception as e:
                        print(f"❌ Failed to update {sku}: {e}")
        
        # Check how many target SKUs were not found
        not_found = len(target_skus) - updated - already_has
        
        print(f'\n📊 Summary:')
        print(f'  ✅ Successfully added PDF URLs to: {updated} products')
        print(f'  ✔️ Already had PDF URLs: {already_has} products')
        if not_found > 0:
            print(f'  ❌ Not found in database: {not_found} products')
        
        # Verify total count
        print('\n🔍 Verifying total PDF URLs...')
        updated_products = ref.get()
        with_pdf = 0
        
        for key, product in updated_products.items():
            pdf_url = product.get('pdfUrl', '')
            if pdf_url:
                with_pdf += 1
        
        print(f'  📊 Total products with PDF URLs: {with_pdf}')
        
        # Show first 5 products with PDF URLs
        print('\n📄 Products with PDF URLs:')
        count = 0
        for key, product in updated_products.items():
            pdf_url = product.get('pdfUrl', '')
            if pdf_url and count < 5:
                sku = product.get('sku', '')
                print(f"  {count + 1}. {sku}")
                count += 1
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    add_more_pdf_urls()
    print('\n✅ Script completed')