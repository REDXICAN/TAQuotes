import json
import pandas as pd
import os

# File paths
json_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-products-export.json"
excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"
output_file = r"C:\Users\andre\Downloads\taquotes-products-with-stock.json"

print(f"Loading products from JSON...")
with open(json_file, 'r', encoding='utf-8') as f:
    products = json.load(f)

print(f"Total products in JSON: {len(products)}")

# Try to read Excel file
print(f"\nLoading Excel file...")
try:
    # Try reading the first sheet, skip first rows if needed
    df = pd.read_excel(excel_file, sheet_name=0, skiprows=2)
    print(f"Excel loaded. Shape: {df.shape}")
    print(f"Columns: {df.columns.tolist()}")
    
    # Display first few rows to understand structure
    print("\nFirst 5 rows of Excel:")
    print(df.head())
    
    # Look for SKU and stock columns (common names)
    sku_column = None
    stock_column = None
    
    # Based on the Excel structure, the columns appear to be:
    # Column 0: Código (SKU)
    # Column 1: Nombre (Product Name)
    # Column 2: Existencia (Stock)
    
    # Check if columns match expected pattern
    if len(df.columns) >= 3:
        # Use first column as SKU and third column as stock
        sku_column = df.columns[0]  # Should be "Código"
        stock_column = df.columns[2]  # Should be "Existencia"
    else:
        # Fallback to searching for column names
        sku_names = ['SKU', 'sku', 'Model', 'MODEL', 'Modelo', 'MODELO', 'Código', 'CODIGO', 'Code', 'Product Code', 'Item', 'Codigo']
        for col in df.columns:
            if any(name.lower() in str(col).lower() for name in sku_names):
                sku_column = col
                break
        
        stock_names = ['Stock', 'STOCK', 'Inventory', 'INVENTORY', 'Inventario', 'INVENTARIO', 'Quantity', 'Qty', 'CANTIDAD', 'Cantidad', 'Available', 'Disponible', 'Existencia']
        for col in df.columns:
            if any(name.lower() in str(col).lower() for name in stock_names):
                stock_column = col
                break
    
    print(f"\nIdentified columns:")
    print(f"SKU column: {sku_column}")
    print(f"Stock column: {stock_column}")
    
    if not sku_column:
        print("\nCouldn't identify SKU column. Please check these columns:")
        for i, col in enumerate(df.columns):
            print(f"  {i}: {col}")
    
    if not stock_column:
        print("\nCouldn't identify Stock column. Available columns:")
        for i, col in enumerate(df.columns):
            print(f"  {i}: {col}")
            
    # Create a mapping of SKU to stock from Excel
    stock_map = {}
    if sku_column and stock_column:
        for _, row in df.iterrows():
            sku = str(row[sku_column]).strip() if pd.notna(row[sku_column]) else None
            stock = row[stock_column] if pd.notna(row[stock_column]) else 0
            
            if sku:
                # Convert stock to integer, handle various formats
                try:
                    stock = int(float(str(stock).replace(',', '')))
                except:
                    stock = 0
                
                stock_map[sku] = stock
        
        print(f"\nCreated stock map with {len(stock_map)} items")
        print("Sample stock mappings:")
        for i, (sku, stock) in enumerate(list(stock_map.items())[:5]):
            print(f"  {sku}: {stock}")
    
    # Update products with stock information
    updated_count = 0
    no_match_count = 0
    
    print("\nUpdating products with stock information...")
    for product_key, product_data in products.items():
        product_sku = product_data.get('sku', '')
        
        if product_sku in stock_map:
            product_data['stock'] = stock_map[product_sku]
            updated_count += 1
        else:
            # Set stock to 0 if not found
            product_data['stock'] = 0
            no_match_count += 1
    
    print(f"\nUpdate complete:")
    print(f"  Products updated with stock: {updated_count}")
    print(f"  Products set to 0 stock (not found): {no_match_count}")
    
    # Save updated products
    print(f"\nSaving updated products to: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(products, f, indent=2, ensure_ascii=False)
    
    print(f"[SUCCESS] Updated products saved successfully!")
    
    # Show some examples of updated products
    print("\nSample of updated products:")
    sample_count = 0
    for key, data in products.items():
        if sample_count < 5:
            print(f"  {data.get('sku', 'N/A')}: stock = {data.get('stock', 0)}")
            sample_count += 1
        else:
            break
            
except Exception as e:
    print(f"Error reading Excel file: {e}")
    print("\nSetting all products to stock = 0...")
    
    # Set all products to stock = 0
    for product_key, product_data in products.items():
        product_data['stock'] = 0
    
    # Save updated products
    print(f"\nSaving updated products to: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(products, f, indent=2, ensure_ascii=False)
    
    print(f"[SUCCESS] All products set to stock = 0 and saved!")