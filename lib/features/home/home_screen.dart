import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/offline_service.dart';
import '../../core/services/cache_manager.dart';
import '../../core/services/app_logger.dart';
import '../../core/config/env_config.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/models/models.dart';
import '../../core/widgets/simple_image_widget.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/widgets/app_bar_with_client.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../products/presentation/screens/products_screen.dart';
import '../../core/widgets/recent_searches_widget.dart';
import '../admin/presentation/widgets/user_approvals_widget.dart';

// Search history provider - stores last 10 searched products
final searchHistoryProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }
  
  final database = FirebaseDatabase.instance;
  
  return database.ref('search_history/${user.uid}')
    .orderByChild('timestamp')
    .limitToLast(10)
    .onValue
    .asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <Product>[];
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<Product> products = [];
      
      // Sort by timestamp descending (most recent first)
      final sortedEntries = data.entries.toList()
        ..sort((a, b) {
          final timestampA = (a.value['timestamp'] ?? 0) as int;
          final timestampB = (b.value['timestamp'] ?? 0) as int;
          return timestampB.compareTo(timestampA);
        });
      
      // Get product details for each search history item
      for (final entry in sortedEntries.take(5)) { // Show only 5 most recent
        final productId = entry.value['product_id'];
        if (productId != null) {
          final productSnapshot = await database.ref('products/$productId').get();
          if (productSnapshot.exists && productSnapshot.value != null) {
            final productData = Map<String, dynamic>.from(productSnapshot.value as Map);
            productData['id'] = productId;
            try {
              products.add(Product.fromMap(productData));
            } catch (e) {
              AppLogger.error('Error parsing search history product', error: e);
            }
          }
        }
      }
      
      return products;
    });
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isOnline = true;
  int _syncQueueCount = 0;
  // Note: OfflineService is not supported on web platform

  // Statistics
  int _totalClients = 0;
  int _totalQuotes = 0;
  int _cartItems = 0;
  int _totalProducts = 0;
  int _totalSpareParts = 0;

  @override
  void initState() {
    super.initState();
    // Initialize offline service only on non-web platforms
    // Web platform doesn't support offline functionality
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize services first
    await _initializeServices();
    
    // Then load data
    _checkConnectivity();
    _loadStatistics();
    _listenToSyncStatus();
    _loadRealtimeData();
  }

  Future<void> _initializeServices() async {
    try {
      await OfflineService.staticInitialize();
      await CacheManager.initialize();

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        OfflineService.syncPendingChanges();
      }
    } catch (e) {
      AppLogger.error('Error initializing services', error: e, category: LogCategory.database);
    }
  }

  void _checkConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });

        if (_isOnline) {
          OfflineService.syncPendingChanges();
        }
      }
    });
  }

  void _listenToSyncStatus() {
    OfflineService.staticQueueStream.listen((operations) async {
      final count = await OfflineService.staticGetSyncQueueCount();
      if (mounted) {
        setState(() {
          _syncQueueCount = count;
        });
      }
    });
  }

  Future<void> _loadStatistics() async {
    try {
      // Ensure cache manager is initialized before accessing
      if (!CacheManager.isInitialized) {
        await CacheManager.initialize();
      }
      
      // Firebase handles caching, return empty lists
      final clients = [];
      final quotes = [];
      final products = [];
      
      // Use OfflineService static method instead of instance
      final cart = OfflineService.getStaticCart();

      if (mounted) {
        setState(() {
          _totalClients = clients.length;
          _totalQuotes = quotes.length;
          _totalProducts = products.length;
          _cartItems = cart.length;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading statistics', error: e, category: LogCategory.database);
      // Set default values on error
      if (mounted) {
        setState(() {
          _totalClients = 0;
          _totalQuotes = 0;
          _totalProducts = 0;
          _cartItems = 0;
        });
      }
    }
  }

  void _loadRealtimeData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final database = FirebaseDatabase.instance;

    // Listen to products
    database.ref('products').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map;
        setState(() {
          _totalProducts = data.length;
        });
      }
    });

    // Listen to clients
    database.ref('clients/${ user.uid}').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map;
        setState(() {
          _totalClients = data.length;
        });
      }
    });

    // Listen to quotes
    database.ref('quotes/${user.uid}').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map;
        setState(() {
          _totalQuotes = data.length;
        });
      }
    });

    // Listen to cart
    database.ref('cart_items/${user.uid}').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map;
        setState(() {
          _cartItems = data.length;
        });
      }
    });

    // Listen to spare parts
    database.ref('spareparts').onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map;
        setState(() {
          _totalSpareParts = data.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = ref.watch(currentUserProvider);
    final userProfile = userAsync.valueOrNull;
    final userEmail = user?.email ?? '';

    return Scaffold(
      appBar: const AppBarWithClient(
        title: 'Dashboard',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStatistics();
          if (_isOnline) {
            await OfflineService.syncPendingChanges();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4169E1), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        (userProfile?.displayName ?? user?.displayName ?? 'User').isNotEmpty
                            ? (userProfile?.displayName ?? user?.displayName ?? 'User').substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4169E1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${userProfile?.displayName ?? user?.displayName ?? 'User'}!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userProfile?.email ?? user?.email ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Only show admin button for superadmin emails
                    if (userEmail != null && EnvConfig.isSuperAdminEmail(userEmail))
                      IconButton(
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                        onPressed: () => context.go('/admin'),
                        tooltip: 'Admin Panel',
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: ResponsiveHelper.getSpacing(context, extraLarge: 24),
              ),

              // User approval notifications for admins and superadmins
              if (userEmail != null && EnvConfig.isSuperAdminEmail(userEmail))
                const UserApprovalsWidget(),

              // Connection status
              if (!_isOnline || _syncQueueCount > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.orange : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isOnline ? Icons.sync : Icons.cloud_off,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isOnline
                              ? '$_syncQueueCount pending changes to sync'
                              : 'Offline mode - Changes will sync when online',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (_isOnline && _syncQueueCount > 0)
                        TextButton(
                          onPressed: () {
                            OfflineService.syncPendingChanges();
                          },
                          child: const Text(
                            'Sync Now',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!_isOnline || _syncQueueCount > 0) const SizedBox(height: 16),

              // Statistics Grid
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: ResponsiveHelper.getValue(
                  context,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: ResponsiveHelper.getValue(
                  context,
                  mobile: 1.0,  // More square for mobile to fit text
                  tablet: 1.3,
                  desktop: 1.2,
                ),
                children: [
                  _buildStatCard(
                    'Products',
                    _totalProducts.toString(),
                    Icons.inventory_2,
                    Colors.blue,
                    () => context.go('/products'),
                  ),
                  _buildStatCard(
                    'Clients',
                    _totalClients.toString(),
                    Icons.people,
                    Colors.green,
                    () => context.go('/clients'),
                  ),
                  _buildStatCard(
                    'Quotes',
                    _totalQuotes.toString(),
                    Icons.description,
                    Colors.orange,
                    () => context.go('/quotes'),
                  ),
                  _buildStatCard(
                    'Cart Items',
                    _cartItems.toString(),
                    Icons.shopping_cart,
                    Colors.purple,
                    () => context.go('/cart'),
                  ),
                  _buildStatCard(
                    'Spare Parts',
                    _totalSpareParts.toString(),
                    Icons.build,
                    Colors.teal,
                    () => context.go('/spareparts'),
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.getSpacing(context, extraLarge: 24),
              ),
              
              // Recently Searched Products Section
              const RecentSearchesWidget(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRecentProductCard(BuildContext context, Product product, double width) {
    final theme = Theme.of(context);
    
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          // Navigate to products screen with pre-filled search
          ref.read(searchQueryProvider.notifier).state = product.sku ?? '';
          context.go('/products');
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: SimpleImageWidget(
                    sku: product.sku ?? product.model ?? '',
                    useThumbnail: true,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    imageUrl: product.thumbnailUrl ?? product.imageUrl,
                  ),
                ),
              ),
              // Product Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.sku ?? product.model ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        '\$${PriceFormatter.formatPrice(product.price)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveHelper.isMobile(context);
        final iconSize = isMobile ? 32.0 : 40.0;
        final valueSize = isMobile ? 24.0 : 28.0;
        final titleSize = isMobile ? 12.0 : 14.0;
        final padding = isMobile ? 12.0 : 16.0;
        
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize, color: color),
                SizedBox(height: isMobile ? 8 : 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: valueSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    color: color.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}