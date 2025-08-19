import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/offline_service.dart';
import '../../core/services/cache_manager.dart';
import '../../core/services/app_logger.dart';
import '../../core/utils/responsive_helper.dart';
import '../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isOnline = true;
  int _syncQueueCount = 0;
  late final OfflineService _offlineService;

  // Statistics
  int _totalClients = 0;
  int _totalQuotes = 0;
  int _cartItems = 0;
  int _totalProducts = 0;

  @override
  void initState() {
    super.initState();
    _offlineService = OfflineService();
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
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
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
      final count = await _offlineService.getSyncQueueCount();
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
      
      final clients = CacheManager.getClients();
      final quotes = CacheManager.getQuotes();
      final products = CacheManager.getProducts();
      
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
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final user = ref.watch(currentUserProvider);
    final userProfile = userAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
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
                    if (userProfile?.role == 'admin')
                      IconButton(
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                        onPressed: () => context.go('/admin'),
                        tooltip: 'Admin Panel',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                  mobile: 1.5,
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
                ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}