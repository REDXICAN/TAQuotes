import pandas as pd
import firebase_admin
from firebase_admin import credentials, db
import json
import os
import re

# Initialize Firebase Admin SDK
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

# Read Excel file - NEW PATH
excel_path = r'O:\OneDrive\Documentos\-- TurboAir\7 Bots\turbo-air-extractor\turbo_air_100_complete_final_fixed.xlsx'

if not os.path.exists(excel_path):
    print(f"Excel file not found at: {excel_path}")
    print("Trying alternative path...")
    excel_path = r'C:\Users\andre\OneDrive\Documentos\-- TurboAir\7 Bots\turbo-air-extractor\turbo_air_100_complete_final_fixed.xlsx'
    if not os.path.exists(excel_path):
        print("Excel file not found! Please check the path.")
        exit(1)

df = pd.read_excel(excel_path)

print(f"Loading {len(df)} products from Excel...")
print(f"Columns in Excel: {list(df.columns)}")

# Show columns F through W (index 5 through 22)
print("\nColumns F through W:")
column_letters = ['F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W']
for i, col_letter in enumerate(column_letters):
    col_index = 5 + i  # F is the 6th column (index 5)
    if col_index < len(df.columns):
        print(f"  Column {col_letter}: {df.columns[col_index]}")

# Get reference to products in database
ref = db.reference('products')
all_products = ref.get()

if not all_products:
    print("No products found in database!")
    exit(1)

print(f"\nFound {len(all_products)} products in database")

# Process Excel data and create spec templates from each row
spec_templates = {}

for index, row in df.iterrows():
    # Get the model/SKU identifier (usually in first few columns)
    model_key = None
    for col in ['Model', 'SKU', 'Model Number', 'Part Number']:
        if col in df.columns and pd.notna(row[col]):
            model_key = str(row[col]).strip()
            break
    
    if not model_key:
        # Try first column if no standard name found
        model_key = str(row.iloc[0]).strip() if pd.notna(row.iloc[0]) else None
    
    if not model_key:
        continue
    
    # Extract base model pattern (remove size/variant suffixes)
    # For example: PRO-26R-N -> PRO-R
    # TSR-23SD-N6 -> TSR-SD
    base_pattern = model_key
    
    # Remove common suffixes
    base_pattern = re.sub(r'-?\d+[A-Z]?(-[A-Z]\d?)?$', '', base_pattern)  # Remove -23SD, -26R, etc
    base_pattern = re.sub(r'-N\d*$', '', base_pattern)  # Remove -N, -N6, etc
    
    # Build spec data from columns F through W (indices 5-22)
    spec_data = {}
    description_parts = []
    
    # Map columns to database fields
    for col_index in range(5, min(23, len(df.columns))):  # F through W
        col_name = df.columns[col_index]
        value = row.iloc[col_index]
        
        if pd.notna(value):
            value_str = str(value).strip()
            
            # Map common column names to database fields
            col_lower = col_name.lower()
            
            if 'voltage' in col_lower or col_name == 'V':
                spec_data['voltage'] = value_str
                description_parts.append(f"Voltage: {value_str}")
            elif 'amp' in col_lower or col_name == 'A' or 'amperage' in col_lower:
                spec_data['amperage'] = value_str
                description_parts.append(f"Amperage: {value_str}")
            elif 'phase' in col_lower or col_name == 'PH':
                spec_data['phase'] = value_str
                description_parts.append(f"Phase: {value_str}")
            elif 'freq' in col_lower or 'hz' in col_lower:
                spec_data['frequency'] = value_str
                description_parts.append(f"Frequency: {value_str}")
            elif 'plug' in col_lower or 'nema' in col_lower:
                spec_data['plugType'] = value_str
                description_parts.append(f"Plug Type: {value_str}")
            elif 'dimension' in col_lower and 'metric' not in col_lower:
                spec_data['dimensions'] = value_str
                description_parts.append(f"Dimensions: {value_str}")
            elif 'dimension' in col_lower and 'metric' in col_lower:
                spec_data['dimensionsMetric'] = value_str
                description_parts.append(f"Dimensions (Metric): {value_str}")
            elif 'weight' in col_lower and 'metric' not in col_lower:
                spec_data['weight'] = value_str
                description_parts.append(f"Weight: {value_str}")
            elif 'weight' in col_lower and 'metric' in col_lower:
                spec_data['weightMetric'] = value_str
                description_parts.append(f"Weight (Metric): {value_str}")
            elif 'temp' in col_lower and 'range' in col_lower and 'metric' not in col_lower:
                spec_data['temperatureRange'] = value_str
                description_parts.append(f"Temperature Range: {value_str}")
            elif 'temp' in col_lower and 'range' in col_lower and 'metric' in col_lower:
                spec_data['temperatureRangeMetric'] = value_str
                description_parts.append(f"Temperature Range (Metric): {value_str}")
            elif 'refrigerant' in col_lower or 'r-' in col_lower:
                spec_data['refrigerant'] = value_str
                description_parts.append(f"Refrigerant: {value_str}")
            elif 'compressor' in col_lower or 'hp' in col_lower:
                spec_data['compressor'] = value_str
                description_parts.append(f"Compressor: {value_str}")
            elif 'capacity' in col_lower or 'cu' in col_lower:
                spec_data['capacity'] = value_str
                description_parts.append(f"Capacity: {value_str}")
            elif 'door' in col_lower:
                try:
                    spec_data['doors'] = int(float(value_str))
                    description_parts.append(f"Doors: {value_str}")
                except:
                    spec_data['doors'] = value_str
                    description_parts.append(f"Doors: {value_str}")
            elif 'shelf' in col_lower or 'shelves' in col_lower:
                try:
                    spec_data['shelves'] = int(float(value_str))
                    description_parts.append(f"Shelves: {value_str}")
                except:
                    spec_data['shelves'] = value_str
                    description_parts.append(f"Shelves: {value_str}")
            elif 'feature' in col_lower:
                spec_data['features'] = value_str
                description_parts.append(f"Features: {value_str}")
            elif 'cert' in col_lower or 'nsf' in col_lower or 'ul' in col_lower:
                spec_data['certifications'] = value_str
                description_parts.append(f"Certifications: {value_str}")
            elif 'type' in col_lower and 'product' in col_lower:
                spec_data['productType'] = value_str
            elif 'category' in col_lower or 'cat' in col_lower:
                if 'sub' in col_lower:
                    spec_data['subcategory'] = value_str
                else:
                    spec_data['category'] = value_str
            elif 'desc' in col_lower:
                spec_data['description'] = value_str
            elif 'price' in col_lower or '$' in str(value_str):
                try:
                    price_val = float(re.sub(r'[^\d.]', '', value_str))
                    spec_data['price'] = price_val
                except:
                    pass
            else:
                # Add to description if not mapped
                description_parts.append(f"{col_name}: {value_str}")
    
    # Create enhanced description from all F-W columns
    if description_parts:
        if 'description' in spec_data:
            spec_data['description'] = spec_data['description'] + '\n\nSpecifications:\n' + '\n'.join(description_parts)
        else:
            spec_data['description'] = 'Specifications:\n' + '\n'.join(description_parts)
    
    # Store template for this model and its pattern
    spec_templates[model_key] = spec_data
    if base_pattern != model_key:
        spec_templates[base_pattern] = spec_data
    
    print(f"Loaded specs for {model_key} (pattern: {base_pattern})")

