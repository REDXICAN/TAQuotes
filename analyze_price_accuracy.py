import pandas as pd
import json
import re
from collections import defaultdict

# File paths
COMPLETE_FILE = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\turbo-air-extractor\turbo_air_100_complete_final_fixed.xlsx"
PRICE_LIST_FILE = r"D:\OneDrive\Documentos\-- TurboAir\7 Bots\Turbots\2024 List Price Norbaja Copy.xlsx"
FIREBASE_JSON = "firebase_products_current.json"

print("=" * 80)
print("PRICE COMPARISON AND SKU MATCHING ANALYSIS")
print("=" * 80)

# Read Excel files
print("\n1. Loading Excel files...")
try:
    # Read the complete file (has prices in column X)
    df_complete = pd.read_excel(COMPLETE_FILE, usecols=['A', 'X'], header=0)
    df_complete.columns = ['SKU', 'Current_Price']
    df_complete['SKU'] = df_complete['SKU'].astype(str).str.strip()
    print(f"   ✓ Complete file loaded: {len(df_complete)} products")
    
    # Read the price list file (has prices in column E)
    df_price_list = pd.read_excel(PRICE_LIST_FILE, usecols=['A', 'E'], header=0)
    df_price_list.columns = ['SKU', 'New_Price']
    df_price_list['SKU'] = df_price_list['SKU'].astype(str).str.strip()
    print(f"   ✓ Price list loaded: {len(df_price_list)} products")
    
except Exception as e:
    print(f"   ✗ Error loading files: {e}")
    exit(1)

# Load Firebase data
print("\n2. Loading Firebase database...")
with open(FIREBASE_JSON, 'r') as f:
    firebase_data = json.load(f)
print(f"   ✓ Firebase data loaded: {len(firebase_data)} products")

# Analyze SKU patterns
print("\n3. Analyzing SKU patterns...")

def normalize_sku(sku):
    """Normalize SKU for comparison - remove spaces and convert to uppercase"""
    if pd.isna(sku):
        return None
    return str(sku).strip().upper().replace(" ", "")

# Normalize SKUs in all datasets
df_complete['SKU_normalized'] = df_complete['SKU'].apply(normalize_sku)
df_price_list['SKU_normalized'] = df_price_list['SKU'].apply(normalize_sku)

# Create Firebase SKU mapping
firebase_sku_map = {}
for key, product in firebase_data.items():
    if 'sku' in product:
        normalized = normalize_sku(product['sku'])
        if normalized:
            firebase_sku_map[normalized] = {
                'key': key,
                'original_sku': product['sku'],
                'current_price': product.get('price', 0)
            }

print(f"   ✓ Normalized {len(firebase_sku_map)} Firebase SKUs")

# Find exact matches
print("\n4. Finding EXACT SKU matches...")

exact_matches = []
no_match_complete = []
no_match_price_list = []

# Check each SKU in the complete file
for idx, row in df_complete.iterrows():
    sku_norm = row['SKU_normalized']
    if not sku_norm:
        continue
    
    # Find in price list
    price_match = df_price_list[df_price_list['SKU_normalized'] == sku_norm]
    
    if not price_match.empty:
        new_price = price_match.iloc[0]['New_Price']
        exact_matches.append({
            'SKU': row['SKU'],
            'Current_Price': row['Current_Price'],
            'New_Price': new_price,
            'In_Firebase': sku_norm in firebase_sku_map
        })
    else:
        no_match_complete.append(row['SKU'])

# Check SKUs in price list that aren't in complete file
for idx, row in df_price_list.iterrows():
    sku_norm = row['SKU_normalized']
    if not sku_norm:
        continue
    
    if sku_norm not in df_complete['SKU_normalized'].values:
        no_match_price_list.append(row['SKU'])

print(f"\n   EXACT MATCHES: {len(exact_matches)}")
print(f"   NO MATCH (in complete but not in price list): {len(no_match_complete)}")
print(f"   NO MATCH (in price list but not in complete): {len(no_match_price_list)}")

# Show sample of exact matches
print("\n5. Sample of EXACT matches (first 10):")
print("-" * 80)
for i, match in enumerate(exact_matches[:10]):
    price_diff = ''
    if pd.notna(match['Current_Price']) and pd.notna(match['New_Price']):
        try:
            curr = float(match['Current_Price'])
            new = float(match['New_Price'])
            diff = new - curr
            pct = (diff / curr * 100) if curr != 0 else 0
            price_diff = f" | Diff: ${diff:,.2f} ({pct:+.1f}%)"
        except:
            pass
    
    firebase_status = "✓ In Firebase" if match['In_Firebase'] else "✗ Not in Firebase"
    print(f"   {match['SKU']}: ${match['Current_Price']} → ${match['New_Price']}{price_diff} [{firebase_status}]")

