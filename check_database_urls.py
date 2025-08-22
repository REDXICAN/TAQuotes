import firebase_admin
from firebase_admin import credentials, storage, db

# Initialize Firebase
cred = credentials.Certificate(r'C:\Users\andre\Desktop\-- Flutter App\firebase-admin-key.json')
app = firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com',
    'storageBucket': 'taquotes.firebasestorage.app'
}, name='checker')

# Check database
ref = db.reference('products', app=app)
products = ref.get()

if products:
    total = len(products)
    with_thumbnail = 0
    with_image = 0
    
    print("Checking first 20 products...")
    for i, (pid, product) in enumerate(products.items()):
        if i >= 20:
            break
        
        sku = product.get('sku') or product.get('model')
        has_thumb = 'thumbnailUrl' in product
        has_image = 'imageUrl' in product
        
        if has_thumb:
            with_thumbnail += 1
        if has_image:
            with_image += 1
            
        print(f"{sku}: thumbnail={has_thumb}, screenshot={has_image}")
        
        if i < 3 and (has_thumb or has_image):
            if has_thumb:
                print(f"  Thumbnail URL: {product['thumbnailUrl'][:80]}...")
            if has_image:
                print(f"  Image URL: {product['imageUrl'][:80]}...")
    
    # Count all
    for pid, product in products.items():
        if 'thumbnailUrl' in product:
            with_thumbnail += 1
        if 'imageUrl' in product:
            with_image += 1
    
    print(f"\nTotal products: {total}")
    print(f"Products with thumbnailUrl: {with_thumbnail}")
    print(f"Products with imageUrl: {with_image}")

firebase_admin.delete_app(app)