import pandas as pd
import json

print("=" * 80)
print("EXTRACTING REAL CLIENT NAMES FROM EXCEL")
print("=" * 80)

excel_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\-- Base de Clientes\Reporte de Ventas x Cliente Agosto 2025.xls"

try:
    # Read the second tab (Cliente Final)
    df = pd.read_excel(excel_path, sheet_name=1, header=None)
    
    print(f"Reading 'Cliente Final' tab")
    print(f"Total rows: {len(df)}")
    
    # Extract client names
    # Pattern: Row with "Nombre:" in column 0 has the client name in column 1
    client_names = []
    
    for idx in range(len(df)):
        # Check if column 0 contains "Nombre:"
        if pd.notna(df.iloc[idx, 0]) and str(df.iloc[idx, 0]).strip() == "Nombre:":
            # Get the client name from column 1
            if pd.notna(df.iloc[idx, 1]):
                client_name = str(df.iloc[idx, 1]).strip()
                if client_name and client_name not in client_names:
                    client_names.append(client_name)
    
    # Sort alphabetically
    client_names = sorted(client_names)
    
    print(f"\nFound {len(client_names)} unique client companies")
    
    # Show first 20 as preview
    print("\nFirst 20 clients:")
    for i, client in enumerate(client_names[:20], 1):
        print(f"  {i}. {client}")
    
    if len(client_names) > 20:
        print(f"  ... and {len(client_names) - 20} more")
    
    # Save to JSON file
    with open('real_clients_from_excel.json', 'w', encoding='utf-8') as f:
        json.dump(client_names, f, ensure_ascii=False, indent=2)
    
    print(f"\nSaved {len(client_names)} client names to real_clients_from_excel.json")
    
    # Also show last 5 clients
    print("\nLast 5 clients:")
    for i, client in enumerate(client_names[-5:], len(client_names) - 4):
        print(f"  {i}. {client}")
        
except Exception as e:
    print(f"\nError: {e}")
    import traceback
    traceback.print_exc()