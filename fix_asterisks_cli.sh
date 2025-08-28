#!/bin/bash

echo "=== Fixing SKUs with asterisks using Firebase CLI ==="
echo ""

# Array of SKUs to fix
declare -a skus=(
  "TGF-72SDH*-N"
  "TGF-35SDH*-N" 
  "TGM-15SDH*-N6"
  "TGM-35SDH*-N"
  "TGM-72SDH*-N"
  "TGF-23SDH*-N"
  "TGM-47SD*-N"
  "TGF-47SDH*-N"
  "TGM-15SD*-N6"
  "TGM-47SDH*-N"
  "TGM-23SDH*-N6"
  "TGM-5SD*-N6"
  "TGM-72SD*-N"
  "TGM-20SD*-N6"
  "TGM-7SD*-N6"
  "TGM-35SD*-N"
  "TGM-12SD*-N6"
  "TGM-23SD*-N6"
  "TGM-10SD*-N6"
)

echo "Processing ${#skus[@]} SKUs..."
echo ""

for sku in "${skus[@]}"
do
  # Remove asterisk from SKU
  clean_sku="${sku//\*/}"
  
  echo "Processing: $sku -> $clean_sku"
  
  # Get the product data
  echo "  Getting product data..."
  firebase database:get "/products/$sku" > temp_product.json
  
  # Check if product exists
  if [ -s temp_product.json ] && [ "$(cat temp_product.json)" != "null" ]; then
    # Update the sku field in the JSON
    sed -i "s/\"sku\":\"$sku\"/\"sku\":\"$clean_sku\"/g" temp_product.json
    
    # Create new product with clean SKU
    echo "  Creating /products/$clean_sku"
    firebase database:set "/products/$clean_sku" temp_product.json
    
    # Delete old product with asterisk
    echo "  Deleting /products/$sku"
    firebase database:remove "/products/$sku"
    
    echo "  ✓ Done"
  else
    echo "  ⚠ Product not found"
  fi
  
  echo ""
done

# Clean up
rm -f temp_product.json

echo "=== Complete ==="