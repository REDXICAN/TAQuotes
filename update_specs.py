import pandas as pd
import firebase_admin
from firebase_admin import credentials, db
import json
import os

# Initialize Firebase Admin SDK
# You'll need to download your service account key from Firebase Console
# Go to Project Settings > Service Accounts > Generate New Private Key
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
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com'
})

# Read Excel file
excel_path = r'C:\Users\andre\Desktop\-- Flutter App\turbo_air_products.xlsx'
df = pd.read_excel(excel_path)

print(f"Loading {len(df)} products from Excel...")

# Get reference to products in database
ref = db.reference('products')
all_products = ref.get()

if not all_products:
    print("No products found in database!")
    exit(1)

print(f"Found {len(all_products)} products in database")

# Update each product
updated_count = 0
not_found = []

for index, row in df.iterrows():
    sku = row['SKU']
    print(f"\nProcessing {sku}...")
    
    # Find product in database by SKU
    product_found = False
    
    for product_id, product_data in all_products.items():
        if product_data.get('sku') == sku or product_data.get('model') == sku:
            print(f"  Found in database as {product_id}")
            product_found = True
            
            # Prepare update data
            update_data = {}
            
            # Map Excel columns to database fields
            field_mapping = {
                'Voltage': 'voltage',
                'Amperage': 'amperage',
                'Phase': 'phase',
                'Frequency': 'frequency',
                'Plug Type': 'plugType',
                'Dimensions': 'dimensions',
                'Dimensions (Metric)': 'dimensionsMetric',
                'Weight': 'weight',
                'Weight (Metric)': 'weightMetric',
                'Temperature Range': 'temperatureRange',
                'Temperature Range (Metric)': 'temperatureRangeMetric',
                'Refrigerant': 'refrigerant',
                'Compressor': 'compressor',
                'Capacity': 'capacity',
                'Doors': 'doors',
                'Shelves': 'shelves',
                'Features': 'features',
                'Certifications': 'certifications',
                'Product Type': 'productType',
                'Subcategory': 'subcategory',
                'Description': 'description',
                'Price': 'price'
            }
            
            # Add each field if it has a value
            for excel_col, db_field in field_mapping.items():
                if excel_col in row and pd.notna(row[excel_col]):
                    value = row[excel_col]
                    
                    # Convert numeric fields appropriately
                    if db_field in ['doors', 'shelves']:
                        try:
                            value = int(float(str(value)))
                        except:
                            pass
                    elif db_field == 'price':
                        try:
                            value = float(value)
                        except:
                            pass
                    else:
                        value = str(value)
                    
                    update_data[db_field] = value
            
            # Update the product in database
            if update_data:
                product_ref = db.reference(f'products/{product_id}')
                product_ref.update(update_data)
                print(f"  Updated with {len(update_data)} fields")
                updated_count += 1
            
            break
    
    if not product_found:
        not_found.append(sku)
        print(f"  NOT FOUND in database")

print("\n" + "="*50)
print(f"UPDATE COMPLETE!")
print(f"Updated: {updated_count} products")
print(f"Not found: {len(not_found)} products")

if not_found:
    print("\nProducts not found in database:")
    for sku in not_found:
        print(f"  - {sku}")

print("\nAll product specifications have been updated from Excel!")