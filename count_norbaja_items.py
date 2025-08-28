import pandas as pd

excel_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\2024 List Price Norbaja Copy.xlsx"
print(f"Counting items in Norbaja Excel file...")

# Read Excel
df = pd.read_excel(excel_path, header=None)
print(f"Total rows in Excel: {len(df)}")

# Count actual product SKUs (starting from row 7)
skus = []
for idx in range(7, len(df)):
    val = df.iloc[idx, 0]  # Column A has the Model/SKU
    if pd.notna(val):
        val_str = str(val).strip()
        # Check if it's a SKU (has dash, not a description)
        if (val_str and 
            '-' in val_str and 
            len(val_str) < 50 and
            not val_str.startswith('*') and
            not any(word in val_str.lower() for word in ['series', 'optional', 'available', 'please', 'display', 'back bars', 'beer', 'bottle'])):
            skus.append(val_str)

# Get unique SKUs
unique_skus = list(set(skus))

print(f"\n=== NORBAJA EXCEL SUMMARY ===")
print(f"Total product rows: {len(skus)}")
print(f"Unique SKUs: {len(unique_skus)}")

# Show some examples
print(f"\nFirst 10 SKUs:")
for sku in skus[:10]:
    print(f"  - {sku}")

print(f"\nLast 10 SKUs:")
for sku in skus[-10:]:
    print(f"  - {sku}")