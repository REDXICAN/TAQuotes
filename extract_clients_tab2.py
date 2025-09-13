import pandas as pd
import json

print("=" * 80)
print("EXTRACTING CLIENTS FROM EXCEL - SECOND TAB")
print("=" * 80)

# Read the Excel file
excel_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\-- Base de Clientes\Reporte de Ventas x Cliente Agosto 2025.xls"

try:
    # Read all sheet names first
    xl_file = pd.ExcelFile(excel_path)
    print(f"\nFound {len(xl_file.sheet_names)} sheets in Excel file:")
    for i, sheet_name in enumerate(xl_file.sheet_names):
        print(f"  Tab {i+1}: {sheet_name}")
    
    # Read the second tab (index 1)
    if len(xl_file.sheet_names) > 1:
        second_tab_name = xl_file.sheet_names[1]
        print(f"\nReading second tab: '{second_tab_name}'")
        
        # Read the second tab
        df = pd.read_excel(excel_path, sheet_name=1)
        
        print(f"\nDataframe shape: {df.shape}")
        print(f"Columns found: {list(df.columns)}")
        
        # Display first few rows to understand structure
        print("\nFirst 5 rows of data:")
        print(df.head())
        
        # Try to identify the client/company column
        # Usually it's the first column or has 'client', 'company', 'nombre', etc.
        potential_columns = ['Cliente', 'Company', 'Empresa', 'Nombre', 'Name', 'Razon Social']
        
        client_column = None
        for col in df.columns:
            if any(name.lower() in str(col).lower() for name in ['client', 'empresa', 'nombre', 'company', 'razon']):
                client_column = col
                break
        
        # If not found, use first column
        if client_column is None and not df.empty:
            client_column = df.columns[0]
        
        if client_column:
            print(f"\nUsing column '{client_column}' for client names")
            
            # Extract unique client names
            clients = df[client_column].dropna().unique()
            
            # Clean and filter client names
            cleaned_clients = []
            for client in clients:
                client_str = str(client).strip()
                # Skip empty, numeric-only, or very short entries
                if client_str and client_str != 'nan' and len(client_str) > 2:
                    # Skip if it looks like a header or total row
                    if not any(skip in client_str.lower() for skip in ['total', 'subtotal', 'sum', 'cliente', 'company']):
                        cleaned_clients.append(client_str)
            
            # Sort alphabetically
            cleaned_clients = sorted(set(cleaned_clients))
            
            print(f"\nFound {len(cleaned_clients)} unique client names")
            
            # Show first 10 as preview
            print("\nFirst 10 clients:")
            for i, client in enumerate(cleaned_clients[:10], 1):
                print(f"  {i}. {client}")
            
            if len(cleaned_clients) > 10:
                print(f"  ... and {len(cleaned_clients) - 10} more")
            
            # Save to JSON for the HTML file
            with open('clients_from_tab2.json', 'w', encoding='utf-8') as f:
                json.dump(cleaned_clients, f, ensure_ascii=False, indent=2)
            
            print(f"\nSaved {len(cleaned_clients)} client names to clients_from_tab2.json")
            
        else:
            print("\nError: Could not identify client column")
            
    else:
        print("\nError: Excel file doesn't have a second tab!")
        
except Exception as e:
    print(f"\nError reading Excel file: {e}")
    print("\nTrying to list available files in directory...")
    import os
    dir_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\-- Base de Clientes"
    if os.path.exists(dir_path):
        files = os.listdir(dir_path)
        print("Files in directory:")
        for f in files:
            if '.xls' in f.lower():
                print(f"  - {f}")