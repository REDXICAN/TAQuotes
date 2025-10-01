// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive_helper.dart';
import '../config/env_config.dart';
import '../providers/providers.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
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
import '../../features/admin/presentation/screens/user_details_screen.dart';
import '../../features/admin/presentation/screens/error_monitoring_dashboard_optimized.dart';
import '../../features/admin/presentation/screens/database_management_v2_screen.dart';
import '../../features/admin/presentation/screens/monitoring_dashboard_v2_screen.dart';
import '../../features/stock/presentation/screens/stock_dashboard_screen.dart';
import '../../features/spareparts/presentation/screens/spareparts_screen.dart';
import '../../features/projects/presentation/screens/projects_screen.dart';
import '../../features/settings/presentation/screens/app_settings_screen.dart';
import '../../features/settings/presentation/screens/backup_management_screen.dart';
// Architecture A: New grouped screens
import '../../features/catalog/presentation/screens/catalog_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/account/presentation/screens/account_screen.dart';

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isAuthenticated = user != null;
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

      // Check admin access for admin routes
      if (isAdminRoute && isAuthenticated) {
        final userEmail = user.email;
        final isAdmin = userEmail != null && EnvConfig.isSuperAdminEmail(userEmail);

        if (!isAdmin) {
          // Non-admin trying to access admin route - redirect to home
          return '/';
        }
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
      GoRoute(
        path: '/auth/pending-approval',
        builder: (context, state) {
          final extras = state.extra as Map<String, String>?;
          return PendingApprovalScreen(
            userEmail: extras?['email'] ?? '',
            userName: extras?['name'] ?? '',
          );
        },
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

          // ARCHITECTURE A - NEW GROUPED NAVIGATION

          // Catalog - Groups Products, Spare Parts, and Stock
          GoRoute(
            path: '/catalog',
            builder: (context, state) {
              // Support optional tab parameter (?tab=0|1|2)
              final tabParam = state.uri.queryParameters['tab'];
              final tabIndex = int.tryParse(tabParam ?? '0') ?? 0;
              return CatalogScreen(initialTabIndex: tabIndex);
            },
          ),

          // Customers - Groups Clients and Projects
          GoRoute(
            path: '/customers',
            builder: (context, state) {
              // Support optional tab parameter (?tab=0|1)
              final tabParam = state.uri.queryParameters['tab'];
              final tabIndex = int.tryParse(tabParam ?? '0') ?? 0;
              return CustomersScreen(initialTabIndex: tabIndex);
            },
          ),

          // Cart - Standalone (high frequency)
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),

          // Quotes - Standalone (high frequency)
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

          // Account - Groups Profile, Settings, and Admin
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
          ),

          // LEGACY ROUTES - Kept for backward compatibility, redirect to new structure

          // Products -> Catalog (tab 0)
          GoRoute(
            path: '/products',
            redirect: (context, state) {
              // Don't redirect if accessing product detail
              if (state.matchedLocation.contains('/products/')) {
                return null; // Allow navigation to product detail
              }
              return '/catalog?tab=0'; // Redirect to catalog for products list
            },
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

          // Spare Parts -> Catalog (tab 1)
          GoRoute(
            path: '/spareparts',
            redirect: (context, state) => '/catalog?tab=1',
          ),

          // Stock -> Catalog (tab 2)
          GoRoute(
            path: '/stock',
            redirect: (context, state) => '/catalog?tab=2',
          ),

          // Clients -> Customers (tab 0)
          GoRoute(
            path: '/clients',
            redirect: (context, state) => '/customers?tab=0',
          ),

          // Projects -> Customers (tab 1)
          GoRoute(
            path: '/projects',
            redirect: (context, state) => '/customers?tab=1',
          ),

          // Profile -> Account
          GoRoute(
            path: '/profile',
            redirect: (context, state) => '/account',
          ),

          // Settings -> Account (but load actual settings screen)
          GoRoute(
            path: '/settings',
            builder: (context, state) => const AppSettingsScreen(),
            routes: [
              GoRoute(
                path: 'backup',
                builder: (context, state) => const BackupManagementScreen(),
              ),
            ],
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
                routes: [
                  GoRoute(
                    path: ':userId',
                    builder: (context, state) {
                      final userId = state.pathParameters['userId']!;
                      final extras = state.extra as Map<String, String>?;
                      return UserDetailsScreen(
                        userId: userId,
                        userEmail: extras?['email'] ?? '',
                        userName: extras?['name'] ?? '',
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'monitoring',
                builder: (context, state) => const MonitoringDashboardV2Screen(),
              ),
              GoRoute(
                path: 'errors',
                builder: (context, state) => const OptimizedErrorMonitoringDashboard(),
              ),
              GoRoute(
                path: 'database',
                builder: (context, state) => const DatabaseManagementV2Screen(),
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
  /// Returns navigation routes for Architecture A (6 items)
  /// NN/g Guideline #8: Reduced from 9 items to 6 (within 7±2 cognitive load)
  ///
  /// Structure:
  /// - Home: Dashboard and overview
  /// - Catalog: Products, Spare Parts, Stock (grouped)
  /// - Customers: Clients, Projects (grouped)
  /// - Cart: Current quote builder
  /// - Quotes: Quote management
  /// - Account: Profile, Settings, Admin (grouped)
  ///
  /// Admin users see same 6 items (admin is in Account menu, not primary nav)
  List<String> _getRoutes(bool isAdmin) {
    // Architecture A: 6 items for all users
    // Admin panel is accessed via Account screen, not as separate nav item
    return [
      '/',          // Home
      '/catalog',   // Catalog (Products, Spare Parts, Stock)
      '/customers', // Customers (Clients, Projects)
      '/cart',      // Cart
      '/quotes',    // Quotes
      '/account',   // Account (Profile, Settings, Admin)
    ];
  }

  int _calculateSelectedIndex(String location, List<String> routes) {
    if (location == '/') {
      return routes.indexOf('/');
    }

    for (int i = 0; i < routes.length; i++) {
      if (location.startsWith(routes[i]) && routes[i] != '/') {
        return i;
      }
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin based on email (centralized config)
    final authState = ref.watch(authStateProvider);
    final userEmail = authState.valueOrNull?.email;
    final isAdmin = userEmail != null && EnvConfig.isSuperAdminEmail(userEmail);

    final currentLocation = GoRouterState.of(context).uri.toString();
    final cartItemCountAsync = ref.watch(cartItemCountProvider);
    final cartItemCount = cartItemCountAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // Get routes based on admin status
    final routes = _getRoutes(isAdmin);
    final selectedIndex = _calculateSelectedIndex(currentLocation, routes);
    
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
              destinations: _buildNavigationRailDestinations(routes, cartItemCount),
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
        destinations: _buildNavigationDestinations(routes, cartItemCount),
      ),
    );
  }

  /// Builds NavigationRail destinations for Architecture A
  /// NN/g Guideline #10: Icons support text labels (not replace them)
  /// NN/g Guideline #7: Clear, familiar labels
  List<NavigationRailDestination> _buildNavigationRailDestinations(List<String> routes, int cartItemCount) {
    final destinations = <NavigationRailDestination>[];

    for (final route in routes) {
      switch (route) {
        case '/':
          destinations.add(const NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: Text('Home'),
          ));
          break;

        case '/catalog':
          // Groups: Products, Spare Parts, Stock
          destinations.add(const NavigationRailDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: Text('Catalog'),
          ));
          break;

        case '/customers':
          // Groups: Clients, Projects
          destinations.add(const NavigationRailDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: Text('Customers'),
          ));
          break;

        case '/cart':
          // NN/g Guideline #13: Badge indicates cart item count
          destinations.add(NavigationRailDestination(
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
          ));
          break;

        case '/quotes':
          destinations.add(const NavigationRailDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: Text('Quotes'),
          ));
          break;

        case '/account':
          // Groups: Profile, Settings, Admin (conditional)
          destinations.add(const NavigationRailDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Account'),
          ));
          break;
      }
    }

    return destinations;
  }

  /// Builds NavigationBar destinations for mobile (Architecture A)
  /// NN/g Guideline #11: Minimum 48dp touch targets
  /// NN/g Guideline #2: Show on mobile (no hamburger menu needed with only 6 items)
  List<NavigationDestination> _buildNavigationDestinations(List<String> routes, int cartItemCount) {
    final destinations = <NavigationDestination>[];

    for (final route in routes) {
      switch (route) {
        case '/':
          destinations.add(const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ));
          break;

        case '/catalog':
          // Groups: Products, Spare Parts, Stock
          destinations.add(const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Catalog',
          ));
          break;

        case '/customers':
          // Groups: Clients, Projects
          destinations.add(const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ));
          break;

        case '/cart':
          // NN/g Guideline #13: Badge for cart count
          destinations.add(NavigationDestination(
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
          ));
          break;

        case '/quotes':
          destinations.add(const NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Quotes',
          ));
          break;

        case '/account':
          // Groups: Profile, Settings, Admin (conditional)
          destinations.add(const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ));
          break;
      }
    }

    return destinations;
  }
}
