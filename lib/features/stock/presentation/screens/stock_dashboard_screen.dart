// lib/features/stock/presentation/screens/stock_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../../core/theme/apple_colors.dart';


// Provider for stock statistics using StreamProvider for real-time updates
final stockStatsProvider = StreamProvider<StockStatistics>((ref) {
  // Directly watch the stream from products provider for better initialization
  final productsStream = ref.watch(productsProvider(null).stream);
  
  // Transform the products stream into stock statistics
  return productsStream.map((products) {
      // Use only real warehouse stock data from Firebase
      return StockStatistics.fromProducts(products);
  }).handleError((error) {
    // Return empty statistics on error
    return StockStatistics(
      totalProducts: 0,
      warehouseStats: {},
      totalAvailable: 0,
      totalReserved: 0,
      lowStockProducts: [],
      categoryStock: {},
      categoryByWarehouse: {},
      criticalStockByWarehouse: {},
      totalStockValue: 0.0,
    );
  });
});

// Stock statistics model
class StockStatistics {
  final int totalProducts;
  final Map<String, WarehouseStats> warehouseStats;
  final int totalAvailable;
  final int totalReserved;
  final List<Product> lowStockProducts;
  final Map<String, int> categoryStock;
  final Map<String, Map<String, int>> categoryByWarehouse; // Category stock per warehouse
  final Map<String, List<Product>> criticalStockByWarehouse; // Critical items per warehouse
  final double totalStockValue; // Total value of all stock

  StockStatistics({
    required this.totalProducts,
    required this.warehouseStats,
    required this.totalAvailable,
    required this.totalReserved,
    required this.lowStockProducts,
    required this.categoryStock,
    required this.categoryByWarehouse,
    required this.criticalStockByWarehouse,
    required this.totalStockValue,
  });
  
  factory StockStatistics.fromProducts(List<Product> products) {
    final warehouseStats = <String, WarehouseStats>{};
    int totalAvailable = 0;
    int totalReserved = 0;
    double totalStockValue = 0.0;
    final lowStockProducts = <Product>[];
    final categoryStock = <String, int>{};
    final categoryByWarehouse = <String, Map<String, int>>{};
    final criticalStockByWarehouse = <String, List<Product>>{};

    // Initialize warehouse stats
    for (final code in WarehouseInfo.warehouses.keys) {
      warehouseStats[code] = WarehouseStats(
        code: code,
        totalAvailable: 0,
        totalReserved: 0,
        productCount: 0,
        lowStockCount: 0,
        categoryBreakdown: {},
        categoryProducts: {},
        totalValue: 0.0,
      );
      categoryByWarehouse[code] = {};
      criticalStockByWarehouse[code] = [];
    }
    
    // Process each product
    for (final product in products) {
      // Use actual warehouse stock data if available
      if (product.warehouseStock != null && product.warehouseStock!.isNotEmpty) {
        product.warehouseStock!.forEach((code, stock) {
          // Calculate value for this warehouse based on actual product price and stock
          final stockValue = stock.available * product.price;

          // Only process warehouses that we know about
          if (warehouseStats.containsKey(code) && criticalStockByWarehouse.containsKey(code)) {
            // Update warehouse stats
            warehouseStats[code]!.totalAvailable += stock.available;
            warehouseStats[code]!.totalReserved += stock.reserved;
            warehouseStats[code]!.totalValue += stockValue;
            if (stock.available > 0) warehouseStats[code]!.productCount++;
            if (stock.isLowStock) {
              warehouseStats[code]!.lowStockCount++;
              criticalStockByWarehouse[code]!.add(product);
            }

            // Track category breakdown per warehouse
            final category = product.category;
            warehouseStats[code]!.categoryBreakdown[category] =
                (warehouseStats[code]!.categoryBreakdown[category] ?? 0) + stock.actualAvailable;

            // Track products per category per warehouse
            if (!warehouseStats[code]!.categoryProducts.containsKey(category)) {
              warehouseStats[code]!.categoryProducts[category] = [];
            }
            warehouseStats[code]!.categoryProducts[category]!.add(product);

            if (categoryByWarehouse.containsKey(code)) {
              categoryByWarehouse[code]![category] =
                  (categoryByWarehouse[code]![category] ?? 0) + stock.actualAvailable;
            }
          }

          totalAvailable += stock.available;
          totalReserved += stock.reserved;
          totalStockValue += stockValue;
        });

        // Check for low stock across all warehouses
        if (product.totalAvailableStock <= 50) {
          lowStockProducts.add(product);
        }
      }

      // Update global category stock
      categoryStock[product.category] = (categoryStock[product.category] ?? 0) +
          product.totalAvailableStock;
    }
    
    // Sort and limit critical stock lists
    criticalStockByWarehouse.forEach((key, list) {
      list.sort((a, b) => a.totalAvailableStock.compareTo(b.totalAvailableStock));
      if (list.length > 5) {
        criticalStockByWarehouse[key] = list.take(5).toList();
      }
    });
    
    // Sort low stock products by total available
    lowStockProducts.sort((a, b) => a.totalAvailableStock.compareTo(b.totalAvailableStock));
    
    return StockStatistics(
      totalProducts: products.length,
      warehouseStats: warehouseStats,
      totalAvailable: totalAvailable,
      totalReserved: totalReserved,
      lowStockProducts: lowStockProducts.take(10).toList(),
      categoryStock: categoryStock,
      categoryByWarehouse: categoryByWarehouse,
      criticalStockByWarehouse: criticalStockByWarehouse,
      totalStockValue: totalStockValue,
    );
  }
}

