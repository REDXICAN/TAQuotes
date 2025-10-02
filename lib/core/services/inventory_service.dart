import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'realtime_database_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// Service to manage inventory data from Firebase
class InventoryService {
  // Database service kept for potential future warehouse operations
  // ignore: unused_field
  final RealtimeDatabaseService _dbService;

  InventoryService(this._dbService);
  
  // Get warehouse stock for a product from Firebase
  Map<String, WarehouseStock>? getProductStock(Product product) {
    // Check if product has warehouse stock data from Firebase
    if (product.warehouseStock != null && product.warehouseStock!.isNotEmpty) {
      return product.warehouseStock;
    }
    
    // Return null if no stock data available
    return null;
  }
  
  // Get total stock for a product
  int getTotalStock(Product product) {
    if (product.warehouseStock == null) return 0;
    
    int total = 0;
    product.warehouseStock!.forEach((warehouse, stock) {
      total += stock.available;
    });
    return total;
  }
  
  // Get available stock (excluding reserved warehouse 999)
  int getAvailableStock(Product product) {
    if (product.warehouseStock == null) return 0;
    
    int available = 0;
    product.warehouseStock!.forEach((warehouse, stock) {
      // Exclude warehouse 999 as it's reserved/quoted merchandise
      if (warehouse != '999') {
        available += stock.actualAvailable;
      }
    });
    return available;
  }
  
  // Check if product is low stock
  bool isLowStock(Product product) {
    final available = getAvailableStock(product);
    return available > 0 && available <= 10;
  }
  
  // Check if product is out of stock
  bool isOutOfStock(Product product) {
    return getAvailableStock(product) == 0;
  }
  
  // Get stock status message
  String getStockStatus(Product product) {
    final available = getAvailableStock(product);
    final reserved = product.warehouseStock?['999']?.available ?? 0;
    
    if (available == 0 && reserved == 0) {
      return 'Out of Stock';
    } else if (available == 0 && reserved > 0) {
      return 'Reserved Only';
    } else if (available <= 10) {
      return 'Low Stock ($available available)';
    } else {
      return 'In Stock ($available available)';
    }
  }
}

// Provider for inventory service
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return InventoryService(dbService);
});

// Provider to get stock status for a product
final productStockStatusProvider = Provider.family<String, Product>((ref, product) {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return inventoryService.getStockStatus(product);
});

// Provider to check if product is low stock
final isLowStockProvider = Provider.family<bool, Product>((ref, product) {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return inventoryService.isLowStock(product);
});

// Provider to check if product is out of stock  
final isOutOfStockProvider = Provider.family<bool, Product>((ref, product) {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return inventoryService.isOutOfStock(product);
});