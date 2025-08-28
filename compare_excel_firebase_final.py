import pandas as pd
import requests
import re

excel_path = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\2024 List Price Norbaja Copy.xlsx"
print("Comparing Excel SKUs with Firebase database...")

# Read Excel
df = pd.read_excel(excel_path, header=None)

# Extract SKUs from column 0 (Model No.)
excel_skus = []
for idx in range(7, len(df)):  # Start from row 7 where actual SKUs begin
    val = df.iloc[idx, 0]
    if pd.notna(val):
        val_str = str(val).strip()
        # Check if it looks like a SKU (has dash, not too long, not a description)
        if (val_str and 
            '-' in val_str and 
            len(val_str) < 50 and
            not val_str.startswith('*') and
            not any(word in val_str.lower() for word in ['series', 'optional', 'available', 'please'])):
            excel_skus.append(val_str)

print(f"Found {len(excel_skus)} SKUs in Excel")
print("Sample Excel SKUs:", excel_skus[:10])

# Get unique SKUs
excel_skus_unique = list(set(excel_skus))
print(f"Unique Excel SKUs: {len(excel_skus_unique)}")

# Get Firebase SKUs
print("\nFetching Firebase products...")
response = requests.get("https://taquotes-default-rtdb.firebaseio.com/products.json?shallow=true")
firebase_products = response.json()
firebase_skus = list(firebase_products.keys())
print(f"Firebase SKUs: {len(firebase_skus)}")

# Compare sets
excel_set = set(excel_skus_unique)
firebase_set = set(firebase_skus)

# Find missing (in Excel but not in Firebase)
missing_in_firebase = excel_set - firebase_set

# Clean up parentheses for comparison
# Some Excel SKUs have (-L) or similar, Firebase might not
excel_cleaned = set()
for sku in excel_set:
    # Remove parentheses and contents for comparison
    base_sku = re.sub(r'\([^)]*\)', '', sku).strip()
    excel_cleaned.add(base_sku)

firebase_cleaned = set()
for sku in firebase_set:
    base_sku = re.sub(r'\([^)]*\)', '', sku).strip()
    firebase_cleaned.add(base_sku)

missing_cleaned = excel_cleaned - firebase_cleaned

print(f"\n=== RESULTS ===")
print(f"Excel unique SKUs: {len(excel_set)}")
print(f"Firebase SKUs: {len(firebase_set)}")
print(f"Missing in Firebase (exact match): {len(missing_in_firebase)}")
print(f"Missing in Firebase (ignoring parentheses): {len(missing_cleaned)}")

if missing_cleaned:
    print(f"\n=== MISSING SKUs (base SKU without parentheses) ===")
    missing_list = sorted(list(missing_cleaned))
    for sku in missing_list[:30]:
        print(f"  - {sku}")
    if len(missing_list) > 30:
        print(f"  ... and {len(missing_list) - 30} more")
    
    # Save to file
    with open('excel_skus_missing_from_firebase.txt', 'w') as f:
        f.write("=== SKUs in Excel but NOT in Firebase ===\n")
        f.write(f"Total missing: {len(missing_cleaned)}\n\n")
        for sku in missing_list:
            f.write(f"{sku}\n")
    print(f"\nFull list saved to: excel_skus_missing_from_firebase.txt")
else:
    print("\n✓ All Excel SKUs are in Firebase!")

# Also check what's in Firebase but not in Excel
extra_in_firebase = firebase_cleaned - excel_cleaned
if extra_in_firebase:
    print(f"\n=== In Firebase but NOT in Excel: {len(extra_in_firebase)} ===")
    extra_list = sorted(list(extra_in_firebase))[:20]
    for sku in extra_list:
        print(f"  - {sku}")