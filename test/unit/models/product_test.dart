import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_air_quotes/core/models/models.dart';

void main() {
  group('Product Model Tests', () {
    test('should create Product from valid map', () {
      final productMap = {
        'id': 'test-id',
        'sku': 'TSR-23SD',
        'model': 'TSR-23SD',
        'name': 'Super Deluxe Reach-In Refrigerator',
        'description': 'Commercial refrigerator with advanced features',
        'price': 2999.99,
        'category': 'Refrigeration',
        'productType': 'Reach-In',
        'isTopSeller': true,
      };

      final product = Product.fromMap(productMap);

      expect(product.id, 'test-id');
      expect(product.sku, 'TSR-23SD');
      expect(product.model, 'TSR-23SD');
      expect(product.name, 'Super Deluxe Reach-In Refrigerator');
      expect(product.price, 2999.99);
      expect(product.category, 'Refrigeration');
      expect(product.isTopSeller, true);
    });

    test('should handle missing optional fields', () {
      final productMap = {
        'id': 'test-id',
        'name': 'Test Product',
        'description': 'Test Description',
        'price': 1000.0,
        'category': 'Test Category',
      };

      final product = Product.fromMap(productMap);

      expect(product.id, 'test-id');
      expect(product.name, 'Test Product');
      expect(product.sku, null);
      expect(product.model, null);
      expect(product.productType, null);
      expect(product.isTopSeller, false);
    });

    test('should convert Product to map correctly', () {
      final product = Product(
        id: 'test-id',
        sku: 'TEST-SKU',
        model: 'TEST-MODEL',
        displayName: 'TEST-SKU - Test Product',
        name: 'Test Product',
        description: 'Test Description',
        price: 1500.50,
        category: 'Test Category',
        productType: 'Test Type',
        isTopSeller: false,
        stock: 10,
        createdAt: DateTime.now(),
      );

      final map = product.toMap();

      expect(map['sku'], 'TEST-SKU');
      expect(map['model'], 'TEST-MODEL');
      expect(map['name'], 'Test Product');
      expect(map['price'], 1500.50);
      expect(map['category'], 'Test Category');
      expect(map['isTopSeller'], false);
    });

    test('displayName should return correct format', () {
      final product1 = Product(
        id: '1',
        sku: 'SKU-123',
        model: 'MODEL-456',
        displayName: 'SKU-123 - Product Name',
        name: 'Product Name',
        description: 'Description',
        price: 100.0,
        category: 'Category',
        stock: 5,
        createdAt: DateTime.now(),
      );

      final product2 = Product(
        id: '2',
        sku: null,
        model: 'MODEL-789',
        displayName: 'MODEL-789 - Product Name 2',
        name: 'Product Name 2',
        description: 'Description',
        price: 200.0,
        category: 'Category',
        stock: 3,
        createdAt: DateTime.now(),
      );

      final product3 = Product(
        id: '3',
        sku: null,
        model: 'MODEL-XYZ',
        displayName: 'Product Name 3',
        name: 'Product Name 3',
        description: 'Description',
        price: 300.0,
        category: 'Category',
        stock: 8,
        createdAt: DateTime.now(),
      );

      expect(product1.displayName, 'SKU-123 - Product Name');
      expect(product2.displayName, 'MODEL-789 - Product Name 2');
      expect(product3.displayName, 'Product Name 3');
    });
  });
}