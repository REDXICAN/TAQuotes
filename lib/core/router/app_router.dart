// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive_helper.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/clients/presentation/screens/clients_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/quotes/presentation/screens/quotes_screen.dart';
import '../../features/quotes/presentation/screens/quote_detail_screen.dart';
import '../../features/quotes/presentation/screens/create_quote_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/admin/presentation/screens/admin_panel_screen.dart';
import '../../features/admin/presentation/screens/performance_dashboard_screen.dart';
import '../../features/admin/presentation/screens/user_info_dashboard_screen.dart';
import '../../features/stock/presentation/screens/stock_dashboard_screen.dart';
import '../../features/spareparts/presentation/screens/spareparts_screen.dart';

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.uri.path.startsWith('/auth');
      final isAdminRoute = state.uri.path.startsWith('/admin');

      // Don't redirect if we're still loading auth state
      if (authState.isLoading) {
        return null;
      }

      // Allow authenticated users to access any route except auth routes
      if (!isAuthenticated && !isAuthRoute) {
        return '/auth/login';
      }

      // Redirect authenticated users away from auth routes
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main app shell
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          // Home
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),

          // Products
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: ':productId',
                builder: (context, state) {
                  final productId = state.pathParameters['productId']!;
                  return ProductDetailScreen(productId: productId);
                },
              ),
            ],
          ),

          // Cart
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),

          // Clients
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsScreen(),
          ),

          // Quotes
          GoRoute(
            path: '/quotes',
            builder: (context, state) => const QuotesScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateQuoteScreen(),
              ),
              GoRoute(
                path: ':quoteId',
                builder: (context, state) {
                  final quoteId = state.pathParameters['quoteId']!;
                  return QuoteDetailScreen(quoteId: quoteId);
                },
              ),
            ],
          ),

          // Profile
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),

          // Stock
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockDashboardScreen(),
          ),

          // Spare Parts
          GoRoute(
            path: '/spareparts',
            builder: (context, state) => const SparePartsScreen(),
          ),

          // Admin
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminPanelScreen(),
            routes: [
              GoRoute(
                path: 'performance',
                builder: (context, state) => const PerformanceDashboardScreen(),
              ),
              GoRoute(
                path: 'users',
                builder: (context, state) => const UserInfoDashboardScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Main Navigation Shell with Bottom Navigation Bar
class MainNavigationShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainNavigationShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  final List<String> _routes = [
    '/',
    '/clients',
    '/products',
    '/cart',
    '/quotes',
    '/stock',
    '/spareparts',
    '/profile',
  ];

  int _calculateSelectedIndex(String location) {
    if (location == '/') return 0;

    for (int i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i]) && _routes[i] != '/') {
        return i;
      }
    }

    if (location.startsWith('/admin')) {
      return _routes.length;
    }

    if (location.startsWith('/spareparts')) {
      return 6; // Index for spare parts
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserProfileAsync = ref.watch(currentUserProfileProvider);
    final isAdmin = currentUserProfileAsync.when(
      data: (profile) => profile?.isAdmin ?? false,
      loading: () => false,
      error: (_, __) => false,
    );

    final currentLocation = GoRouterState.of(context).uri.toString();
    final cartItemCountAsync = ref.watch(cartItemCountProvider);
    final cartItemCount = cartItemCountAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // Always include admin route - let the admin screens handle access control
    final routes = [..._routes, '/admin'];
    final selectedIndex = _calculateSelectedIndex(currentLocation);
    
    // Check if we should show navigation rail for larger screens
    // Use navigation rail for tablets and desktop, bottom nav for phones
    final bool showNavigationRail = ResponsiveHelper.isDesktop(context) || 
        (ResponsiveHelper.isTablet(context) && !ResponsiveHelper.isPortrait(context));

    if (showNavigationRail) {
      // Desktop/Tablet layout with NavigationRail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex.clamp(0, routes.length - 1),
              onDestinationSelected: (index) {
                if (index < routes.length) {
                  context.go(routes[index]);
                }
              },
              labelType: ResponsiveHelper.isTablet(context) 
                  ? NavigationRailLabelType.selected 
                  : NavigationRailLabelType.all,
              extended: ResponsiveHelper.isLargeDesktop(context),
              minWidth: ResponsiveHelper.isTablet(context) ? 56 : 72,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Clients'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Products'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    label: cartItemCount > 0 ? Text('$cartItemCount') : null,
                    isLabelVisible: cartItemCount > 0,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  selectedIcon: Badge(
                    label: cartItemCount > 0 ? Text('$cartItemCount') : null,
                    isLabelVisible: cartItemCount > 0,
                    child: const Icon(Icons.shopping_cart),
                  ),
                  label: const Text('Cart'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text('Quotes'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.warehouse_outlined),
                  selectedIcon: Icon(Icons.warehouse),
                  label: Text('Stock'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.build_outlined),
                  selectedIcon: Icon(Icons.build),
                  label: Text('Spare Parts'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
                // Always show admin icon - let the screen handle access control
                const NavigationRailDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings),
                  label: Text('Admin'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: widget.child,  // Full width - no wrapper
            ),
          ],
        ),
      );
    }

    // Mobile and tablet portrait layout with bottom navigation
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, routes.length - 1),
        onDestinationSelected: (index) {
          if (index < routes.length) {
            context.go(routes[index]);
          }
        },
        height: ResponsiveHelper.useCompactLayout(context) ? 56 : null,
        labelBehavior: ResponsiveHelper.useCompactLayout(context)
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Badge(
              label: cartItemCount > 0 ? Text('$cartItemCount') : null,
              isLabelVisible: cartItemCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              label: cartItemCount > 0 ? Text('$cartItemCount') : null,
              isLabelVisible: cartItemCount > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Quotes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.warehouse_outlined),
            selectedIcon: Icon(Icons.warehouse),
            label: 'Stock',
          ),
          const NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Spare Parts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          // Always show admin icon - let the screen handle access control
          const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
      ),
    );
  }
}