# Analyze potential broad matches (similar SKUs)
print("\n6. Analyzing SKU pattern similarities...")

def extract_sku_pattern(sku):
    """Extract the base pattern from a SKU (e.g., TSR-23SD from TSR-23SD-N)"""
    if not sku:
        return None
    # Remove common suffixes
    base = re.sub(r'[-/]N\d*$', '', str(sku))
    base = re.sub(r'[-/][A-Z]$', '', base)
    return base

# Group by patterns
pattern_groups = defaultdict(list)
for sku in df_complete['SKU'].dropna():
    pattern = extract_sku_pattern(sku)
    if pattern:
        pattern_groups[pattern].append(sku)

print(f"\n   Found {len(pattern_groups)} unique SKU patterns")

# Find patterns with multiple variants
multi_variant_patterns = {k: v for k, v in pattern_groups.items() if len(v) > 1}
print(f"   Patterns with multiple variants: {len(multi_variant_patterns)}")

# Show examples of patterns with variants
print("\n7. Examples of SKU patterns with variants (potential confusion):")
print("-" * 80)
for pattern, skus in list(multi_variant_patterns.items())[:5]:
    print(f"   Pattern: {pattern}")
    for sku in skus[:3]:
        print(f"      - {sku}")

# Summary report
print("\n" + "=" * 80)
print("SUMMARY REPORT")
print("=" * 80)

total_complete = len(df_complete)
total_price_list = len(df_price_list)
total_firebase = len(firebase_data)

print(f"\nTotal products:")
print(f"  - Complete file: {total_complete}")
print(f"  - Price list: {total_price_list}")
print(f"  - Firebase: {total_firebase}")

print(f"\nMatching results:")
print(f"  - EXACT matches found: {len(exact_matches)} ({len(exact_matches)/total_complete*100:.1f}%)")
print(f"  - In complete but NOT in price list: {len(no_match_complete)}")
print(f"  - In price list but NOT in complete: {len(no_match_price_list)}")

# Check how many exact matches are in Firebase
firebase_matches = [m for m in exact_matches if m['In_Firebase']]
print(f"\nFirebase status:")
print(f"  - Exact matches that ARE in Firebase: {len(firebase_matches)}")
print(f"  - Exact matches NOT in Firebase: {len(exact_matches) - len(firebase_matches)}")

# Save results to JSON for review
output = {
    'summary': {
        'total_complete_file': total_complete,
        'total_price_list': total_price_list,
        'total_firebase': total_firebase,
        'exact_matches': len(exact_matches),
        'exact_matches_in_firebase': len(firebase_matches)
    },
    'exact_matches': exact_matches,
    'no_match_from_complete': no_match_complete,
    'no_match_from_price_list': no_match_price_list,
    'multi_variant_patterns': {k: v[:5] for k, v in list(multi_variant_patterns.items())[:20]}
}

with open('price_analysis_results.json', 'w') as f:
    json.dump(output, f, indent=2)

print("\n✓ Analysis saved to price_analysis_results.json")

# Create update script
print("\n8. Creating price update script...")

updates = []
for match in exact_matches:
    if match['In_Firebase']:
        sku_norm = normalize_sku(match['SKU'])
        firebase_info = firebase_sku_map[sku_norm]
        updates.append({
            'firebase_key': firebase_info['key'],
            'sku': match['SKU'],
            'old_price': firebase_info['current_price'],
            'new_price': match['New_Price']
        })

with open('price_updates_to_apply.json', 'w') as f:
    json.dump(updates, f, indent=2)

print(f"✓ Created update script with {len(updates)} price updates")
print("  Review 'price_updates_to_apply.json' before applying updates")

# Show samples of updates
print("\n9. Sample of updates to be applied (first 10):")
print("-" * 80)
for update in updates[:10]:
    print(f"   {update['sku']}: ${update['old_price']} → ${update['new_price']}")

print("\n" + "=" * 80)
print("RECOMMENDATION:")
print("=" * 80)
print(f"✓ Found {len(exact_matches)} EXACT SKU matches")
print(f"✓ {len(updates)} of these can be updated in Firebase")
print("\n⚠️  IMPORTANT: Only exact SKU matches will be updated to ensure 100% accuracy")
print("⚠️  Review 'price_updates_to_apply.json' before running the update")
print("=" * 80)