// Warehouse statistics
class WarehouseStats {
  final String code;
  int totalAvailable;
  int totalReserved;
  int productCount;
  int lowStockCount;
  Map<String, int> categoryBreakdown;
  Map<String, List<Product>> categoryProducts;
  double manualUtilizationRate;
  double totalValue; // Track actual value based on product prices

  WarehouseStats({
    required this.code,
    required this.totalAvailable,
    required this.totalReserved,
    required this.productCount,
    required this.lowStockCount,
    required this.categoryBreakdown,
    this.categoryProducts = const {},
    this.manualUtilizationRate = 0.0,
    this.totalValue = 0.0,
  });

  int get actualAvailable => totalAvailable - totalReserved;
  double get utilizationRate => manualUtilizationRate > 0 ? manualUtilizationRate : (totalAvailable > 0 ? (totalReserved / totalAvailable * 100) : 0);
  double get warehouseValue => totalValue; // Use actual calculated value
}

class StockDashboardScreen extends ConsumerStatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  ConsumerState<StockDashboardScreen> createState() => _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> with SingleTickerProviderStateMixin {
  String? selectedWarehouse;
  String? selectedCategory;
  late TabController _tabController;
  final Map<String, double> _warehouseUtilization = {};
  final Map<String, int> _warehouseCapacity = {}; // Will be calculated from real data
  final Map<String, TextEditingController> _utilizationControllers = {};
  final Map<String, TextEditingController> _capacityControllers = {};
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllers();
    _loadSavedValues();
  }
  
  void _initializeControllers() {
    // Initialize controllers for all real warehouses from Firebase data
    for (final warehouse in WarehouseInfo.warehouses.keys) {
      // Initialize with 0 utilization until real data loads
      _warehouseUtilization[warehouse] = 0.0;
      _utilizationControllers[warehouse] = TextEditingController(
        text: '0.0'
      );
      // Set initial capacity based on actual stock data
      _warehouseCapacity[warehouse] = 0;
      _capacityControllers[warehouse] = TextEditingController(
        text: '0'
      );
    }
  }
  
  Future<void> _loadSavedValues() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load saved values asynchronously
      final prefs = await SharedPreferences.getInstance();

      // Update with saved values if they exist
      if (mounted) {
        setState(() {
          for (final warehouse in WarehouseInfo.warehouses.keys) {
            final utilizationKey = 'warehouse_utilization_$warehouse';
            final capacityKey = 'warehouse_capacity_$warehouse';

            final savedUtilization = prefs.getDouble(utilizationKey);
            if (savedUtilization != null) {
              _warehouseUtilization[warehouse] = savedUtilization;
              _utilizationControllers[warehouse]?.text = savedUtilization.toStringAsFixed(1);
            }

            final savedCapacity = prefs.getInt(capacityKey);
            if (savedCapacity != null) {
              _warehouseCapacity[warehouse] = savedCapacity;
              _capacityControllers[warehouse]?.text = savedCapacity.toString();
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _saveUtilization(String warehouse, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('warehouse_utilization_$warehouse', value);
    setState(() {
      _warehouseUtilization[warehouse] = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Utilization saved for $warehouse',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppleColors.accentSuccess,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  Future<void> _saveCapacity(String warehouse, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('warehouse_capacity_$warehouse', value);
    setState(() {
      _warehouseCapacity[warehouse] = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Capacity saved for $warehouse',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppleColors.accentSuccess,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Calculate warehouse capacities based on real stock data
  void _updateCapacitiesFromStockData(StockStatistics stats) {
    for (final entry in stats.warehouseStats.entries) {
      final warehouse = entry.key;
      final warehouseStats = entry.value;

      // Calculate estimated capacity as total available + reserved + some buffer (50%)
      // This gives a realistic capacity estimate based on current stock levels
      final currentTotal = warehouseStats.totalAvailable + warehouseStats.totalReserved;
      final estimatedCapacity = (currentTotal * 1.5).round(); // 50% buffer for realistic capacity

      if (estimatedCapacity > 0) {
        _warehouseCapacity[warehouse] = estimatedCapacity;
        _capacityControllers[warehouse]?.text = estimatedCapacity.toString();

        // Calculate utilization rate based on actual stock vs estimated capacity
        final utilizationRate = estimatedCapacity > 0
          ? ((currentTotal / estimatedCapacity) * 100).clamp(0.0, 100.0)
          : 0.0;
        _warehouseUtilization[warehouse] = utilizationRate;
        _utilizationControllers[warehouse]?.text = utilizationRate.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Dispose all controllers
    _utilizationControllers.forEach((_, controller) => controller.dispose());
    _capacityControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockStatsAsync = ref.watch(stockStatsProvider);
    final isMobile = ResponsiveHelper.isMobile(context);
    final numberFormat = NumberFormat('#,###');
    
    return Scaffold(
      backgroundColor: AppleColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppleColors.bgSecondary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: AppleColors.bgSecondary,
            border: Border(
              bottom: BorderSide(
                color: AppleColors.borderSubtle,
                width: 0.5,
              ),
            ),
          ),
        ),
        title: Text(
          'Stock Management Dashboard',
          style: TextStyle(
            color: AppleColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: AppleColors.textPrimary,
          size: 22,
        ),
        actions: const [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: AppleColors.bgSecondary,
              border: Border(
                bottom: BorderSide(
                  color: AppleColors.borderSubtle,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppleColors.accentPrimary,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppleColors.accentPrimary,
              unselectedLabelColor: AppleColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.08,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.08,
              ),
              tabs: [
                Tab(
                  text: 'Global Overview',
                  icon: Icon(
                    Icons.dashboard_rounded,
                    size: 20,
                  ),
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  text: 'Warehouse Details',
                  icon: Icon(
                    Icons.warehouse_rounded,
                    size: 20,
                  ),
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
        ),
      ),
      body: stockStatsAsync.when(
        data: (stats) {
          // Update warehouse capacities and utilization with real Firebase data
          if (!_isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateCapacitiesFromStockData(stats);
              }
            });
          }
          
          return TabBarView(
            controller: _tabController,
            children: [
              // Global Overview Tab - Redesigned for better clarity
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Summary Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppleColors.bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppleColors.borderSubtle,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppleColors.accentPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.assessment_rounded,
                                  size: 18,
                                  color: AppleColors.accentPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Inventory Summary',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppleColors.textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isMobile ? 2 : 4,
                              childAspectRatio: isMobile ? 2.2 : 2.5,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                              _buildQuickStat(
                                label: 'Total Products',
                                value: numberFormat.format(stats.totalProducts),
                                icon: Icons.inventory_2_rounded,
                                color: theme.primaryColor,
                                theme: theme,
                              ),
                              _buildQuickStat(
                                label: 'Total Stock Value',
                                value: '\$${numberFormat.format(stats.totalStockValue)}',
                                icon: Icons.attach_money_rounded,
                                color: Colors.green,
                                theme: theme,
                              ),
                              _buildQuickStat(
                                label: 'Total Available',
                                value: numberFormat.format(stats.totalAvailable),
                                icon: Icons.check_circle_rounded,
                                color: Colors.teal,
                                theme: theme,
                              ),
                              _buildQuickStat(
                                label: 'Total Committed',
                                value: numberFormat.format(stats.totalReserved),
                                icon: Icons.pending_rounded,
                                color: Colors.orange,
                                theme: theme,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                    const SizedBox(height: 24),
                    
                    
                    // Stock by Category - Line Chart
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppleColors.accentPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            size: 16,
                            color: AppleColors.accentPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Stock by Category',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppleColors.textPrimary,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryLineChart(stats, theme, numberFormat),
                    const SizedBox(height: 24),
                    
                    // Category Cards
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppleColors.accentPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            size: 16,
                            color: AppleColors.accentPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Category Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppleColors.textPrimary,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryCards(stats, theme, numberFormat, isMobile),
                    const SizedBox(height: 24),
                    
                    // Warehouse Utilization with Editable Fields
                    Text(
                      'Warehouse Utilization',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEnhancedWarehouseUtilization(stats, theme, numberFormat),
                    const SizedBox(height: 24),
                    
                    
                    // Critical Stock Alerts with better visualization
                    if (stats.lowStockProducts.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFF00FF),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, 
                                  color: const Color(0xFFFF00FF),
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Critical Stock Alerts',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF00FF),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF00FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${stats.lowStockProducts.length} items',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildImprovedLowStockList(stats.lowStockProducts, theme),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Warehouse Details Tab - Improved layout
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced warehouse selector
                    _buildEnhancedWarehouseSelector(stats, theme),
                    const SizedBox(height: 24),
                    
                    // Selected warehouse details
                    if (selectedWarehouse != null) 
                      _buildEnhancedWarehouseDetails(selectedWarehouse!, stats, theme, numberFormat),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () {
          return Container(
            color: AppleColors.bgPrimary,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Global Overview Tab - Loading state
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppleColors.bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppleColors.borderSubtle,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Loading Stock Data',
                              style: TextStyle(
                                color: AppleColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 2,
                              child: LinearProgressIndicator(
                                backgroundColor: AppleColors.fillTertiary,
                                valueColor: AlwaysStoppedAnimation<Color>(AppleColors.accentPrimary),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(3, (index) =>
                                Container(
                                  width: 100,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppleColors.fillTertiary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppleColors.borderSubtle,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppleColors.accentPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Skeleton warehouse cards
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: isMobile ? 1.5 : 1.3,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppleColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppleColors.borderSubtle,
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppleColors.accentPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Warehouse Details Tab - Loading state
                Container(
                  color: AppleColors.bgPrimary,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppleColors.accentPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading Warehouse Details',
                          style: TextStyle(
                            color: AppleColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        error: (error, stack) => Container(
          color: AppleColors.bgPrimary,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppleColors.bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppleColors.borderSubtle,
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 48,
                    color: AppleColors.accentWarning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to Load Data',
                    style: TextStyle(
                      color: AppleColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again.',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: AppleColors.accentPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        splashColor: Colors.white.withOpacity(0.1),
                        highlightColor: Colors.white.withOpacity(0.05),
                        onTap: () => ref.invalidate(stockStatsProvider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Text(
                            'Try Again',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildOverviewSection(StockStatistics stats, ThemeData theme, NumberFormat format) {
    return GridView.count(
      crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.5 : 1.8,
      children: [
        _buildStatCard(
          title: 'Total Products',
          value: format.format(stats.totalProducts),
          icon: Icons.inventory_2,
          color: const Color(0xFF00FFFF),
          theme: theme,
        ),
        _buildStatCard(
          title: 'Available Stock',
          value: format.format(stats.totalAvailable),
          icon: Icons.check_circle,
          color: const Color(0xFF00FF00),
          theme: theme,
        ),
        _buildStatCard(
          title: 'Reserved',
          value: format.format(stats.totalReserved),
          icon: Icons.lock,
          color: const Color(0xFFFFFF00),
          theme: theme,
        ),
        _buildStatCard(
          title: 'Low Stock Items',
          value: stats.lowStockProducts.length.toString(),
          icon: Icons.warning,
          color: const Color(0xFFFF00FF),
          theme: theme,
        ),
      ],
    );
  }
  
  Widget _buildQuickStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon, 
              color: color, 
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).primaryColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildImprovedWarehouseGrid(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
    bool isMobile,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 3,
        childAspectRatio: isMobile ? 1.2 : 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.warehouseStats.length,
      itemBuilder: (context, index) {
        final entry = stats.warehouseStats.entries.elementAt(index);
        final code = entry.key;
        final warehouseStats = entry.value;
        final info = WarehouseInfo.warehouses[code]!;
        
        // Calculate health score
        final healthScore = warehouseStats.lowStockCount == 0 ? 100 :
            ((warehouseStats.productCount - warehouseStats.lowStockCount) / 
             warehouseStats.productCount * 100).round();
        
        Color healthColor;
        IconData healthIcon;
        if (healthScore >= 80) {
          healthColor = const Color(0xFF00FF00); // Neon green for good
          healthIcon = Icons.check_circle;
        } else if (healthScore >= 60) {
          healthColor = const Color(0xFFFFFF00); // Amber for warning
          healthIcon = Icons.warning;
        } else {
          healthColor = const Color(0xFFFF00FF); // Magenta for critical
          healthIcon = Icons.error;
        }
        
        return InkWell(
          onTap: () {
            setState(() {
              selectedWarehouse = code;
              _tabController.animateTo(1); // Switch to details tab
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedWarehouse == code 
                    ? const Color(0xFF00FF00) 
                    : const Color(0xFF00FFFF),
                width: selectedWarehouse == code ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF37474F),
                        ),
                      ),
                    ),
                    Icon(healthIcon, color: healthColor, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  info['name'] ?? code,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${format.format(warehouseStats.totalAvailable)} units',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF37474F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                LinearProgressIndicator(
                  value: healthScore / 100,
                  backgroundColor: healthColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Health: $healthScore%',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (warehouseStats.lowStockCount > 0)
                      Text(
                        '${warehouseStats.lowStockCount} low',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFFFF00FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildCategoryDistributionOld(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
  ) {
    final sortedCategories = stats.categoryStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) {
          final category = sortedCategories[index];
          final percentage = (category.value / stats.totalAvailable * 100).toStringAsFixed(1);
          
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FFFF), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.key,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  format.format(category.value),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF37474F),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: sortedCategories.isNotEmpty ? (category.value / sortedCategories.first.value) : 0.0,
                  backgroundColor: theme.primaryColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  '$percentage% of total',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildImprovedLowStockList(List<Product> products, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: products.take(10).length,
        itemBuilder: (context, index) {
          final product = products[index];
          final stockLevel = product.totalAvailableStock;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: stockLevel <= 10 ? const Color(0xFFFF00FF) : const Color(0xFF00FFFF),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (stockLevel <= 10 ? const Color(0xFFFF00FF) : const Color(0xFF00FFFF)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      stockLevel.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: stockLevel <= 10 ? const Color(0xFFFF00FF) : const Color(0xFF00FFFF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'SKU: ${product.sku ?? 'N/A'} • ${product.category}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    // Navigate to product details
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEnhancedWarehouseSelector(StockStatistics stats, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Warehouse',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ChoiceChip(
                label: const Text('All Warehouses'),
                selected: selectedWarehouse == null,
                onSelected: (_) {
                  setState(() {
                    selectedWarehouse = null;
                  });
                },
              ),
              ...stats.warehouseStats.entries.map((entry) {
                final info = WarehouseInfo.warehouses[entry.key]!;
                return ChoiceChip(
                  label: Text('${entry.key} - ${info['name'] ?? entry.key}'),
                  selected: selectedWarehouse == entry.key,
                  onSelected: (_) {
                    setState(() {
                      selectedWarehouse = entry.key;
                    });
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEnhancedWarehouseDetails(
    String warehouseCode,
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
  ) {
    final warehouseStats = stats.warehouseStats[warehouseCode]!;
    final info = WarehouseInfo.warehouses[warehouseCode]!;
    final criticalItems = stats.criticalStockByWarehouse[warehouseCode] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warehouse Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warehouse, size: 32, color: theme.primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['name'] ?? warehouseCode,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Location: ${info['location'] ?? 'Unknown'} • Code: $warehouseCode',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Stats Grid with Total Space
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatCard(
              title: 'Total Stock',
              value: format.format(warehouseStats.totalAvailable),
              icon: Icons.inventory,
              color: const Color(0xFF00FFFF),
              theme: theme,
            ),
            _buildStatCard(
              title: 'Total Space',
              value: format.format(_warehouseCapacity[warehouseCode] ?? 10000),
              icon: Icons.space_dashboard,
              color: const Color(0xFF455A64),
              theme: theme,
            ),
            _buildStatCard(
              title: 'Reserved',
              value: format.format(warehouseStats.totalReserved),
              icon: Icons.lock,
              color: const Color(0xFFFFFF00),
              theme: theme,
            ),
            _buildStatCard(
              title: 'Available',
              value: format.format(warehouseStats.actualAvailable),
              icon: Icons.check_circle,
              color: const Color(0xFF00FF00),
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Category breakdown with improved visual cards
        if (warehouseStats.categoryBreakdown.isNotEmpty) ...[
          Text(
            'Stock by Category',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Display categories as visual cards in grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 3,
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: warehouseStats.categoryBreakdown.entries.length,
            itemBuilder: (context, index) {
              final entry = warehouseStats.categoryBreakdown.entries.elementAt(index);
              final percentage = (entry.value / warehouseStats.totalAvailable * 100);
              final isSelected = selectedCategory == entry.key;
              final color = _getCategoryColor(index);
              
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedCategory = selectedCategory == entry.key ? null : entry.key;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.03),
                    border: Border.all(
                      color: isSelected ? color : color.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(entry.key),
                            size: 20,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? color : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            format.format(entry.value),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Show selected category products if any
          if (selectedCategory != null && warehouseStats.categoryProducts[selectedCategory] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Products in $selectedCategory',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${warehouseStats.categoryProducts[selectedCategory]!.length} items',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: warehouseStats.categoryProducts[selectedCategory]!.length.clamp(0, 10),
                      itemBuilder: (context, index) {
                        final product = warehouseStats.categoryProducts[selectedCategory]![index];
                        final stock = product.warehouseStock?[warehouseCode];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (stock?.available ?? 0) < 50 
                                    ? const Color(0xFFFFFF00).withOpacity(0.1)
                                    : const Color(0xFF00FF00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${stock?.available ?? 0}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: (stock?.available ?? 0) < 50 ? const Color(0xFFFFFF00) : const Color(0xFF00FF00),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              product.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'SKU: ${product.sku ?? 'N/A'} • \$${product.price?.toStringAsFixed(2) ?? 'N/A'}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Text(
                              'Min: ${stock?.minStock ?? 50}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.disabledColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        
        // Critical items for this warehouse
        if (criticalItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Critical Stock Items',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFF00FF),
            ),
          ),
          const SizedBox(height: 16),
          _buildImprovedLowStockList(criticalItems, theme),
        ],
      ],
    );
  }
  
  Widget _buildWarehouseComparisonDashboard(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Warehouse Comparison',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Comparison table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Warehouse', style: Theme.of(context).textTheme.titleMedium)),
              DataColumn(label: Text('Total Stock', style: Theme.of(context).textTheme.titleMedium), numeric: true),
              DataColumn(label: Text('Available', style: Theme.of(context).textTheme.titleMedium), numeric: true),
              DataColumn(label: Text('Reserved', style: Theme.of(context).textTheme.titleMedium), numeric: true),
              DataColumn(label: Text('Health', style: Theme.of(context).textTheme.titleMedium), numeric: true),
            ],
            rows: stats.warehouseStats.entries.map((entry) {
              final code = entry.key;
              final warehouseStats = entry.value;
              final info = WarehouseInfo.warehouses[code]!;
              final healthScore = warehouseStats.lowStockCount == 0 ? 100 :
                  ((warehouseStats.productCount - warehouseStats.lowStockCount) / 
                   warehouseStats.productCount * 100).round();
              
              return DataRow(
                cells: [
                  DataCell(Text('$code - ${info['name'] ?? code}', 
                    style: Theme.of(context).textTheme.bodyMedium)),
                  DataCell(Text(format.format(warehouseStats.totalAvailable), 
                    style: Theme.of(context).textTheme.bodyMedium)),
                  DataCell(Text(format.format(
                    warehouseStats.totalAvailable - warehouseStats.totalReserved
                  ), style: Theme.of(context).textTheme.bodyMedium)),
                  DataCell(Text(format.format(warehouseStats.totalReserved), 
                    style: Theme.of(context).textTheme.bodyMedium)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: healthScore >= 80 ? const Color(0xFF546E7A).withOpacity(0.2) :
                               healthScore >= 60 ? const Color(0xFF78909C).withOpacity(0.2) :
                               const Color(0xFF5D4037).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$healthScore%',
                        style: TextStyle(
                          color: healthScore >= 80 ? const Color(0xFF607D8B) :
                                 healthScore >= 60 ? const Color(0xFF78909C) :
                                 Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  
  
  Widget _buildMetricCard(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryBreakdown(Map<String, int> categories, ThemeData theme, NumberFormat format) {
    final sortedCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sortedCategories.isEmpty) {
      return const Center(child: Text('No stock data available'));
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: sortedCategories.map((entry) {
          final maxValue = sortedCategories.isNotEmpty ? sortedCategories.first.value : 0;
          final percentage = maxValue > 0 ? (entry.value / maxValue) : 0.0;
          
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            format.format(entry.value),
                            style: TextStyle(
                              color: const Color(0xFF37474F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: theme.dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    entry.value < 50 ? const Color(0xFF78909C) : theme.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  
  // Chart building methods
  Widget _buildCategoryBarChart(StockStatistics stats, ThemeData theme) {
    if (stats.categoryStock.isEmpty) {
      return const Center(child: Text('No category data available'));
    }
    
    final sortedCategories = stats.categoryStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topCategories = sortedCategories.take(8).toList();
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: topCategories.isNotEmpty ? (topCategories.first.value.toDouble() * 1.2) : 10.0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = topCategories[group.x.toInt()];
              return BarTooltipItem(
                '${category.key}\n${NumberFormat('#,###').format(rod.toY.toInt())} units',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < topCategories.length) {
                  final category = topCategories[value.toInt()].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        category.length > 10 ? '${category.substring(0, 10)}...' : category,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 60,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: topCategories.isNotEmpty ? (topCategories.first.value / 5) : 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact().format(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        ),
        barGroups: topCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: category.value.toDouble(),
                color: const Color(0xFF00FF00),
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildWarehouseUtilizationChart(StockStatistics stats, ThemeData theme) {
    final warehouseData = stats.warehouseStats.entries
        .map((e) => MapEntry(e.key, e.value.utilizationRate))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final warehouse = warehouseData[group.x.toInt()];
                return BarTooltipItem(
                  '${WarehouseInfo.warehouses[warehouse.key]?['name'] ?? warehouse.key}\n${rod.toY.toStringAsFixed(1)}%',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < warehouseData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        warehouseData[value.toInt()].key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
          ),
          barGroups: warehouseData.asMap().entries.map((entry) {
            final index = entry.key;
            final utilization = entry.value.value;
            
            Color barColor;
            if (utilization > 80) {
              barColor = Colors.red;
            } else if (utilization > 60) {
              barColor = const Color(0xFF78909C);
            } else if (utilization > 40) {
              barColor = const Color(0xFF546E7A);
            } else {
              barColor = const Color(0xFF607D8B);
            }
            
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: utilization,
                  color: barColor,
                  width: 25,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
  
  
  // New improved category section with better readability
  Widget _buildImprovedCategorySection(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
    bool isMobile,
  ) {
    final sortedCategories = stats.categoryStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category cards with better visualization
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              childAspectRatio: isMobile ? 1.5 : 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: sortedCategories.length.clamp(0, 8),
            itemBuilder: (context, index) {
              final category = sortedCategories[index];
              final percentage = (category.value / stats.totalAvailable * 100);
              final color = _getCategoryColor(index);
              
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedCategory = selectedCategory == category.key ? null : category.key;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedCategory == category.key ? color : color.withOpacity(0.3),
                      width: selectedCategory == category.key ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category.key),
                            color: color,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category.key,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            format.format(category.value),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Show selected category products
          if (selectedCategory != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Products in $selectedCategory',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Click on a warehouse in the details tab to see specific products',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // Editable warehouse utilization
  Widget _buildEditableWarehouseUtilization(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: stats.warehouseStats.entries.map((entry) {
          final code = entry.key;
          final warehouseStats = entry.value;
          final info = WarehouseInfo.warehouses[code]!;
          // Get utilization value and sync controller if needed
          final utilization = _warehouseUtilization[code] ?? warehouseStats.utilizationRate;
          
          // Update controller text if it's empty or different from current value
          if (_utilizationControllers[code] != null) {
            final currentText = _utilizationControllers[code]!.text;
            final expectedText = utilization.toStringAsFixed(1);
            if (currentText.isEmpty || (currentText != expectedText && !_warehouseUtilization.containsKey(code))) {
              _utilizationControllers[code]!.text = expectedText;
            }
          }
          
          Color utilizationColor;
          if (utilization > 80) {
            utilizationColor = const Color(0xFFFF00FF);
          } else if (utilization > 60) {
            utilizationColor = const Color(0xFFFFFF00);
          } else {
            utilizationColor = const Color(0xFF00FF00);
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00FFFF), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      info['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${info['name']} ($code)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Value: \$${format.format(warehouseStats.warehouseValue.round())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF37474F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Utilization',
                          style: theme.textTheme.bodySmall,
                        ),
                        Container(
                          width: 80,
                          height: 35,
                          decoration: BoxDecoration(
                            border: Border.all(color: utilizationColor, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _utilizationControllers[code],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: utilizationColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                  onChanged: (value) {
                                    // Just update the local value, don't save automatically
                                    final parsed = double.tryParse(value);
                                    if (parsed != null && parsed >= 0 && parsed <= 100) {
                                      _warehouseUtilization[code] = parsed;
                                    }
                                  },
                                ),
                              ),
                              Text(
                                '%',
                                style: TextStyle(
                                  color: utilizationColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  final value = double.tryParse(_utilizationControllers[code]?.text ?? '0');
                                  if (value != null) {
                                    _saveUtilization(code, value);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.save,
                                    size: 16,
                                    color: utilizationColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: utilization / 100,
                  backgroundColor: utilizationColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(utilizationColor),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stock: ${format.format(warehouseStats.totalAvailable)} units',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Reserved: ${format.format(warehouseStats.totalReserved)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // Helper method to get category color
  Color _getCategoryColor(int index) {
    final colors = [
      const Color(0xFF00FF00), // Neon Green
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFF808080), // Grey
      const Color(0xFFFFFFFF), // White
      const Color(0xFF000000), // Black
      const Color(0xFFFF00FF), // Magenta (accent)
    ];
    return colors[index % colors.length];
  }
  
  // Helper method to get category icon
  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    if (categoryLower.contains('refriger')) return Icons.ac_unit;
    if (categoryLower.contains('freezer')) return Icons.kitchen;
    if (categoryLower.contains('cooler')) return Icons.kitchen;
    if (categoryLower.contains('prep')) return Icons.countertops;
    if (categoryLower.contains('display')) return Icons.storefront;
    if (categoryLower.contains('merchandis')) return Icons.store;
    if (categoryLower.contains('sandwich')) return Icons.fastfood;
    if (categoryLower.contains('pizza')) return Icons.local_pizza;
    return Icons.category;
  }
  
  // Table showing stock by category with numbers and percentages
  Widget _buildCategoryLineChart(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
  ) {
    final sortedCategories = stats.categoryStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sortedCategories.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: const Center(child: Text('No category data available')),
      );
    }
    
    final totalStock = stats.totalAvailable;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No redundant header - title is already shown above
          // Table content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: [
                DataColumn(
                  label: Text(
                    'Category',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Quantity',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Percentage',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              rows: sortedCategories.take(15).map((category) {
                final percentage = (category.value / totalStock * 100);
                final color = _getCategoryColor(sortedCategories.indexOf(category));
                
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category.key),
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              category.key,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        format.format(category.value),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      _buildStockStatusIndicator(category.value, percentage, theme),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          if (sortedCategories.length > 15)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '+ ${sortedCategories.length - 15} more categories',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.disabledColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStockStatusIndicator(int quantity, double percentage, ThemeData theme) {
    String status;
    Color color;
    IconData icon;
    
    if (percentage >= 20) {
      status = 'High';
      color = const Color(0xFF00FF00);
      icon = Icons.trending_up;
    } else if (percentage >= 10) {
      status = 'Normal';
      color = const Color(0xFF00FFFF);
      icon = Icons.trending_flat;
    } else if (percentage >= 5) {
      status = 'Low';
      color = const Color(0xFFFFFF00);
      icon = Icons.trending_down;
    } else {
      status = 'Critical';
      color = Colors.red;
      icon = Icons.warning;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // Category cards below the chart
  Widget _buildCategoryCards(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
    bool isMobile,
  ) {
    final sortedCategories = stats.categoryStock.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(
          color: theme.dividerColor,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              childAspectRatio: isMobile ? 1.5 : 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: sortedCategories.length.clamp(0, 8),
            itemBuilder: (context, index) {
              final category = sortedCategories[index];
              final percentage = (category.value / stats.totalAvailable * 100);
              final color = _getCategoryColor(index);
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category.key),
                          color: const Color(0xFF00FF00),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category.key,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          format.format(category.value),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF37474F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Enhanced warehouse utilization with capacity input
  Widget _buildEnhancedWarehouseUtilization(
    StockStatistics stats,
    ThemeData theme,
    NumberFormat format,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: stats.warehouseStats.entries.map((entry) {
          final code = entry.key;
          final warehouseStats = entry.value;
          final info = WarehouseInfo.warehouses[code]!;
          final capacity = _warehouseCapacity[code] ?? 10000;
          final actualUtilization = (warehouseStats.totalAvailable / capacity * 100).clamp(0.0, 100.0);
          
          Color utilizationColor;
          if (actualUtilization > 80) {
            utilizationColor = const Color(0xFFFF00FF); // Magenta for critical
          } else if (actualUtilization > 60) {
            utilizationColor = const Color(0xFFFFFF00); // Blue Grey 400 for warning
          } else {
            utilizationColor = const Color(0xFF00FF00); // Neon green for good
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      info['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${info['name']} ($code)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF37474F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stock: ${format.format(warehouseStats.totalAvailable)} / Capacity: ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF00FFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Capacity input field with save icon
                    Row(
                      children: [
                        Container(
                          width: 100,
                          height: 35,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF607D8B)),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey.withOpacity(0.05),
                          ),
                          child: TextFormField(
                            controller: _capacityControllers[code],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF37474F),
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4),
                              hintText: 'Capacity',
                            ),
                            onChanged: (value) {
                              // Just update the local value, don't save automatically
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed > 0) {
                                _warehouseCapacity[code] = parsed;
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            final value = int.tryParse(_capacityControllers[code]?.text ?? '0');
                            if (value != null && value > 0) {
                              _saveCapacity(code, value);
                            }
                          },
                          child: Icon(
                            Icons.save,
                            size: 20,
                            color: const Color(0xFF37474F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Utilization display
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Utilization',
                          style: theme.textTheme.bodySmall,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: utilizationColor.withOpacity(0.1),
                            border: Border.all(color: utilizationColor, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${actualUtilization.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: utilizationColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: actualUtilization / 100,
                  backgroundColor: utilizationColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(utilizationColor),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Value: \$${format.format(warehouseStats.warehouseValue.round())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF37474F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Reserved: ${format.format(warehouseStats.totalReserved)} units',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}