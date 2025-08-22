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

def add_pdf_urls():
    """Add PDF URLs to products in the database."""
    
    print('🔍 Adding PDF URLs to products in database...\n')
    
    try:
        # Get reference to products
        ref = db.reference('products')
        products_data = ref.get()
        
        if not products_data:
            print('❌ No products found in database')
            return
        
        print(f'✅ Found {len(products_data)} total products\n')
        
        # Count products that need PDF URLs
        products_to_update = []
        
        for key, product in products_data.items():
            sku = product.get('sku', '')
            pdf_url = product.get('pdfUrl', '')
            
            # If no PDF URL, create one based on SKU
            if not pdf_url and sku:
                # Format: https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/pdfs%2FSKU.pdf?alt=media
                new_pdf_url = f'https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/pdfs%2F{sku}.pdf?alt=media'
                products_to_update.append({
                    'key': key,
                    'sku': sku,
                    'pdf_url': new_pdf_url
                })
        
        if not products_to_update:
            print('✅ All products already have PDF URLs')
            return
        
        print(f'🔧 Found {len(products_to_update)} products to add PDF URLs\n')
        
        # Update products with PDF URLs
        updated = 0
        failed = 0
        
        # Only update a few products as examples (you can remove this limit later)
        sample_skus = ['PRO-26R-N', 'TSR-23SD-N6', 'M3R24-1-N', 'PST-28-N', 'TUR-48SD-N']
        
        for product in products_to_update:
            # For now, only add PDF URLs to sample products
            if product['sku'] not in sample_skus:
                continue
                
            try:
                # Update the product with PDF URL
                ref.child(product['key']).update({
                    'pdfUrl': product['pdf_url']
                })
                updated += 1
                print(f"✅ Added PDF URL for: {product['sku']}")
            except Exception as e:
                failed += 1
                print(f"❌ Failed: {product['sku']} - Error: {e}")
        
        print(f'\n📊 Summary:')
        print(f'  ✅ Successfully added PDF URLs to: {updated} products')
        if failed > 0:
            print(f'  ❌ Failed to update: {failed} products')
        
        # Verify the update
        print('\n🔍 Verifying PDF URLs...')
        updated_products = ref.get()
        with_pdf = 0
        
        for key, product in updated_products.items():
            pdf_url = product.get('pdfUrl', '')
            if pdf_url:
                with_pdf += 1
        
        print(f'  📊 Products with PDF URLs: {with_pdf}')
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    add_pdf_urls()
    print('\n✅ Script completed')