import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:turbots/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final database = FirebaseDatabase.instance;
  final productsRef = database.ref('products');

  // Sample products data
  final products = [
    {
      'sku': 'TST-09',
      'model': 'TST-09',
      'name': 'Sandwich/Salad Unit',
      'description': 'Super Deluxe Sandwich/Salad Unit with stainless steel interior & exterior',
      'price': 2999.99,
      'category': 'Prep Tables',
      'subcategory': 'Sandwich/Salad',
      'dimensions': '27"W x 30"D x 43"H',
      'weight': '150 lbs',
      'capacity': '9 cu. ft.',
    },
    {
      'sku': 'TST-28',
      'model': 'TST-28',
      'name': 'Sandwich/Salad Unit',
      'description': 'Super Deluxe Sandwich/Salad Unit, one-section',
      'price': 3499.99,
      'category': 'Prep Tables',
      'subcategory': 'Sandwich/Salad',
      'dimensions': '28"W x 30"D x 43"H',
      'weight': '180 lbs',
      'capacity': '7 cu. ft.',
    },
    {
      'sku': 'TST-48',
      'model': 'TST-48',
      'name': 'Sandwich/Salad Unit',
      'description': 'Super Deluxe Sandwich/Salad Unit, two-section',
      'price': 4299.99,
      'category': 'Prep Tables',
      'subcategory': 'Sandwich/Salad',
      'dimensions': '48"W x 30"D x 43"H',
      'weight': '250 lbs',
      'capacity': '12 cu. ft.',
    },
    {
      'sku': 'TST-60',
      'model': 'TST-60',
      'name': 'Sandwich/Salad Unit',
      'description': 'Super Deluxe Sandwich/Salad Unit, two-section with 12 pans',
      'price': 4999.99,
      'category': 'Prep Tables',
      'subcategory': 'Sandwich/Salad',
      'dimensions': '60"W x 30"D x 43"H',
      'weight': '300 lbs',
      'capacity': '16 cu. ft.',
    },
    {
      'sku': 'TST-72',
      'model': 'TST-72',
      'name': 'Sandwich/Salad Unit',
      'description': 'Super Deluxe Sandwich/Salad Unit, three-section',
      'price': 5999.99,
      'category': 'Prep Tables',
      'subcategory': 'Sandwich/Salad',
      'dimensions': '72"W x 30"D x 43"H',
      'weight': '350 lbs',
      'capacity': '19 cu. ft.',
    },
    {
      'sku': 'TSR-23',
      'model': 'TSR-23',
      'name': 'Reach-In Refrigerator',
      'description': 'Super Deluxe Series Reach-In Refrigerator, one-section',
      'price': 3299.99,
      'category': 'Refrigeration',
      'subcategory': 'Reach-In',
      'dimensions': '27"W x 30"D x 78"H',
      'weight': '400 lbs',
      'capacity': '23 cu. ft.',
    },
    {
      'sku': 'TSR-35',
      'model': 'TSR-35',
      'name': 'Reach-In Refrigerator',
      'description': 'Super Deluxe Series Reach-In Refrigerator, one-section, glass door',
      'price': 3799.99,
      'category': 'Refrigeration',
      'subcategory': 'Reach-In',
      'dimensions': '40"W x 30"D x 78"H',
      'weight': '450 lbs',
      'capacity': '35 cu. ft.',
    },
    {
      'sku': 'TSR-49',
      'model': 'TSR-49',
      'name': 'Reach-In Refrigerator',
      'description': 'Super Deluxe Series Reach-In Refrigerator, two-section',
      'price': 4799.99,
      'category': 'Refrigeration',
      'subcategory': 'Reach-In',
      'dimensions': '54"W x 30"D x 78"H',
      'weight': '550 lbs',
      'capacity': '49 cu. ft.',
    },
    {
      'sku': 'TSR-72',
      'model': 'TSR-72',
      'name': 'Reach-In Refrigerator',
      'description': 'Super Deluxe Series Reach-In Refrigerator, three-section',
      'price': 6299.99,
      'category': 'Refrigeration',
      'subcategory': 'Reach-In',
      'dimensions': '81"W x 30"D x 78"H',
      'weight': '700 lbs',
      'capacity': '72 cu. ft.',
    },
    {
      'sku': 'TSF-23',
      'model': 'TSF-23',
      'name': 'Reach-In Freezer',
      'description': 'Super Deluxe Series Reach-In Freezer, one-section',
      'price': 3599.99,
      'category': 'Refrigeration',
      'subcategory': 'Freezers',
      'dimensions': '27"W x 30"D x 78"H',
      'weight': '420 lbs',
      'capacity': '23 cu. ft.',
    },
  ];

  print('Starting to populate products...');
  
  int count = 0;
  for (final product in products) {
    try {
      await productsRef.push().set(product);
      count++;
      print('Added product: ${product['sku']} - ${product['name']}');
    } catch (e) {
      print('Error adding product ${product['sku']}: $e');
    }
  }
  
  print('\nSuccessfully added $count products to the database.');
  print('Products are now available at: https://turbo-air-viewer-default-rtdb.firebaseio.com/products.json');
}