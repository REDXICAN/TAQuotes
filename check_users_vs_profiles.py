import json
import glob
import os

# Find the most recent database file
downloads_path = r"C:\Users\andre\Downloads"
pattern = os.path.join(downloads_path, "taquotes-WITH-SPAREPARTS-PRICES-*.json")
files = glob.glob(pattern)

if not files:
    pattern = os.path.join(downloads_path, "taquotes-FINAL-DATABASE-*.json")
    files = glob.glob(pattern)

if files:
    latest_file = max(files, key=os.path.getctime)
else:
    latest_file = r"C:\Users\andre\Downloads\taquotes-default-rtdb-export.json"

print(f"Analyzing: {os.path.basename(latest_file)}")
print("=" * 80)

with open(latest_file, 'r', encoding='utf-8') as f:
    database = json.load(f)

# Analyze users section
print("\nUSERS SECTION:")
print("-" * 40)
if 'users' in database:
    print(f"Total users: {len(database['users'])}")
    # Show structure of first user
    for uid, user_data in list(database['users'].items())[:2]:
        print(f"\nUser ID: {uid[:20]}...")
        if isinstance(user_data, dict):
            print("  Fields:")
            for key in user_data.keys():
                value = user_data[key]
                if isinstance(value, str) and len(value) > 30:
                    print(f"    - {key}: {value[:30]}...")
                else:
                    print(f"    - {key}: {value}")
        print()

# Analyze user_profiles section
print("\nUSER_PROFILES SECTION:")
print("-" * 40)
if 'user_profiles' in database:
    print(f"Total profiles: {len(database['user_profiles'])}")
    # Show structure of first profile
    for uid, profile_data in list(database['user_profiles'].items())[:2]:
        print(f"\nProfile ID: {uid[:20]}...")
        if isinstance(profile_data, dict):
            print("  Fields:")
            for key in profile_data.keys():
                value = profile_data[key]
                if isinstance(value, str) and len(value) > 30:
                    print(f"    - {key}: {value[:30]}...")
                else:
                    print(f"    - {key}: {value}")
        print()

# Compare UIDs
print("\nCOMPARISON:")
print("-" * 40)
if 'users' in database and 'user_profiles' in database:
    users_uids = set(database['users'].keys())
    profiles_uids = set(database['user_profiles'].keys())
    
    print(f"Users count: {len(users_uids)}")
    print(f"Profiles count: {len(profiles_uids)}")
    
    # Check overlap
    common = users_uids & profiles_uids
    users_only = users_uids - profiles_uids
    profiles_only = profiles_uids - users_uids
    
    print(f"\nUIDs in both: {len(common)}")
    print(f"UIDs only in users: {len(users_only)}")
    print(f"UIDs only in profiles: {len(profiles_only)}")
    
    if profiles_only:
        print(f"\nProfile-only UID: {list(profiles_only)[0]}")

print("\n" + "=" * 80)
print("SUMMARY:")
print("-" * 40)
print("USERS: Basic Firebase Auth data (email, created date)")
print("USER_PROFILES: Extended app-specific data (name, role, company, preferences)")
print("=" * 80)