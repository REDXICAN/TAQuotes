// lib/features/admin/presentation/screens/user_info_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/rbac_service.dart';
import '../../../../core/services/app_logger.dart';

// Auto-refreshing provider for fetching all users with their detailed information
final allUsersProvider = StreamProvider.autoDispose<List<UserInfo>>((ref) async* {
  // Initial load
  yield await _fetchAllUsers();

  // Auto-refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      yield await _fetchAllUsers();
    } catch (e) {
      // Continue with previous data on error, don't break the stream
      AppLogger.error('Auto-refresh failed for users', error: e);
    }
  }
});

// Extract the logic to a separate function for reuse
Future<List<UserInfo>> _fetchAllUsers() async {
  final database = FirebaseDatabase.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  // Check if user has permission to access user info dashboard
  if (currentUser == null) {
    throw Exception('User not authenticated');
  }

  final hasPermission = await RBACService.hasPermission('access_user_info_dashboard');
  if (!hasPermission) {
    throw Exception('Access denied: SuperAdmin privileges required');
  }

  try {
    DataSnapshot usersSnapshot;

    // Try 'user_profiles' first (recommended path with simpler permissions)
    try {
      usersSnapshot = await database.ref('user_profiles').get();
      AppLogger.info('Successfully accessed user_profiles path');
    } catch (e) {
      // If user_profiles fails, try fallback to 'users' path
      AppLogger.warning('user_profiles path failed, trying users path', error: e);
      usersSnapshot = await database.ref('users').get();
      AppLogger.info('Successfully accessed users path as fallback');
    }

    if (!usersSnapshot.exists) {
      AppLogger.info('No user data found in database (checked both user_profiles and users paths)');
      return [];
    }

    final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
    final List<UserInfo> userInfoList = [];

    for (final entry in users.entries) {
      final userId = entry.key;
      final userData = Map<String, dynamic>.from(entry.value);

      // Get user's quotes count and calculate detailed metrics
      final quotesSnapshot = await database.ref('quotes/$userId').get();
      int quotesCount = 0;
      double totalRevenue = 0;
      List<Map<String, dynamic>> latestQuotes = [];
      Map<String, int> topProducts = {};

      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        quotesCount = quotesData.length;

        // Process each quote for detailed metrics
        final quotesWithDates = <Map<String, dynamic>>[];

        for (final quoteEntry in quotesData.entries) {
          final quote = Map<String, dynamic>.from(quoteEntry.value);
          final createdAt = DateTime.tryParse(quote['created_at'] ?? '') ?? DateTime.now();

          quotesWithDates.add({
            ...quote,
            'id': quoteEntry.key,
            'parsed_date': createdAt,
          });

          // Calculate revenue from accepted quotes
          if (quote['status']?.toString().toLowerCase() == 'accepted' ||
              quote['status']?.toString().toLowerCase() == 'closed' ||
              quote['status']?.toString().toLowerCase() == 'sold') {
            totalRevenue += PriceFormatter.safeToDouble(quote['total']);
          }
        }

        // Sort quotes by date and get latest 5
        quotesWithDates.sort((a, b) => b['parsed_date'].compareTo(a['parsed_date']));
        latestQuotes = quotesWithDates.take(5).map((q) => {
          'number': q['quote_number'] ?? 'Q-${q['id']?.substring(0, 8) ?? 'Unknown'}',
          'client': q['client_name'] ?? 'Unknown Client',
          'amount': (q['total'] ?? 0).toStringAsFixed(2),
        }).toList();

        // Calculate top products from quote items
        for (final quote in quotesWithDates) {
          final items = quote['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final productName = item['sku'] ?? item['product_name'] ?? 'Unknown Product';
              final quantity = (item['quantity'] ?? 0) as int;
              topProducts[productName] = (topProducts[productName] ?? 0) + quantity;
            }
          }
        }
      }

      // Convert top products to list format
      final topProductsList = topProducts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      final formattedTopProducts = topProductsList.take(5).map((entry) => {
        'name': entry.key,
        'count': entry.value,
      }).toList();

      // Get user's clients count
      final clientsSnapshot = await database.ref('clients/$userId').get();
      int clientsCount = 0;
      if (clientsSnapshot.exists) {
        final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);
        clientsCount = clientsData.length;
      }

      userInfoList.add(UserInfo(
        uid: userId,
        email: userData['email'] ?? userData['emailAddress'] ?? '',
        displayName: userData['displayName'] ?? userData['name'] ?? userData['full_name'] ?? userData['fullName'] ?? 'Unknown',
        role: userData['role'] ?? userData['user_role'] ?? 'distributor',
        createdAt: DateTime.tryParse(userData['createdAt'] ?? userData['created_at'] ?? userData['registrationDate'] ?? '') ?? DateTime.now(),
        lastLoginAt: DateTime.tryParse(userData['lastLoginAt'] ?? userData['last_login_at'] ?? userData['lastLogin'] ?? '') ?? DateTime.now(),
        isAdmin: (userData['role'] ?? userData['user_role'] ?? '').toLowerCase() == 'admin' ||
                 (userData['role'] ?? userData['user_role'] ?? '').toLowerCase() == 'superadmin',
        quotesCount: quotesCount,
        clientsCount: clientsCount,
        totalRevenue: totalRevenue,
        phoneNumber: userData['phoneNumber'] ?? userData['phone'] ?? userData['phone_number'] ?? '',
        photoUrl: userData['photoUrl'] ?? userData['photo_url'] ?? userData['profileImage'] ?? '',
        isActive: userData['isActive'] ?? userData['active'] ?? userData['status'] != 'inactive',
        latestQuotes: latestQuotes,
        topProducts: formattedTopProducts,
      ));
    }

    // Sort by total revenue (best performers first)
    userInfoList.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return userInfoList;
  } catch (e) {
    // Handle specific Firebase permission errors
    if (e.toString().contains('permission') ||
        e.toString().contains('denied') ||
        e.toString().contains('PERMISSION_DENIED')) {
      AppLogger.error('Permission denied accessing user_profiles', error: e);
      throw Exception('Permission denied: Unable to access user data. Check Firebase database rules.');
    }

    // Handle network or connection errors
    if (e.toString().contains('network') ||
        e.toString().contains('connection') ||
        e.toString().contains('timeout')) {
      AppLogger.error('Network error loading users', error: e);
      throw Exception('Network error: Please check your internet connection and try again.');
    }

    AppLogger.error('Error loading users from user_profiles', error: e);
    rethrow;
  }
}

