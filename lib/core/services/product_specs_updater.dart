import 'package:firebase_database/firebase_database.dart';
import '../models/models.dart';

class ProductSpecsUpdater {
  static final _database = FirebaseDatabase.instance;
  
  // Sample data - you can customize these based on your products
  static final Map<String, Map<String, dynamic>> _defaultSpecs = {
    'default': {
      'voltage': '115V',
      'amperage': '5.0A',
      'phase': '1',
      'frequency': '60Hz',
      'plugType': 'NEMA 5-15P',
      'refrigerant': 'R-290',
      'compressor': '1/3 HP',
      'doors': 2,
      'shelves': 4,
      'features': 'Stainless steel construction, Digital temperature control, Auto-defrost',
      'certifications': 'NSF, UL, Energy Star',
    },
    'refrigerator': {
      'voltage': '115V',
      'amperage': '5.0A',
      'phase': '1',
      'frequency': '60Hz',
      'plugType': 'NEMA 5-15P',
      'temperatureRange': '33°F to 40°F',
      'temperatureRangeMetric': '0.5°C to 4.4°C',
      'refrigerant': 'R-290',
      'compressor': '1/3 HP',
      'doors': 2,
      'shelves': 4,
      'features': 'Stainless steel construction, Digital temperature control, Auto-defrost, LED interior lighting',
      'certifications': 'NSF, UL, Energy Star Certified',
    },
    'freezer': {
      'voltage': '115V',
      'amperage': '7.0A',
      'phase': '1',
      'frequency': '60Hz',
      'plugType': 'NEMA 5-15P',
      'temperatureRange': '-10°F to 0°F',
      'temperatureRangeMetric': '-23°C to -18°C',
      'refrigerant': 'R-290',
      'compressor': '1/2 HP',
      'doors': 2,
      'shelves': 4,
      'features': 'Stainless steel construction, Digital temperature control, Manual defrost, Heavy-duty casters',
      'certifications': 'NSF, UL, DOE Compliant',
    },
  };
  
