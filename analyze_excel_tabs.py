import pandas as pd
import json

print("=" * 80)
print("ANALYZING EXCEL FILE STRUCTURE - ALL TABS")
print("=" * 80)

excel_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\-- Base de Clientes\Reporte de Ventas x Cliente Agosto 2025.xls"

try:
    # Read all sheet names
    xl_file = pd.ExcelFile(excel_path)
    print(f"\nFound {len(xl_file.sheet_names)} sheets:")
    for i, sheet_name in enumerate(xl_file.sheet_names):
        print(f"\n{'='*60}")
        print(f"TAB {i+1}: '{sheet_name}'")
        print('='*60)
        
        # Read the tab
        df = pd.read_excel(excel_path, sheet_name=i, header=None)
        
        print(f"Shape: {df.shape}")
        print(f"\nFirst 20 rows (to find where client data starts):")
        print("-" * 40)
        
        # Show first 20 rows to understand structure
        for idx in range(min(20, len(df))):
            row_data = df.iloc[idx].dropna().tolist()
            if row_data:  # Only show non-empty rows
                print(f"Row {idx}: {row_data[:5]}")  # Show first 5 columns
        
        # Try to find rows that look like client names
        print(f"\n{'='*40}")
        print("SEARCHING FOR CLIENT-LIKE DATA:")
        print('='*40)
        
        # Check each column for potential client names
        for col_idx in range(min(5, len(df.columns))):  # Check first 5 columns
            col_data = df.iloc[:, col_idx].dropna()
            
            # Filter for strings that look like company names
            potential_clients = []
            for val in col_data:
                val_str = str(val).strip()
                # Look for entries that:
                # - Are strings (not numbers)
                # - Have more than 5 characters
                # - Don't look like headers or codes
                if (len(val_str) > 5 and 
                    not val_str.replace('.', '').replace('-', '').isdigit() and
                    not any(skip in val_str.lower() for skip in ['total', 'codigo', 'reporte', 'fecha', 'cantidad', 'nombre'])):
                    
                    # Check if it looks like a company name (has letters and possibly some special chars)
                    if any(c.isalpha() for c in val_str) and val_str[0].isalpha():
                        potential_clients.append(val_str)
            
            if potential_clients:
                print(f"\nColumn {col_idx} - Found {len(potential_clients)} potential client names:")
                for j, client in enumerate(potential_clients[:5], 1):
                    print(f"  {j}. {client}")
                if len(potential_clients) > 5:
                    print(f"  ... and {len(potential_clients) - 5} more")
                    
except Exception as e:
    print(f"\nError: {e}")

print("\n" + "=" * 80)
print("Let me now look for the actual client data in the raw Excel file...")
print("=" * 80)

# Try reading with different parameters
try:
    # Read second sheet skipping header rows
    for skip_rows in [0, 5, 10, 15]:
        print(f"\n--- Reading Tab 2 skipping {skip_rows} rows ---")
        df = pd.read_excel(excel_path, sheet_name=1, skiprows=skip_rows, nrows=20)
        
        print("Columns:", list(df.columns)[:5])
        
        # Look for column that might contain client names
        for col in df.columns:
            col_data = df[col].dropna()
            # Check if this column has text that looks like company names
            text_entries = [str(x) for x in col_data if len(str(x)) > 10 and any(c.isalpha() for c in str(x))]
            if text_entries:
                print(f"  Column '{col}' has text entries:")
                for entry in text_entries[:3]:
                    print(f"    - {entry}")
                break
                
except Exception as e:
    print(f"Error in alternative reading: {e}")