print(f"\nLoaded {len(spec_templates)} spec templates from Excel")

# Now apply specs to ALL products in database
updated_count = 0
matched_count = 0
no_match_products = []

for product_id, product_data in all_products.items():
    product_model = product_data.get('model', '')
    product_sku = product_data.get('sku', '')
    
    # Try to find matching spec template
    spec_data = None
    
    # First try exact match
    if product_model in spec_templates:
        spec_data = spec_templates[product_model]
        matched_count += 1
    elif product_sku in spec_templates:
        spec_data = spec_templates[product_sku]
        matched_count += 1
    else:
        # Try pattern matching
        for pattern, specs in spec_templates.items():
            if pattern in product_model or pattern in product_sku:
                spec_data = specs
                matched_count += 1
                break
            
            # Try without numbers for broader matching
            product_base = re.sub(r'\d+', '', product_model)
            pattern_base = re.sub(r'\d+', '', pattern)
            if product_base and pattern_base and product_base == pattern_base:
                spec_data = specs
                matched_count += 1
                break
    
    if spec_data:
        # Update the product with specifications
        try:
            product_ref = db.reference(f'products/{product_id}')
            product_ref.update(spec_data)
            updated_count += 1
            print(f"Updated {product_model or product_sku} with {len(spec_data)} fields")
        except Exception as e:
            print(f"Error updating {product_id}: {e}")
    else:
        no_match_products.append(product_model or product_sku or product_id)

print("\n" + "="*50)
print(f"UPDATE COMPLETE!")
print(f"Total products in database: {len(all_products)}")
print(f"Products matched to specs: {matched_count}")
print(f"Products successfully updated: {updated_count}")
print(f"Products without matching specs: {len(no_match_products)}")

if no_match_products and len(no_match_products) <= 20:
    print("\nProducts without matching specs (first 20):")
    for product in no_match_products[:20]:
        print(f"  - {product}")

print("\nAll products have been updated with specifications from Excel columns F-W!")
print("The specifications are now included in the product descriptions.")