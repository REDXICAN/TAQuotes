import pandas as pd
import openpyxl

excel_file = r"D:\Flutter App\09.12.25 INVENTARIO MEXICO.xlsx"

print("=" * 80)
print("FINDING THE CORRECT STOCK TOTAL OF 10,112")
print("=" * 80)

# First check all sheets
wb = openpyxl.load_workbook(excel_file, read_only=True, data_only=True)
print("\nChecking all sheets:")
for sheet_name in wb.sheetnames:
    print(f"  - {sheet_name}")
wb.close()

# Load all sheets and check totals
excel = pd.ExcelFile(excel_file)
for sheet_name in excel.sheet_names:
    print(f"\n" + "=" * 80)
    print(f"SHEET: {sheet_name}")
    print("=" * 80)
    
    # Try different skiprows values
    for skip in [0, 1, 2, 3, 4]:
        try:
            df = pd.read_excel(excel_file, sheet_name=sheet_name, skiprows=skip)
            
            # Check each numeric column
            numeric_cols = []
            for col_idx in range(len(df.columns)):
                try:
                    # Sum numeric values in column
                    col_sum = 0
                    numeric_count = 0
                    for val in df.iloc[:, col_idx]:
                        if pd.notna(val):
                            try:
                                num_val = float(val)
                                if num_val > 0 and num_val < 100000:  # Reasonable stock range
                                    col_sum += num_val
                                    numeric_count += 1
                            except:
                                pass
                    
                    if col_sum > 0:
                        numeric_cols.append({
                            'index': col_idx,
                            'name': str(df.columns[col_idx])[:30],
                            'sum': int(col_sum),
                            'count': numeric_count
                        })
                except:
                    pass
            
            # Report findings
            if numeric_cols:
                print(f"\n  Skiprows={skip}, Columns={len(df.columns)}, Rows={len(df)}")
                for col in numeric_cols:
                    if col['sum'] > 100:  # Only show significant sums
                        print(f"    Col {col['index']:2} ({col['name']:30}): {col['sum']:,} (from {col['count']} items)")
                        
                        # Check if this might be our target
                        if 9000 < col['sum'] < 11000:
                            print(f"    >>> POSSIBLE MATCH! Close to 10,112")
                        elif col['sum'] == 10112:
                            print(f"    >>> EXACT MATCH! This is the column!")
        except Exception as e:
            pass

print("\n" + "=" * 80)
print("ANALYSIS COMPLETE")
print("=" * 80)