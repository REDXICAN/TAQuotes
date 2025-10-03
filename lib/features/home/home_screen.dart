import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/offline_service.dart';
import '../../core/services/cache_manager.dart';
import '../../core/services/app_logger.dart';
import '../../core/auth/providers/rbac_provider.dart';
import '../../core/auth/models/rbac_permissions.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/models/models.dart';
import '../../core/widgets/simple_image_widget.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/widgets/app_bar_with_client.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/recent_searches_widget.dart';
import '../admin/presentation/widgets/user_approvals_widget.dart';
import 'widgets/projects_dashboard_widget.dart';

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
    _listenToSyncStatus();
  }

  Future<void> _initializeServices() async {
    try {
      await OfflineService.staticInitialize();
      await CacheManager.initialize();

      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
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



  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = ref.watch(currentUserProvider);
    final userProfile = userAsync.valueOrNull;

    return Scaffold(
      appBar: const AppBarWithClient(
        title: 'Dashboard',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate providers to refresh data
          ref.invalidate(totalProductsProvider);
          ref.invalidate(totalClientsProvider);
          ref.invalidate(totalQuotesProvider);
          ref.invalidate(cartItemCountProvider);
          ref.invalidate(sparePartsProvider);

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
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Only show admin button for users with admin panel access permission
                    Consumer(
                      builder: (context, ref, child) {
                        final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));
                        return hasAdminAccess.when(
                          data: (hasAccess) => hasAccess ? child! : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                      child: IconButton(
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                        onPressed: () => context.go('/admin'),
                        tooltip: 'Admin Panel',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: ResponsiveHelper.getSpacing(context, extraLarge: 24),
              ),

              // User approval notifications for users with approval permissions
              Consumer(
                builder: (context, ref, child) {
                  final canApproveUsers = ref.watch(hasPermissionProvider(Permission.approveUsers));
                  return canApproveUsers.when(
                    data: (canApprove) => canApprove ? const UserApprovalsWidget() : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),

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
                  tablet: 4,
                  desktop: 4,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: ResponsiveHelper.getValue(
                  context,
                  mobile: 1.8,  // Even more compact cards - 30% smaller height
                  tablet: 2.2,
                  desktop: 2.2,
                ),
                children: [
                  // Products Card - Clickable to navigate to catalog
                  Consumer(
                    builder: (context, ref, child) {
                      final productsAsync = ref.watch(totalProductsProvider);
                      return productsAsync.when(
                        data: (count) => _buildStatCard(
                          'Products',
                          count.toString(),
                          Icons.inventory_2,
                          Colors.blue,
                          route: '/catalog?tab=0',
                        ),
                        loading: () => _buildStatCard(
                          'Products',
                          '...',
                          Icons.inventory_2,
                          Colors.blue,
                          route: '/catalog?tab=0',
                        ),
                        error: (_, __) => _buildStatCard(
                          'Products',
                          '0',
                          Icons.inventory_2,
                          Colors.blue,
                          route: '/catalog?tab=0',
                        ),
                      );
                    },
                  ),
                  // Clients Card - Clickable to navigate to customers
                  Consumer(
                    builder: (context, ref, child) {
                      final clientsAsync = ref.watch(totalClientsProvider);
                      return clientsAsync.when(
                        data: (count) => _buildStatCard(
                          'Clients',
                          count.toString(),
                          Icons.people,
                          Colors.green,
                          route: '/customers?tab=0',
                        ),
                        loading: () => _buildStatCard(
                          'Clients',
                          '...',
                          Icons.people,
                          Colors.green,
                          route: '/customers?tab=0',
                        ),
                        error: (_, __) => _buildStatCard(
                          'Clients',
                          '0',
                          Icons.people,
                          Colors.green,
                          route: '/customers?tab=0',
                        ),
                      );
                    },
                  ),
                  // Quotes Card - Clickable to navigate to quotes
                  Consumer(
                    builder: (context, ref, child) {
                      final quotesAsync = ref.watch(totalQuotesProvider);
                      return quotesAsync.when(
                        data: (count) => _buildStatCard(
                          'Quotes',
                          count.toString(),
                          Icons.description,
                          Colors.orange,
                          route: '/quotes',
                        ),
                        loading: () => _buildStatCard(
                          'Quotes',
                          '...',
                          Icons.description,
                          Colors.orange,
                          route: '/quotes',
                        ),
                        error: (_, __) => _buildStatCard(
                          'Quotes',
                          '0',
                          Icons.description,
                          Colors.orange,
                          route: '/quotes',
                        ),
                      );
                    },
                  ),
                  // Cart Items Card - Clickable to navigate to cart
                  Consumer(
                    builder: (context, ref, child) {
                      final cartAsync = ref.watch(cartItemCountProvider);
                      return cartAsync.when(
                        data: (count) => _buildStatCard(
                          'Cart Items',
                          count.toString(),
                          Icons.shopping_cart,
                          Colors.purple,
                          route: '/cart',
                        ),
                        loading: () => _buildStatCard(
                          'Cart Items',
                          '...',
                          Icons.shopping_cart,
                          Colors.purple,
                          route: '/cart',
                        ),
                        error: (_, __) => _buildStatCard(
                          'Cart Items',
                          '0',
                          Icons.shopping_cart,
                          Colors.purple,
                          route: '/cart',
                        ),
                      );
                    },
                  ),
                  // Spare Parts Card - Clickable to navigate to spare parts
                  Consumer(
                    builder: (context, ref, child) {
                      final sparePartsAsync = ref.watch(sparePartsProvider);
                      return sparePartsAsync.when(
                        data: (spareParts) => _buildStatCard(
                          'Spare Parts',
                          spareParts.length.toString(),
                          Icons.build,
                          Colors.teal,
                          route: '/catalog?tab=1',
                        ),
                        loading: () => _buildStatCard(
                          'Spare Parts',
                          '...',
                          Icons.build,
                          Colors.teal,
                          route: '/catalog?tab=1',
                        ),
                        error: (_, __) => _buildStatCard(
                          'Spare Parts',
                          '0',
                          Icons.build,
                          Colors.teal,
                          route: '/catalog?tab=1',
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.getSpacing(context, extraLarge: 24),
              ),

              // Projects Dashboard Section
              const ProjectsDashboardWidget(),

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

  // ignore: unused_element
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
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                    sku: (product.sku != null && product.sku!.isNotEmpty) ? product.sku! : product.model,
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
                        (product.sku != null && product.sku!.isNotEmpty) ? product.sku! : product.model,
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

  /// Builds non-clickable stat card for dashboard
  /// Architecture A: Stats-only approach (no navigation)
  /// NN/g Guideline #16: Familiar pattern - cards show data, nav bar handles navigation
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? route,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveHelper.isMobile(context);
        final iconSize = isMobile ? 20.0 : 24.0; // 30% smaller icons
        final valueSize = isMobile ? 16.0 : 18.0; // 30% smaller values
        final titleSize = isMobile ? 9.0 : 10.0; // 30% smaller titles
        final padding = isMobile ? 6.0 : 8.0; // 30% less padding for compact cards

        final cardContent = Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: color),
              SizedBox(height: isMobile ? 6 : 8),
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
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  color: color.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

        // If route is provided, make it clickable
        if (route != null) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go(route),
              borderRadius: BorderRadius.circular(12),
              child: cardContent,
            ),
          );
        }

        return cardContent;
      },
    );
  }
}