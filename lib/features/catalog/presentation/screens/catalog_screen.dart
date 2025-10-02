// lib/features/catalog/presentation/screens/catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../spareparts/presentation/screens/spareparts_screen.dart';
import '../../../stock/presentation/screens/stock_dashboard_screen.dart';

/// Catalog Screen with Tabs - Groups Products, Spare Parts, and Stock
///
/// This screen implements Architecture A's "Catalog" navigation item,
/// consolidating three related inventory sections under one top-level nav item.
///
/// NN/g Compliance:
/// - Guideline #8: Groups related items logically (all product/inventory management)
/// - Guideline #6: Provides local navigation (tabs for sub-sections)
/// - Guideline #5: Indicates current location (selected tab)
/// - Guideline #12: Click-activated tabs (not hover)
/// - Guideline #16: Familiar pattern (standard Material tab bar)
class CatalogScreen extends StatefulWidget {
  /// Optional initial tab index (0=Products, 1=Spare Parts, 2=Stock)
  final int initialTabIndex;

  const CatalogScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 3 tabs (Products, Spare Parts, Stock)
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog'),
        // Tab bar for sub-navigation
        // NN/g Guideline #6: Local navigation for related content
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.inventory_2_outlined),
              text: 'Products',
            ),
            Tab(
              icon: Icon(Icons.build_outlined),
              text: 'Spare Parts',
            ),
            Tab(
              icon: Icon(Icons.warehouse_outlined),
              text: 'Stock',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // Disable swipe on web/desktop for better control
        physics: Theme.of(context).platform == TargetPlatform.iOS ||
                Theme.of(context).platform == TargetPlatform.android
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        children: const [
          // Products Tab - Main product catalog (835+ products)
          ProductsScreen(showAppBar: false),

          // Spare Parts Tab - Parts catalog
          SparePartsScreen(),

          // Stock Tab - Warehouse inventory levels
          StockDashboardScreen(showAppBar: false),
        ],
      ),
    );
  }
}
