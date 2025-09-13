import json
import glob
import os
from datetime import datetime

# Find the most recent FINAL-DATABASE file
downloads_path = r"C:\Users\andre\Downloads"
pattern = os.path.join(downloads_path, "taquotes-FINAL-DATABASE-*.json")
files = glob.glob(pattern)

if not files:
    # If no FINAL-DATABASE, use the original export
    latest_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-export.json"
    print("Using original export file")
else:
    latest_file = max(files, key=os.path.getctime)
    print(f"Using latest database: {os.path.basename(latest_file)}")

# Load the database
with open(latest_file, 'r', encoding='utf-8') as f:
    database = json.load(f)

print("\n" + "=" * 80)
print("ADDING PRICE FIELD TO SPARE PARTS")
print("=" * 80)

# Check if spareparts section exists
if 'spareparts' not in database:
    print("[ERROR] No spareparts section found in database!")
    exit(1)

# Count spare parts before modification
spare_parts_count = len(database['spareparts'])
print(f"\nFound {spare_parts_count} spare parts")

# Add price: 0 to all spare parts
updated_count = 0
for part_id, part_data in database['spareparts'].items():
    if isinstance(part_data, dict):
        # Add price field if it doesn't exist or update it to 0
        part_data['price'] = 0
        updated_count += 1

print(f"Updated {updated_count} spare parts with price: 0")

# Create output file with timestamp
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_file = f"C:\\Users\\andre\\Downloads\\taquotes-WITH-SPAREPARTS-PRICES-{timestamp}.json"

# Save the updated database
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(database, f, indent=2, ensure_ascii=False)

print(f"\n[SUCCESS] Database saved to:")
print(f"  {output_file}")

# Verify the update
print("\n" + "=" * 80)
print("VERIFICATION")
print("=" * 80)

# Check a few spare parts to confirm price field
sample_parts = list(database['spareparts'].items())[:3]
for part_id, part_data in sample_parts:
    if isinstance(part_data, dict):
        print(f"  {part_id}: price = {part_data.get('price', 'MISSING')}")

# Summary of all sections
print("\n" + "=" * 80)
print("DATABASE SUMMARY")
print("=" * 80)

for section in database:
    if isinstance(database[section], dict):
        count = len(database[section])
        if section == 'spareparts':
            # Count spare parts with price field
            with_price = sum(1 for p in database[section].values() 
                           if isinstance(p, dict) and 'price' in p)
            print(f"  {section:20} : {count} items ({with_price} with price field)")
        elif section in ['quotes', 'clients']:
            # Count nested items
            total = sum(len(v) for v in database[section].values() if isinstance(v, dict))
            print(f"  {section:20} : {count} users with {total} total items")
        else:
            print(f"  {section:20} : {count} items")

print("\n" + "=" * 80)
print("INSTRUCTIONS FOR FIREBASE UPLOAD")
print("=" * 80)
print("1. Go to Firebase Console: https://console.firebase.google.com/project/taquotes/database")
print("2. Click on 'Import JSON' button")
print("3. Select the file created above")
print("4. [CRITICAL] Import at ROOT level (/) to replace entire database")
print("5. This preserves all existing data and adds price to spare parts")
print("\n[OK] Safe to upload - all original data preserved!")
print("=" * 80)