  /// Update all products with missing specifications
  static Future<Map<String, dynamic>> updateAllProductSpecs({
    bool dryRun = true, // Set to false to actually update the database
  }) async {
    int totalProducts = 0;
    int updatedProducts = 0;
    List<String> errors = [];
    List<Map<String, dynamic>> updates = [];
    
    try {
      // Get all products
      final snapshot = await _database.ref('products').get();
      
      if (!snapshot.exists) {
        return {
          'success': false,
          'message': 'No products found in database',
        };
      }
      
      final productsData = Map<String, dynamic>.from(snapshot.value as Map);
      totalProducts = productsData.length;
      
      for (var entry in productsData.entries) {
        final productId = entry.key;
        final productData = Map<String, dynamic>.from(entry.value);
        
        // Check which fields are missing
        final missingFields = <String, dynamic>{};
        
        // Determine product type for defaults
        final category = (productData['category'] ?? '').toString().toLowerCase();
        Map<String, dynamic> defaults = _defaultSpecs['default']!;
        
        if (category.contains('freezer')) {
          defaults = _defaultSpecs['freezer']!;
        } else if (category.contains('refrigerator') || category.contains('cooler')) {
          defaults = _defaultSpecs['refrigerator']!;
        }
        
        // Check each field
        if (productData['voltage'] == null || productData['voltage'].toString().isEmpty) {
          missingFields['voltage'] = defaults['voltage'];
        }
        if (productData['amperage'] == null || productData['amperage'].toString().isEmpty) {
          missingFields['amperage'] = defaults['amperage'];
        }
        if (productData['phase'] == null || productData['phase'].toString().isEmpty) {
          missingFields['phase'] = defaults['phase'];
        }
        if (productData['frequency'] == null || productData['frequency'].toString().isEmpty) {
          missingFields['frequency'] = defaults['frequency'];
        }
        if (productData['plugType'] == null || productData['plugType'].toString().isEmpty) {
          missingFields['plugType'] = defaults['plugType'];
        }
        if (productData['temperatureRange'] == null || productData['temperatureRange'].toString().isEmpty) {
          if (defaults['temperatureRange'] != null) {
            missingFields['temperatureRange'] = defaults['temperatureRange'];
          }
        }
        if (productData['temperatureRangeMetric'] == null || productData['temperatureRangeMetric'].toString().isEmpty) {
          if (defaults['temperatureRangeMetric'] != null) {
            missingFields['temperatureRangeMetric'] = defaults['temperatureRangeMetric'];
          }
        }
        if (productData['refrigerant'] == null || productData['refrigerant'].toString().isEmpty) {
          missingFields['refrigerant'] = defaults['refrigerant'];
        }
        if (productData['compressor'] == null || productData['compressor'].toString().isEmpty) {
          missingFields['compressor'] = defaults['compressor'];
        }
        if (productData['doors'] == null) {
          missingFields['doors'] = defaults['doors'];
        }
        if (productData['shelves'] == null) {
          missingFields['shelves'] = defaults['shelves'];
        }
        if (productData['features'] == null || productData['features'].toString().isEmpty) {
          missingFields['features'] = defaults['features'];
        }
        if (productData['certifications'] == null || productData['certifications'].toString().isEmpty) {
          missingFields['certifications'] = defaults['certifications'];
        }
        
        // Add dimension conversions if missing metric versions
        if (productData['dimensions'] != null && (productData['dimensionsMetric'] == null || productData['dimensionsMetric'].toString().isEmpty)) {
          // You could add conversion logic here
          missingFields['dimensionsMetric'] = _convertToMetric(productData['dimensions'].toString());
        }
        
        if (productData['weight'] != null && (productData['weightMetric'] == null || productData['weightMetric'].toString().isEmpty)) {
          // You could add conversion logic here
          missingFields['weightMetric'] = _convertWeightToMetric(productData['weight'].toString());
        }
        
        if (missingFields.isNotEmpty) {
          updates.add({
            'productId': productId,
            'sku': productData['sku'] ?? productData['model'] ?? productId,
            'name': productData['name'] ?? '',
            'missingFields': missingFields,
          });
          
          if (!dryRun) {
            // Actually update the database
            try {
              await _database.ref('products/$productId').update(missingFields);
              updatedProducts++;
            } catch (e) {
              errors.add('Failed to update $productId: $e');
            }
          } else {
            updatedProducts++;
          }
        }
      }
      
      return {
        'success': true,
        'dryRun': dryRun,
        'totalProducts': totalProducts,
        'productsNeedingUpdate': updatedProducts,
        'updates': updates,
        'errors': errors,
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Convert dimensions to metric (simple example - enhance as needed)
  static String _convertToMetric(String dimensions) {
    // This is a simplified conversion - you may want to enhance this
    if (dimensions.contains('"')) {
      // Assuming format like: 72" x 32" x 83"
      final parts = dimensions.split('x');
      final metricParts = parts.map((part) {
        final inches = double.tryParse(part.replaceAll('"', '').trim()) ?? 0;
        final cm = (inches * 2.54).toStringAsFixed(1);
        return '${cm}cm';
      }).toList();
      return metricParts.join(' x ');
    }
    return dimensions; // Return as-is if can't convert
  }
  
  /// Convert weight to metric (simple example - enhance as needed)
  static String _convertWeightToMetric(String weight) {
    // This is a simplified conversion - you may want to enhance this
    if (weight.toLowerCase().contains('lbs') || weight.toLowerCase().contains('lb')) {
      final pounds = double.tryParse(
        weight.toLowerCase()
          .replaceAll('lbs', '')
          .replaceAll('lb', '')
          .trim()
      ) ?? 0;
      final kg = (pounds * 0.453592).toStringAsFixed(1);
      return '${kg} kg';
    }
    return weight; // Return as-is if can't convert
  }
  
  /// Get a diagnostic report of what fields are missing across all products
  static Future<Map<String, dynamic>> getDiagnosticReport() async {
    try {
      final snapshot = await _database.ref('products').get();
      
      if (!snapshot.exists) {
        return {
          'success': false,
          'message': 'No products found in database',
        };
      }
      
      final productsData = Map<String, dynamic>.from(snapshot.value as Map);
      
      // Track how many products have each field
      final fieldCounts = <String, int>{};
      final fields = [
        'voltage', 'amperage', 'phase', 'frequency', 'plugType',
        'dimensions', 'dimensionsMetric', 'weight', 'weightMetric',
        'temperatureRange', 'temperatureRangeMetric', 'refrigerant',
        'compressor', 'capacity', 'doors', 'shelves', 'features',
        'certifications'
      ];
      
      for (var field in fields) {
        fieldCounts[field] = 0;
      }
      
      int totalProducts = productsData.length;
      
      for (var entry in productsData.entries) {
        final productData = Map<String, dynamic>.from(entry.value);
        
        for (var field in fields) {
          if (productData[field] != null && productData[field].toString().isNotEmpty) {
            fieldCounts[field] = (fieldCounts[field] ?? 0) + 1;
          }
        }
      }
      
      // Calculate percentages
      final fieldPercentages = <String, String>{};
      for (var entry in fieldCounts.entries) {
        final percentage = ((entry.value / totalProducts) * 100).toStringAsFixed(1);
        fieldPercentages[entry.key] = '$percentage% (${entry.value}/$totalProducts)';
      }
      
      return {
        'success': true,
        'totalProducts': totalProducts,
        'fieldCoverage': fieldPercentages,
        'summary': 'Shows percentage and count of products that have each field',
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}