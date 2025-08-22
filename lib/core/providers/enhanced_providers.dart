import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/models.dart';
import '../services/app_logger.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// Enhanced products provider with retry logic
final enhancedProductsProvider = StreamProvider.family<List<Product>, String?>((ref, category) async* {
  final database = FirebaseDatabase.instance;
  var retryCount = 0;
  const maxRetries = 3;
  
  while (retryCount < maxRetries) {
    try {
      // Add a small delay on retries
      if (retryCount > 0) {
        await Future.delayed(Duration(seconds: retryCount));
      }
      
      // Create the stream
      await for (final event in database.ref('products').onValue) {
        final List<Product> products = [];
        
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            
            for (final entry in data.entries) {
              try {
                final productMap = Map<String, dynamic>.from(entry.value);
                productMap['id'] = entry.key;
                final product = Product.fromMap(productMap);
                
                // Filter by category if specified
                if (category == null || category.isEmpty) {
                  products.add(product);
                } else {
                  final productCategory = product.category.trim().toLowerCase();
                  final filterCategory = category.trim().toLowerCase();
                  
                  if (productCategory == filterCategory || 
                      productCategory.contains(filterCategory) ||
                      filterCategory.contains(productCategory)) {
                    products.add(product);
                  }
                }
              } catch (e) {
                // Log but continue with other products
                AppLogger.debug('Error parsing product ${entry.key}', error: e);
              }
            }
          } catch (e) {
            AppLogger.error('Error processing products data', error: e);
            // If we have some products, yield them despite the error
            if (products.isNotEmpty) {
              products.sort((a, b) => (a.sku ?? '').compareTo(b.sku ?? ''));
              yield products;
            }
            continue;
          }
        }
        
        // Sort and yield products
        products.sort((a, b) => (a.sku ?? '').compareTo(b.sku ?? ''));
        yield products;
        
        // Reset retry count on successful load
        retryCount = 0;
      }
    } catch (e) {
      retryCount++;
      AppLogger.error('Products stream error (attempt $retryCount/$maxRetries)', error: e);
      
      if (retryCount >= maxRetries) {
        // After max retries, yield empty list but keep trying
        yield [];
        await Future.delayed(const Duration(seconds: 5));
        retryCount = 0; // Reset for continuous retry
      }
    }
  }
});

// Enhanced clients provider with retry logic
final enhancedClientsProvider = StreamProvider<List<Client>>((ref) async* {
  // Wait for authentication
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    yield [];
    return;
  }
  
  final database = FirebaseDatabase.instance;
  var retryCount = 0;
  const maxRetries = 3;
  
  while (retryCount < maxRetries) {
    try {
      // Add a small delay on retries
      if (retryCount > 0) {
        await Future.delayed(Duration(seconds: retryCount));
      }
      
      // Create the stream
      await for (final event in database.ref('clients/${user.uid}').onValue) {
        final List<Client> clients = [];
        
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            
            for (final entry in data.entries) {
              try {
                final clientMap = Map<String, dynamic>.from(entry.value);
                clientMap['id'] = entry.key;
                clients.add(Client.fromMap(clientMap));
              } catch (e) {
                AppLogger.error('Error parsing client ${entry.key}', error: e);
              }
            }
          } catch (e) {
            AppLogger.error('Error processing clients data', error: e);
            // If we have some clients, yield them despite the error
            if (clients.isNotEmpty) {
              clients.sort((a, b) => a.company.compareTo(b.company));
              yield clients;
            }
            continue;
          }
        }
        
        // Sort and yield clients
        clients.sort((a, b) => a.company.compareTo(b.company));
        yield clients;
        
        // Reset retry count on successful load
        retryCount = 0;
      }
    } catch (e) {
      retryCount++;
      AppLogger.error('Clients stream error (attempt $retryCount/$maxRetries)', error: e);
      
      if (retryCount >= maxRetries) {
        // After max retries, yield empty list but keep trying
        yield [];
        await Future.delayed(const Duration(seconds: 5));
        retryCount = 0; // Reset for continuous retry
      }
    }
  }
});

// Provider to check if Firebase is ready
final firebaseReadyProvider = FutureProvider<bool>((ref) async {
  try {
    final database = FirebaseDatabase.instance;
    
    // Try to read a simple value to ensure connection
    final snapshot = await database.ref('.info/connected').once();
    final isConnected = snapshot.snapshot.value as bool? ?? false;
    
    if (!isConnected) {
      // Wait a bit and try again
      await Future.delayed(const Duration(seconds: 2));
      final retrySnapshot = await database.ref('.info/connected').once();
      return retrySnapshot.snapshot.value as bool? ?? false;
    }
    
    return isConnected;
  } catch (e) {
    AppLogger.error('Error checking Firebase connection', error: e);
    return false;
  }
});

// Wrapper providers that wait for Firebase to be ready
final smartProductsProvider = StreamProvider.family<List<Product>, String?>((ref, category) async* {
  // Wait for Firebase to be ready
  final firebaseReady = await ref.watch(firebaseReadyProvider.future);
  
  if (!firebaseReady) {
    // Try enhanced provider anyway, it has retry logic
    yield* ref.watch(enhancedProductsProvider(category).stream);
  } else {
    yield* ref.watch(enhancedProductsProvider(category).stream);
  }
});

final smartClientsProvider = StreamProvider<List<Client>>((ref) async* {
  // Wait for Firebase to be ready
  final firebaseReady = await ref.watch(firebaseReadyProvider.future);
  
  if (!firebaseReady) {
    // Try enhanced provider anyway, it has retry logic
    yield* ref.watch(enhancedClientsProvider.stream);
  } else {
    yield* ref.watch(enhancedClientsProvider.stream);
  }
});