import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final database = FirebaseDatabase.instance;
  
  try {
    print('Checking product URLs in Firebase...\n');
    
    // Get all products
    final snapshot = await database.ref('products').get();
    
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      
      int totalProducts = 0;
      int withThumbnailUrl = 0;
      int withImageUrl = 0;
      int withImageUrl2 = 0;
      int withoutAnyUrl = 0;
      
      List<String> productsWithoutUrls = [];
      
      data.forEach((key, value) {
        totalProducts++;
        final product = Map<String, dynamic>.from(value);
        
        bool hasThumbnail = product['thumbnailUrl'] != null && product['thumbnailUrl'].toString().isNotEmpty;
        bool hasImage1 = product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty;
        bool hasImage2 = product['imageUrl2'] != null && product['imageUrl2'].toString().isNotEmpty;
        
        if (hasThumbnail) withThumbnailUrl++;
        if (hasImage1) withImageUrl++;
        if (hasImage2) withImageUrl2++;
        
        if (!hasThumbnail && !hasImage1) {
          withoutAnyUrl++;
          String sku = product['sku'] ?? product['model'] ?? key;
          productsWithoutUrls.add(sku);
        }
      });
      
      print('=== Product URL Statistics ===');
      print('Total products: $totalProducts');
      print('With thumbnailUrl: $withThumbnailUrl');
      print('With imageUrl (P.1): $withImageUrl');
      print('With imageUrl2 (P.2): $withImageUrl2');
      print('Without any URL: $withoutAnyUrl');
      
      if (productsWithoutUrls.isNotEmpty) {
        print('\n=== Products without URLs (first 10) ===');
        productsWithoutUrls.take(10).forEach((sku) {
          print('  - $sku');
        });
      }
      
      // Check a sample product
      print('\n=== Sample Product Check ===');
      final sampleKey = data.keys.first;
      final sampleProduct = Map<String, dynamic>.from(data[sampleKey]);
      print('SKU: ${sampleProduct['sku'] ?? sampleProduct['model']}');
      print('thumbnailUrl: ${sampleProduct['thumbnailUrl'] ?? 'NOT SET'}');
      print('imageUrl: ${sampleProduct['imageUrl'] ?? 'NOT SET'}');
      print('imageUrl2: ${sampleProduct['imageUrl2'] ?? 'NOT SET'}');
      
    } else {
      print('No products found in database!');
    }
  } catch (e) {
    print('Error: $e');
  }
  
  print('\nDone!');
}