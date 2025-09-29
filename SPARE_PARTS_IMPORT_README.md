# Spare Parts Import Guide

## Overview
This guide explains how to extract and import real spare parts data from the Mexico inventory Excel file into the Firebase database for the Turbo Air Quotes (TAQ) application.

## Files Created
- `extract_spare_parts.py` - Python script to extract spare parts from Excel
- `spare_parts_extracted.json` - Generated JSON file with spare parts data
- `import_spare_parts.dart` - Dart script to import data to Firebase
- `lib/core/services/spare_parts_import_service.dart` - Service for Firebase operations
- `lib/features/admin/presentation/widgets/spare_parts_import_widget.dart` - UI widget

## Step-by-Step Process

### Step 1: Extract Spare Parts from Excel
1. Ensure Python with pandas is installed:
   ```bash
   pip install pandas openpyxl
   ```

2. Run the extraction script:
   ```bash
   python extract_spare_parts.py
   ```

3. This will:
   - Read `O:\OneDrive\Documentos\-- TurboAir\7 Bots\09.12.25 INVENTARIO MEXICO.xlsx`
   - Identify 94 spare parts based on keywords (clip, rejilla, filtro, etc.)
   - Extract SKUs, names, and warehouse stock quantities
   - Generate `spare_parts_extracted.json`

### Step 2: Import to Firebase (via Admin Panel)
1. Launch the Flutter app:
   ```bash
   flutter run -d chrome
   ```

2. Login as admin (andres@turboairmexico.com)

3. Navigate to Admin Panel

4. Scroll down to "Spare Parts Import" section

5. Click "Import Spare Parts" button

6. The system will:
   - First try to find `spare_parts_extracted.json` in the project root
   - If not found, open a file picker to select the JSON file
   - Parse the JSON data (94 spare parts)
   - Import each spare part to Firebase products collection
   - Create warehouse stock entries for all 16 warehouses

### Step 3: Verify Import
1. Check the "Current spare parts in database" counter
2. Visit the Products screen and filter by "Spare Parts" category
3. Check warehouse stock levels in the Stock Dashboard

## Data Structure

### Extracted Spare Parts Data
```json
{
  "sku": "30220L0900",
  "name": "CLIP DE PLASTICO COLOR BLANCO PARA REJILLA",
  "category": "Spare Parts",
  "price": 0.0,
  "warehouse_stock": {
    "999": 479,
    "CA": 0,
    "CA1": 0,
    // ... all 16 warehouses
  },
  "description": "Spare part: CLIP DE PLASTICO COLOR BLANCO PARA REJILLA",
  "original_row": 8
}
```

### Firebase Structure
Products are stored in:
- `/products/{sku}` - Product information
- `/warehouse_stock/{warehouse}/{sku}` - Stock levels per warehouse

## Supported Warehouses
- 999, CA, CA1, CA2, CA3, CA4
- COCZ, COPZ, INT, MEE, PU, SI
- XCA, XPU, XZRE, ZRE

## Keywords for Spare Parts Detection
Spanish and English keywords are used to identify spare parts:
- clip, rejilla, filtro, filter, belt, motor, fan
- bearing, gasket, seal, valve, sensor, switch
- relay, fuse, thermostat, capacitor, contactor
- coil, evaporator, condenser, compressor
- And many more...

## Sample Extracted Spare Parts
1. **CLIP DE PLASTICO COLOR BLANCO PARA REJILLA** (30220L0900) - 479 units in warehouse 999
2. **REJILLA M3R24-1/2, M3F24-1/2 (24'' X 23.5'')** (G2F1800104NW) - 11 units in warehouse 999
3. And 92 more spare parts with real inventory levels

## Admin Functions
The admin panel provides:
- **Import Spare Parts** - Import from JSON file
- **Refresh Count** - Update current spare parts count
- **Clear All** - Remove all spare parts (with confirmation)

## Troubleshooting

### Python Script Issues
- Ensure Excel file path is correct
- Check pandas installation: `pip install pandas openpyxl`
- Verify file permissions

### Flutter Import Issues
- Ensure Firebase is configured
- Check admin permissions
- Verify JSON file format
- Use file picker if default path fails

### Firebase Issues
- Check Firebase console for errors
- Verify database security rules
- Ensure admin authentication

## Success Metrics
- **Products Extracted**: 94 spare parts from 890 total items
- **Keywords Matched**: Spanish/English spare parts terminology
- **Warehouses**: All 16 warehouse locations supported
- **Data Quality**: Real inventory quantities from December 2024

## Next Steps
After successful import:
1. Verify spare parts appear in product catalog
2. Check stock levels in Stock Dashboard
3. Test quote creation with spare parts
4. Update pricing if needed (currently set to 0.0)

---
**Note**: This process imports REAL inventory data from the TurboAir Mexico warehouse system. Handle with care in production environment.