// User Info model
class UserInfo {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isAdmin;
  final int quotesCount;
  final int clientsCount;
  final double totalRevenue;
  final String phoneNumber;
  final String photoUrl;
  final bool isActive;
  final List<Map<String, dynamic>>? latestQuotes;
  final List<Map<String, dynamic>>? topProducts;

  UserInfo({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
    required this.isAdmin,
    required this.quotesCount,
    required this.clientsCount,
    required this.totalRevenue,
    this.phoneNumber = '',
    this.photoUrl = '',
    this.isActive = true,
    this.latestQuotes,
    this.topProducts,
  });
}

class UserInfoDashboardScreen extends ConsumerStatefulWidget {
  const UserInfoDashboardScreen({super.key});

  @override
  ConsumerState<UserInfoDashboardScreen> createState() => _UserInfoDashboardScreenState();
}

class _UserInfoDashboardScreenState extends ConsumerState<UserInfoDashboardScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedRole = 'all';
  final String _sortBy = 'lastLogin';
  // Selected user ID kept for potential future user details panel
  // ignore: unused_field
  int? _selectedUserId; // For showing user details
  bool _hasAccess = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to access this page'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    // Check if user has permission to access user info dashboard
    final hasPermission = await RBACService.hasPermission('access_user_info_dashboard');

    if (!hasPermission) {
      // No permission - BLOCK ACCESS
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access Denied: SuperAdmin privileges required for User Dashboard.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
      AppLogger.warning('Access denied to User Info Dashboard', data: {'user_email': user.email});
      return;
    }

    AppLogger.info('User Info Dashboard access granted', data: {'user_email': user.email});
    if (mounted) {
      setState(() {
        _hasAccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(allUsersProvider);
    // Number format kept for potential future statistics formatting
    // ignore: unused_local_variable
    final numberFormat = NumberFormat('#,###');
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM dd, yyyy');
    // Time format kept for potential future time-based features
    // ignore: unused_local_variable
    final timeFormat = DateFormat('hh:mm a');
    // isMobile kept for potential future responsive adjustments
    // ignore: unused_local_variable
    final isMobile = ResponsiveHelper.isMobile(context);

    // Show loading while checking access
    if (!_hasAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Additional check for current auth state
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Information'),
        ),
        body: const Center(
          child: Text('Please log in to access this page'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Information Dashboard'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.receipt), text: 'Quotes'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allUsersProvider);
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Analytics Tab
          usersAsync.when(
            data: (users) => _buildAnalyticsTab(users, theme, currencyFormat, dateFormat),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorWidget(error, ref),
          ),
          // Quotes Tab
          usersAsync.when(
            data: (users) => _buildQuotesTab(users, theme, currencyFormat, dateFormat),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorWidget(error, ref),
          ),
          // Users Tab
          usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No Users Found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No user data available in the database.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Filter and sort users
          var filteredUsers = users.where((user) {
            // Filter by search query
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!user.displayName.toLowerCase().contains(query) &&
                  !user.email.toLowerCase().contains(query) &&
                  !user.phoneNumber.toLowerCase().contains(query)) {
                return false;
              }
            }

            // Filter by role
            if (_selectedRole != 'all' && user.role != _selectedRole) {
              return false;
            }

            return true;
          }).toList();

          // Sort users
          switch (_sortBy) {
            case 'name':
              filteredUsers.sort((a, b) => a.displayName.compareTo(b.displayName));
              break;
            case 'revenue':
              filteredUsers.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
              break;
            case 'quotes':
              filteredUsers.sort((a, b) => b.quotesCount.compareTo(a.quotesCount));
              break;
            case 'clients':
              filteredUsers.sort((a, b) => b.clientsCount.compareTo(a.clientsCount));
              break;
            case 'lastLogin':
            default:
              filteredUsers.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
              break;
          }

          return _buildUsersTab(filteredUsers, theme, currencyFormat, dateFormat);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorWidget(error, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(
    List<UserInfo> users,
    ThemeData theme,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    // Calculate overall metrics
    final totalUsers = users.length;
    final totalQuotes = users.fold<int>(0, (sum, user) => sum + user.quotesCount);
    final totalRevenue = users.fold<double>(0, (sum, user) => sum + user.totalRevenue);
    final totalClients = users.fold<int>(0, (sum, user) => sum + user.clientsCount);
    final avgQuotesPerUser = totalUsers > 0 ? (totalQuotes / totalUsers).toStringAsFixed(1) : '0';
    final avgRevenuePerUser = totalUsers > 0 ? currencyFormat.format(totalRevenue / totalUsers) : '\$0';

    // Get top performers
    final topPerformers = List<UserInfo>.from(users)
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Statistics Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard(
                'Total Revenue',
                currencyFormat.format(totalRevenue),
                Icons.attach_money,
                Colors.green,
              ),
              _buildMetricCard(
                'Total Quotes',
                totalQuotes.toString(),
                Icons.receipt_long,
                Colors.blue,
              ),
              _buildMetricCard(
                'Total Users',
                totalUsers.toString(),
                Icons.people,
                Colors.purple,
              ),
              _buildMetricCard(
                'Total Clients',
                totalClients.toString(),
                Icons.business,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Average Metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Average Performance',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAverageMetric(
                          'Avg Quotes/User',
                          avgQuotesPerUser,
                          Icons.person,
                        ),
                      ),
                      Expanded(
                        child: _buildAverageMetric(
                          'Avg Revenue/User',
                          avgRevenuePerUser,
                          Icons.trending_up,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Top Performers
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Performers',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ...topPerformers.take(5).map((user) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                      child: Text(
                        user.displayName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: _getRoleColor(user.role),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(user.displayName),
                    subtitle: Text('${user.quotesCount} quotes • ${user.clientsCount} clients'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(user.totalRevenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          user.role,
                          style: TextStyle(
                            color: _getRoleColor(user.role),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesTab(
    List<UserInfo> users,
    ThemeData theme,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    // Gather all quotes from all users
    final allQuotes = <Map<String, dynamic>>[];
    for (final user in users) {
      if (user.latestQuotes != null) {
        for (final quote in user.latestQuotes!) {
          allQuotes.add({
            ...quote,
            'userName': user.displayName,
            'userEmail': user.email,
            'userId': user.uid,
          });
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Quotes Overview',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          if (allQuotes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No quotes available'),
                ),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Quote #')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Client')),
                    DataColumn(label: Text('Amount')),
                  ],
                  rows: allQuotes.take(20).map((quote) => DataRow(
                    cells: [
                      DataCell(Text(quote['number'] ?? '')),
                      DataCell(Text(quote['userName'] ?? '')),
                      DataCell(Text(quote['client'] ?? '')),
                      DataCell(Text('\$${quote['amount'] ?? '0'}')),
                    ],
                  )).toList(),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // User Quotes Summary
          Text(
            'Quotes by User',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          ...users.where((u) => u.quotesCount > 0).map((user) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                child: Text(
                  user.quotesCount.toString(),
                  style: TextStyle(
                    color: _getRoleColor(user.role),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(user.displayName),
              subtitle: Text(user.email),
              trailing: Text(
                currencyFormat.format(user.totalRevenue),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: () => _showUserDetailsDialog(user, theme, currencyFormat, dateFormat),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildUsersTab(
    List<UserInfo> filteredUsers,
    ThemeData theme,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search and filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search users...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _selectedRole,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Roles')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'sales', child: Text('Sales')),
                            DropdownMenuItem(value: 'distributor', child: Text('Distributor')),
                          ],
                          onChanged: (value) => setState(() => _selectedRole = value!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // User tiles grid
                Text(
                  'Users (${filteredUsers.length})',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isMobile ? 3.5 : 2.0,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _buildUserTile(user, theme, currencyFormat, dateFormat);
                  },
                ),
              ],
            ),
          );
  }

  Widget _buildUserTile(
    UserInfo user,
    ThemeData theme,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final roleColor = user.role == 'admin'
        ? Colors.purple
        : user.role == 'sales'
            ? Colors.blue
            : Colors.green;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          _showUserDetailsDialog(user, theme, currencyFormat, dateFormat);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withValues(alpha: 0.2),
                    child: Text(
                      user.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.receipt_long,
                    user.quotesCount.toString(),
                    'Quotes',
                    theme,
                  ),
                  _buildStatItem(
                    Icons.people,
                    user.clientsCount.toString(),
                    'Clients',
                    theme,
                  ),
                  _buildStatItem(
                    Icons.attach_money,
                    currencyFormat.format(user.totalRevenue),
                    'Revenue',
                    theme,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Latest Quotes Section
              if (user.latestQuotes != null && user.latestQuotes!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Latest Quotes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...user.latestQuotes!.take(3).map((quote) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 4, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${quote['number']} - \$${quote['amount']}',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],

              // Top Products Section
              if (user.topProducts != null && user.topProducts!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Top Products',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...user.topProducts!.take(3).map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 4, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${product['name']} (${product['count']}x)',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],

              const SizedBox(height: 8),
              const Divider(),
              Row(
                children: [
                  Icon(
                    user.isActive ? Icons.circle : Icons.circle_outlined,
                    size: 8,
                    color: user.isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    user.isActive ? 'Active' : 'Inactive',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    'Last: ${dateFormat.format(user.lastLoginAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDetailsDialog(
    UserInfo user,
    ThemeData theme,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Email: ${user.email}'),
              Text('Role: ${user.role}'),
              Text('Phone: ${user.phoneNumber.isEmpty ? "Not provided" : user.phoneNumber}'),
              const SizedBox(height: 16),
              Text('Total Revenue: ${currencyFormat.format(user.totalRevenue)}'),
              Text('Total Quotes: ${user.quotesCount}'),
              Text('Total Clients: ${user.clientsCount}'),
              const SizedBox(height: 16),
              if (user.latestQuotes != null && user.latestQuotes!.isNotEmpty) ...[
                const Text('Latest 5 Quotes:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...user.latestQuotes!.take(5).map((q) =>
                  Text('• ${q['number']} - ${q['client']} - \$${q['amount']}')
                ),
              ],
              const SizedBox(height: 16),
              if (user.topProducts != null && user.topProducts!.isNotEmpty) ...[
                const Text('Top 5 Products:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...user.topProducts!.take(5).map((p) =>
                  Text('• ${p['name']} - Sold ${p['count']} times')
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: theme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'superadmin':
        return Colors.purple;
      case 'sales':
        return Colors.blue;
      case 'distributor':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageMetric(
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: theme.primaryColor, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget(Object error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error.toString().contains('Permission denied')
                ? Icons.security
                : Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              error.toString().contains('Permission denied')
                ? 'Access Denied'
                : 'Error Loading Users',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString().contains('Permission denied')
                ? 'You don\'t have permission to access user data.'
                : error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.invalidate(allUsersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}