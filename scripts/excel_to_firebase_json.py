import pandas as pd
import json
import sys
from datetime import datetime

def parse_price(price_str):
    """Parse price from string, removing currency symbols"""
    if pd.isna(price_str) or price_str == '':
        return 0.0
    if isinstance(price_str, (int, float)):
        return float(price_str)
    # Remove currency symbols and commas
    cleaned = str(price_str).replace('$', '').replace(',', '').strip()
    try:
        return float(cleaned)
    except:
        return 0.0

def parse_int(value):
    """Safely parse integer values"""
    if pd.isna(value) or value == '':
        return None
    try:
        if isinstance(value, str):
            # Remove non-numeric characters
            cleaned = ''.join(filter(str.isdigit, value))
            if cleaned:
                return int(cleaned)
        return int(value)
    except:
        return None

def excel_to_firebase_json(excel_path):
    """Convert Excel file to Firebase-ready JSON"""
    
    # Read Excel file
    df = pd.read_excel(excel_path)
    
    # Print columns for debugging
    print(f"Found {len(df)} rows")
    print(f"Columns: {list(df.columns)}")
    
    products = {}
    
    for index, row in df.iterrows():
        # Skip rows without SKU
        if pd.isna(row.get('SKU', '')):
            continue
            
        sku = str(row['SKU']).strip()
        description = str(row.get('Description', '')).strip() if not pd.isna(row.get('Description', '')) else ''
        
        # Generate name from description (first part before comma)
        name = description.split(',')[0].strip() if description else sku
        
        # Create product data
        product_data = {
            'sku': sku,
            'model': sku,  # Use SKU as model
            'name': name,
            'displayName': name,
            'description': description,
            'category': str(row.get('Category', '')).strip() if not pd.isna(row.get('Category', '')) else '',
            'subcategory': str(row.get('Subcategory', '')).strip() if not pd.isna(row.get('Subcategory', '')) else '',
            'product_type': str(row.get('Product Type', '')).strip() if not pd.isna(row.get('Product Type', '')) else '',
            'voltage': str(row.get('Voltage', '')).strip() if not pd.isna(row.get('Voltage', '')) else '',
            'amperage': str(row.get('Amperage', '')).strip() if not pd.isna(row.get('Amperage', '')) else '',
            'phase': str(row.get('Phase', '')).strip() if not pd.isna(row.get('Phase', '')) else '',
            'frequency': str(row.get('Frequency', '')).strip() if not pd.isna(row.get('Frequency', '')) else '',
            'plug_type': str(row.get('Plug Type', '')).strip() if not pd.isna(row.get('Plug Type', '')) else '',
            'dimensions': str(row.get('Dimensions', '')).strip() if not pd.isna(row.get('Dimensions', '')) else '',
            'dimensions_metric': str(row.get('Dimensions (Metric)', '')).strip() if not pd.isna(row.get('Dimensions (Metric)', '')) else '',
            'weight': str(row.get('Weight', '')).strip() if not pd.isna(row.get('Weight', '')) else '',
            'weight_metric': str(row.get('Weight (Metric)', '')).strip() if not pd.isna(row.get('Weight (Metric)', '')) else '',
            'temperature_range': str(row.get('Temperature Range', '')).strip() if not pd.isna(row.get('Temperature Range', '')) else '',
            'temperature_range_metric': str(row.get('Temperature Range (Metric)', '')).strip() if not pd.isna(row.get('Temperature Range (Metric)', '')) else '',
            'refrigerant': str(row.get('Refrigerant', '')).strip() if not pd.isna(row.get('Refrigerant', '')) else '',
            'compressor': str(row.get('Compressor', '')).strip() if not pd.isna(row.get('Compressor', '')) else '',
            'capacity': str(row.get('Capacity', '')).strip() if not pd.isna(row.get('Capacity', '')) else '',
            'features': str(row.get('Features', '')).strip() if not pd.isna(row.get('Features', '')) else '',
            'certifications': str(row.get('Certifications', '')).strip() if not pd.isna(row.get('Certifications', '')) else '',
            'price': parse_price(row.get('Price', 0)),
            'stock': 100,  # Default stock
            'image_url': f'assets/screenshots/{sku}/P.1.png',
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat(),
        }
        
        # Parse integer fields
        doors = parse_int(row.get('Doors', ''))
        if doors is not None:
            product_data['doors'] = doors
            
        shelves = parse_int(row.get('Shelves', ''))
        if shelves is not None:
            product_data['shelves'] = shelves
        
        # Remove empty string values
        product_data = {k: v for k, v in product_data.items() if v != ''}
        
        # Generate a unique key for Firebase (you can use push IDs in actual implementation)
        firebase_key = f"product_{index:04d}"
        products[firebase_key] = product_data
        
        print(f"Processed: {sku} - {name}")
    
    print(f"\nTotal products processed: {len(products)}")
    
    # Create the full database structure
    database_json = {
        "products": products
    }
    
    # Save to JSON file
    output_path = excel_path.replace('.xlsx', '_firebase.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(database_json, f, indent=2, ensure_ascii=False)
    
    print(f"Firebase JSON saved to: {output_path}")
    print("\nTo import to Firebase:")
    print("1. Go to Firebase Console > Realtime Database")
    print("2. Click on the three dots menu > Import JSON")
    print(f"3. Upload the file: {output_path}")
    
    return output_path

if __name__ == "__main__":
    excel_file = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\-- Flutter App\turbo_air_products.xlsx"
    
    try:
        output_file = excel_to_firebase_json(excel_file)
        print(f"\nSuccess! Firebase JSON created: {output_file}")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()