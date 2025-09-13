import json

database_json = r"C:\Users\andre\Downloads\taquotes-default-rtdb-export.json"

print("=" * 80)
print("CHECKING QUOTES IN DATABASE")
print("=" * 80)

# Load database
with open(database_json, 'r', encoding='utf-8') as f:
    database = json.load(f)

# Check quotes section
if 'quotes' in database:
    quotes = database['quotes']
    print(f"\nQuotes section type: {type(quotes)}")
    
    if isinstance(quotes, dict):
        print(f"Total quote entries: {len(quotes)}")
        
        # Count actual quotes (might be nested by user)
        total_quotes = 0
        quotes_by_user = {}
        
        for key, value in quotes.items():
            if isinstance(value, dict):
                # Check if this is a user ID with nested quotes
                nested_count = 0
                for subkey, subvalue in value.items():
                    if isinstance(subvalue, dict):
                        nested_count += 1
                
                if nested_count > 0:
                    quotes_by_user[key] = nested_count
                    total_quotes += nested_count
                else:
                    # This might be a direct quote
                    total_quotes += 1
        
        print(f"\nQuotes structure:")
        if quotes_by_user:
            print("  Quotes are organized by user ID:")
            for user_id, count in quotes_by_user.items():
                print(f"    User {user_id[:20]}... : {count} quotes")
        
        print(f"\nTotal actual quotes: {total_quotes}")
        
        # Show sample quote structure
        print("\nSample quote keys (first level):")
        for i, key in enumerate(list(quotes.keys())[:5]):
            print(f"  - {key}")
            
else:
    print("No quotes section found in database!")

# Also check other sections
print("\n" + "=" * 80)
print("ALL DATABASE SECTIONS:")
print("=" * 80)

for section, data in database.items():
    if isinstance(data, dict):
        # Check for nested structure
        first_key = list(data.keys())[0] if data else None
        if first_key and isinstance(data[first_key], dict):
            # Count nested items
            nested_total = 0
            for key, value in data.items():
                if isinstance(value, dict):
                    nested_total += len(value) if isinstance(value, dict) else 1
            print(f"{section:20} : {len(data)} top-level, {nested_total} total nested items")
        else:
            print(f"{section:20} : {len(data)} items")
    else:
        print(f"{section:20} : single value")

print("\n" + "=" * 80)