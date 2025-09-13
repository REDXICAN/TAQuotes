import json
import glob
import os
from datetime import datetime

# Find the most recent database file with spare parts prices
downloads_path = r"C:\Users\andre\Downloads"
pattern = os.path.join(downloads_path, "taquotes-WITH-SPAREPARTS-PRICES-*.json")
files = glob.glob(pattern)

if files:
    latest_file = max(files, key=os.path.getctime)
else:
    latest_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-export.json"

print(f"Loading: {os.path.basename(latest_file)}")
print("=" * 80)

with open(latest_file, 'r', encoding='utf-8') as f:
    database = json.load(f)

print("CORRECTING DATABASE STRUCTURE")
print("=" * 80)

# Step 1: Find orphaned profile
orphaned_uid = None
if 'users' in database and 'user_profiles' in database:
    users_uids = set(database['users'].keys())
    profiles_uids = set(database['user_profiles'].keys())
    profiles_only = profiles_uids - users_uids
    
    if profiles_only:
        orphaned_uid = list(profiles_only)[0]
        print(f"Found orphaned profile: {orphaned_uid}")
        
        # Create a corresponding user entry from the profile data
        profile = database['user_profiles'][orphaned_uid]
        
        # Create user entry from profile
        new_user = {
            'uid': profile.get('uid', orphaned_uid),
            'email': profile.get('email', ''),
            'displayName': profile.get('name', profile.get('displayName', '')),
            'createdAt': profile.get('created_at', profile.get('createdAt', 0)),
            'emailVerified': False,
            'role': profile.get('role', 'user').lower()
        }
        
        # Add to users section
        database['users'][orphaned_uid] = new_user
        print(f"  Created user entry for: {profile.get('email', 'unknown')}")

# Step 2: Ensure all users have profiles
users_without_profiles = set(database.get('users', {}).keys()) - set(database.get('user_profiles', {}).keys())
if users_without_profiles:
    print(f"Found {len(users_without_profiles)} users without profiles")
    for uid in users_without_profiles:
        user = database['users'][uid]
        # Create profile from user data
        new_profile = {
            'uid': uid,
            'email': user.get('email', ''),
            'displayName': user.get('displayName', ''),
            'name': user.get('displayName', ''),
            'role': user.get('role', 'user'),
            'createdAt': user.get('createdAt', 0),
            'updatedAt': user.get('createdAt', 0),
            'company': '',
            'phoneNumber': '',
            'photoURL': '',
            'status': 'active',
            'settings': {
                'emailNotifications': True,
                'pushNotifications': False,
                'theme': 'light',
                'language': 'en'
            }
        }
        database['user_profiles'][uid] = new_profile
        print(f"  Created profile for: {user.get('email', 'unknown')}")

# Step 3: Standardize field names in profiles
print("\nStandardizing profile fields...")
for uid, profile in database.get('user_profiles', {}).items():
    if isinstance(profile, dict):
        # Standardize created_at to createdAt
        if 'created_at' in profile and 'createdAt' not in profile:
            profile['createdAt'] = profile['created_at']
            del profile['created_at']
        
        # Standardize updated_at to updatedAt
        if 'updated_at' in profile and 'updatedAt' not in profile:
            profile['updatedAt'] = profile['updated_at']
            del profile['updated_at']
        
        # Ensure name field exists
        if 'name' not in profile and 'displayName' in profile:
            profile['name'] = profile['displayName']
        elif 'displayName' not in profile and 'name' in profile:
            profile['displayName'] = profile['name']
        
        # Ensure settings exist
        if 'settings' not in profile:
            profile['settings'] = {
                'emailNotifications': True,
                'pushNotifications': False,
                'theme': 'light',
                'language': 'en'
            }
        
        # Ensure status exists
        if 'status' not in profile:
            profile['status'] = 'active'

print("Profile fields standardized")

# Step 4: Verify spare parts have all required fields
print("\nVerifying spare parts structure...")
if 'spareparts' in database:
    for part_id, part in database['spareparts'].items():
        if isinstance(part, dict):
            # Ensure all required fields exist
            if 'price' not in part:
                part['price'] = 0
            if 'sku' not in part:
                part['sku'] = part_id
            if 'name' not in part and 'description' in part:
                part['name'] = part['description']
            elif 'name' not in part:
                part['name'] = ''
            if 'stock' not in part:
                part['stock'] = 0
    print(f"  Verified {len(database['spareparts'])} spare parts")

# Create output file with timestamp
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_file = f"C:\\Users\\andre\\Downloads\\taquotes-CORRECTED-COMPLETE-{timestamp}.json"

# Save the corrected database
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(database, f, indent=2, ensure_ascii=False)

print(f"\n[SUCCESS] Corrected database saved to:")
print(f"  {output_file}")

# Final verification
print("\n" + "=" * 80)
print("FINAL VERIFICATION")
print("=" * 80)

for section in sorted(database.keys()):
    if isinstance(database[section], dict):
        count = len(database[section])
        if section in ['quotes', 'clients']:
            # Count nested items
            total = sum(len(v) for v in database[section].values() if isinstance(v, dict))
            print(f"  {section:20} : {count} users with {total} total items")
        elif section == 'spareparts':
            # Check spare parts have price
            with_price = sum(1 for p in database[section].values() 
                           if isinstance(p, dict) and 'price' in p)
            total_stock = sum(p.get('stock', 0) for p in database[section].values() if isinstance(p, dict))
            print(f"  {section:20} : {count} items ({with_price} with price, {total_stock} total stock)")
        elif section == 'products':
            # Check products stock
            total_stock = sum(p.get('stock', 0) for p in database[section].values() if isinstance(p, dict))
            with_stock = sum(1 for p in database[section].values() if isinstance(p, dict) and p.get('stock', 0) > 0)
            print(f"  {section:20} : {count} items ({with_stock} with stock, {total_stock} total units)")
        else:
            print(f"  {section:20} : {count} items")

# Check sync between users and profiles
users_count = len(database.get('users', {}))
profiles_count = len(database.get('user_profiles', {}))
print(f"\nUser sync check:")
print(f"  Users: {users_count}")
print(f"  Profiles: {profiles_count}")
if users_count == profiles_count:
    print(f"  [OK] Users and profiles are synchronized!")
else:
    print(f"  [WARNING] Mismatch between users and profiles!")

# Total inventory check
products_stock = sum(p.get('stock', 0) for p in database.get('products', {}).values() if isinstance(p, dict))
spareparts_stock = sum(p.get('stock', 0) for p in database.get('spareparts', {}).values() if isinstance(p, dict))
total_inventory = products_stock + spareparts_stock
print(f"\nTotal inventory:")
print(f"  Products: {products_stock} units")
print(f"  Spare parts: {spareparts_stock} units")
print(f"  TOTAL: {total_inventory} units")

print("\n" + "=" * 80)
print("UPLOAD INSTRUCTIONS")
print("=" * 80)
print("1. Go to: https://console.firebase.google.com/project/taquotes/database")
print("2. Click 'Import JSON'")
print("3. Select the file created above")
print("4. Import at ROOT (/) to replace entire database")
print("\n[OK] Database is corrected and ready for upload!")
print("=" * 80)