# Firebase Import Instructions - Missing Products

## Overview
This document provides instructions for importing 599 missing products from the Excel inventory into Firebase Realtime Database.

## Files Generated
1. **missing_products_to_import.json** - Contains 599 products to be imported
2. **add_missing_products_to_firebase.py** - Python script that generated the import file
3. **inventory_comparison_report.json** - Detailed comparison report

## Product Breakdown
- **Spare Parts**: 66 products (SKUs starting with "3")
- **Components**: 80 products (SKUs starting with letters like "B", "C", etc.)
- **Parts & Accessories**: 453 products (other alphanumeric codes)
- **Total**: 599 products

## Import Methods

### Method 1: Firebase Console (Recommended - Most Secure)
1. Open Firebase Console: https://console.firebase.google.com/project/taquotes/database/taquotes-default-rtdb/data
2. Navigate to `/products` node
3. Click the three-dot menu (⋮) → "Import JSON"
4. Select `missing_products_to_import.json`
5. Confirm the import

**Benefits**:
- Uses Firebase Console authentication
- Visual confirmation before import
- No CLI permission issues

### Method 2: Firebase CLI with Authentication
```bash
# Login first
firebase login

# Import with merge to avoid overwriting existing products
firebase database:update /products -d scripts/missing_products_to_import.json --project taquotes
```

### Method 3: Python Script with Firebase Admin SDK
Requires Firebase Admin SDK key (firebase-admin-key.json):

```python
import firebase_admin
from firebase_admin import credentials, db
import json

# Initialize Firebase Admin
cred = credentials.Certificate('firebase-admin-key.json')
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://taquotes-default-rtdb.firebaseio.com'
})

# Load products
with open('missing_products_to_import.json', 'r', encoding='utf-8') as f:
    products = json.load(f)

# Import to Firebase
ref = db.reference('/products')
for key, product in products.items():
    ref.child(key).set(product)
    print(f"Imported: {product['sku']}")

print(f"Successfully imported {len(products)} products")
```

## Sample Products Being Added

1. **30220L0900** - CLIP DE PLASTICO COLOR BLANCO PARA REJILLA
2. **G2F1800104NW** - REJILLA M3R24-1/2, M3F24-1/2 (24'' X 23.5'')
3. **MUF28N1** - MESA FRIA DE CONGELACIÓN BAJO MOSTRADOR, 1 PTA, RU
4. **MUR28N1** - MESA FRIA "BAJO MOSTRADOR" 1 PTA. SOLIDAS, RUEDAS
5. **PRO262HG** - GABINETE CALIENTE 2 MEDIAS PUERTAS DE CRISTAL, EN
6. **PRO26FN** - CONGELADOR VERTICAL 1 PUERTA SOLIDA, ACERO INOX.
7. **S28R813660** - RUEDA 1" SIN FRENO
8. **TBP3654NNB** - VITRINA REFRIGERADA 36", 2 ENTREPAÑOS, COLOR NEGRO
9. **TGF23SDBN** - CONGELADOR VERTICAL COLOR NEGRO, 1 PUERTA DE CRIST
10. **TGM23SDBN6** - REFRIGERADOR VERTICAL COLOR NEGRO, 1 PUERTA DE CRI

## Product Structure
Each product contains:
- `sku`: Product SKU code
- `model`: Model number (same as SKU for parts)
- `name`: Product name in Spanish
- `description`: Same as name
- `category`: "Spare Parts", "Components", or "Parts & Accessories"
- `price`: 0.0 (to be updated later)
- `currency`: "USD"
- `available`: true
- `featured`: false
- `dateAdded`: "2025-01-26"
- `lastUpdated`: "2025-01-26"
- `warehouseStock.CA`: Stock levels from Excel (available/reserved)
- `thumbnailUrl`: "" (empty - will use default icon)
- `imageUrl`: "" (empty - will use default icon)
- `imageUrl2`: "" (empty - will use default icon)

## After Import

### Verification
1. Check total product count in Firebase: Should be 1098 + 599 = 1,697 products
2. Verify a few sample SKUs are present
3. Check that warehouseStock data is correct

### Next Steps
1. Update product prices as needed
2. Add product images to Firebase Storage (optional)
3. Verify products appear correctly in the app
4. Update product categories if needed

## Notes
- All products initially assigned to warehouse "CA" (Cancún)
- Stock quantities from Excel are preserved
- Images will use the new default product icon fallback
- Prices set to $0.00 and need manual update

## Support
For issues with import:
- **Technical Lead**: andres@turboairmexico.com
- **Support**: turboairquotes@gmail.com
