import json
import requests

# Firebase database URL
DATABASE_URL = "https://taquotes-default-rtdb.firebaseio.com"

def get_products_with_asterisks():
    """Get all products that have asterisks in their SKUs"""
    print("Fetching products with asterisks...")
    
    # List of known SKUs with asterisks from the grep output
    skus_with_asterisks = [
        "TGF-72SDH*-N",
        "TGF-35SDH*-N", 
        "TGM-15SDH*-N6",
        "TGM-35SDH*-N",
        "TGM-72SDH*-N",
        "TGF-23SDH*-N",
        "TGM-47SD*-N",
        "TGF-47SDH*-N",
        "TGM-15SD*-N6",
        "TGM-47SDH*-N",
        "TGM-23SDH*-N6",
        "TGM-5SD*-N6",
        "TGM-72SD*-N",
        "TGM-20SD*-N6",
        "TGM-7SD*-N6",
        "TGM-35SD*-N",
        "TGM-12SD*-N6",
        "TGM-23SD*-N6",
        "TGM-10SD*-N6"
    ]
    
    products_to_update = []
    
    for sku in skus_with_asterisks:
        # Get the product data
        response = requests.get(f"{DATABASE_URL}/products/{sku}.json")
        if response.status_code == 200:
            product = response.json()
            if product:
                products_to_update.append({
                    'old_key': sku,
                    'new_key': sku.replace('*', ''),
                    'product': product
                })
                print(f"Found: {sku} -> {sku.replace('*', '')}")
    
    return products_to_update

def update_products(products_to_update):
    """Update products by removing asterisks from SKUs"""
    print(f"\nUpdating {len(products_to_update)} products...")
    
    for item in products_to_update:
        old_key = item['old_key']
        new_key = item['new_key']
        product = item['product']
        
        # Update the SKU field in the product
        product['sku'] = new_key
        
        # Create new product with cleaned SKU
        print(f"Creating: /products/{new_key}")
        response = requests.put(
            f"{DATABASE_URL}/products/{new_key}.json",
            json=product
        )
        
        if response.status_code == 200:
            print(f"[OK] Created {new_key}")
            
            # Delete the old product with asterisk
            print(f"Deleting: /products/{old_key}")
            del_response = requests.delete(f"{DATABASE_URL}/products/{old_key}.json")
            
            if del_response.status_code == 200:
                print(f"[OK] Deleted {old_key}")
            else:
                print(f"[ERROR] Failed to delete {old_key}: {del_response.status_code}")
        else:
            print(f"[ERROR] Failed to create {new_key}: {response.status_code}")
    
    print("\n[OK] Finished updating products")

def main():
    print("=== Removing asterisks from Firebase SKUs ===\n")
    
    # Get products with asterisks
    products_to_update = get_products_with_asterisks()
    
    if not products_to_update:
        print("No products with asterisks found")
        return
    
    print(f"\nFound {len(products_to_update)} products with asterisks")
    
    # Confirm before proceeding
    print("\nThis will:")
    print("1. Create new products with cleaned SKUs (no asterisks)")
    print("2. Delete the old products with asterisks")
    
    print("\nProceeding with updates...")
    
    # Update products
    update_products(products_to_update)
    
    print("\n=== Complete ===")

if __name__ == "__main__":
    main()