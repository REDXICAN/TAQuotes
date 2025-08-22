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

def check_sample_products():
    """Check if sample products exist in database."""
    
    print('🔍 Checking sample products in database...\n')
    
    try:
        # Get reference to products
        ref = db.reference('products')
        products_data = ref.get()
        
        if not products_data:
            print('❌ No products found in database')
            return
        
        # Sample SKUs to check
        sample_skus = ['PRO-26R-N', 'TSR-23SD-N6', 'M3R24-1-N', 'PST-28-N', 'TUR-48SD-N']
        
        print('Looking for sample SKUs:')
        for target_sku in sample_skus:
            found = False
            for key, product in products_data.items():
                sku = product.get('sku', '')
                if sku == target_sku:
                    pdf_url = product.get('pdfUrl', '')
                    print(f"✅ Found: {target_sku}")
                    if pdf_url:
                        print(f"   Has PDF URL: {pdf_url[:50]}...")
                    else:
                        print(f"   No PDF URL")
                    found = True
                    break
            
            if not found:
                print(f"❌ Not found: {target_sku}")
        
        # List first 10 SKUs in database for reference
        print('\n📊 First 10 SKUs in database:')
        count = 0
        for key, product in products_data.items():
            if count >= 10:
                break
            sku = product.get('sku', '')
            if sku:
                pdf_url = product.get('pdfUrl', '')
                print(f"{count + 1}. {sku} - PDF: {'Yes' if pdf_url else 'No'}")
                count += 1
        
    except Exception as e:
        print(f'❌ Error: {e}')

if __name__ == '__main__':
    check_sample_products()
    print('\n✅ Check completed')