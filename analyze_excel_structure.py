import pandas as pd

excel_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\2024 List Price Norbaja Copy.xlsx"
print(f"Analyzing Excel structure...")

df = pd.read_excel(excel_path, header=None)  # Read without header
print(f"Shape: {df.shape}")

# Show first 20 rows and 5 columns to understand structure
print("\n=== First 20 rows x 5 columns ===")
print(df.iloc[:20, :5])

# Look for row with "Model" or "SKU" header
for idx, row in df.iterrows():
    row_str = str(row.tolist()).lower()
    if 'model' in row_str or 'sku' in row_str:
        print(f"\nFound potential header row at index {idx}:")
        print(row.tolist()[:5])
        if idx < len(df) - 5:
            print(f"\nNext 5 rows after header:")
            for i in range(1, 6):
                print(f"Row {idx+i}: {df.iloc[idx+i, :5].tolist()}")
        break