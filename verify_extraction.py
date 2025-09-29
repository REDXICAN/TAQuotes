#!/usr/bin/env python3
"""
Verify spare parts extraction results
"""

import json
import os

def verify_extraction():
    json_file = 'spare_parts_extracted.json'

    if not os.path.exists(json_file):
        print(f"ERROR: File not found: {json_file}")
        return False

    try:
        # Read with UTF-8 encoding
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        print("SUCCESS: Successfully loaded JSON file")
        print(f"Total spare parts extracted: {len(data)}")
        print()

        # Analyze the data
        total_stock = 0
        items_with_stock = 0
        warehouse_summary = {}

        for item in data:
            sku = item.get('sku', 'Unknown')
            name = item.get('name', 'Unknown')
            warehouse_stock = item.get('warehouse_stock', {})

            item_total = sum(stock for stock in warehouse_stock.values() if isinstance(stock, int) and stock > 0)
            if item_total > 0:
                items_with_stock += 1
                total_stock += item_total

                # Track warehouse usage
                for warehouse, stock in warehouse_stock.items():
                    if isinstance(stock, int) and stock > 0:
                        if warehouse not in warehouse_summary:
                            warehouse_summary[warehouse] = {'items': 0, 'total_stock': 0}
                        warehouse_summary[warehouse]['items'] += 1
                        warehouse_summary[warehouse]['total_stock'] += stock

        print(f"Items with stock: {items_with_stock}")
        print(f"Total stock across all items: {total_stock}")
        print()

        print("Warehouse Summary:")
        for warehouse, stats in sorted(warehouse_summary.items()):
            print(f"  {warehouse}: {stats['items']} items, {stats['total_stock']} units")
        print()

        print("Sample spare parts:")
        for i, item in enumerate(data[:10]):
            sku = item.get('sku', 'Unknown')
            name = item.get('name', 'Unknown')[:50] + ('...' if len(item.get('name', '')) > 50 else '')
            warehouse_stock = item.get('warehouse_stock', {})
            total = sum(stock for stock in warehouse_stock.values() if isinstance(stock, int) and stock > 0)

            if total > 0:
                print(f"  {i+1:2d}. {sku} - {name} ({total} units)")

        print()
        print("SUCCESS: Extraction verification complete!")
        return True

    except Exception as e:
        print(f"ERROR: Error reading JSON file: {e}")
        return False

if __name__ == "__main__":
    print("=== Spare Parts Extraction Verification ===")
    print()
    success = verify_extraction()
    print()
    print("=" * 50)