// lib/features/admin/presentation/screens/user_info_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/config/env_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Provider for fetching all users with their detailed information
final allUsersProvider = FutureProvider<List<UserInfo>>((ref) async {
  final database = FirebaseDatabase.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  
  // Check if user is admin
  if (currentUser?.email != EnvConfig.adminEmail) {
    // Return mock data for demonstration
    return _getMockUsers();
  }
  
  try {
    // Get all users
    final usersSnapshot = await database.ref('users').get();
    if (!usersSnapshot.exists) {
      // Return mock data if no real users
      return _getMockUsers();
    }
    
    final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
    final List<UserInfo> userInfoList = [];
    
    for (final entry in users.entries) {
      final userId = entry.key;
      final userData = Map<String, dynamic>.from(entry.value);
      
      // Get user's quotes count
      final quotesSnapshot = await database.ref('quotes/$userId').get();
      int quotesCount = 0;
      double totalRevenue = 0;
      if (quotesSnapshot.exists) {
        final quotesData = Map<String, dynamic>.from(quotesSnapshot.value as Map);
        quotesCount = quotesData.length;
        
        // Calculate total revenue from accepted quotes
        for (final quoteEntry in quotesData.values) {
          final quote = Map<String, dynamic>.from(quoteEntry as Map);
          if (quote['status']?.toString().toLowerCase() == 'accepted') {
            totalRevenue += (quote['total'] ?? 0).toDouble();
          }
        }
      }
      
      // Get user's clients count
      final clientsSnapshot = await database.ref('clients/$userId').get();
      int clientsCount = 0;
      if (clientsSnapshot.exists) {
        final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);
        clientsCount = clientsData.length;
      }
      
      userInfoList.add(UserInfo(
        uid: userId,
        email: userData['email'] ?? '',
        displayName: userData['displayName'] ?? 'Unknown',
        role: userData['role'] ?? 'sales',
        createdAt: DateTime.tryParse(userData['createdAt'] ?? '') ?? DateTime.now(),
        lastLoginAt: DateTime.tryParse(userData['lastLoginAt'] ?? '') ?? DateTime.now(),
        isAdmin: userData['isAdmin'] ?? false,
        quotesCount: quotesCount,
        clientsCount: clientsCount,
        totalRevenue: totalRevenue,
        phoneNumber: userData['phoneNumber'] ?? '',
        photoUrl: userData['photoUrl'] ?? '',
        isActive: userData['isActive'] ?? true,
      ));
    }
    
    // Sort by last login
    userInfoList.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
    
    // Return mock data if no real users found
    if (userInfoList.isEmpty) {
      return _getMockUsers();
    }
    
    return userInfoList;
  } catch (e) {
    print('Error loading users: $e');
    // Return mock data on error
    return _getMockUsers();
  }
});

// Mock data generator
List<UserInfo> _getMockUsers() {
  final now = DateTime.now();
  return [
    UserInfo(
      uid: 'mock_1',
      email: 'john.smith@example.com',
      displayName: 'John Smith',
      role: 'admin',
      createdAt: now.subtract(const Duration(days: 180)),
      lastLoginAt: now.subtract(const Duration(hours: 2)),
      isAdmin: true,
      quotesCount: 45,
      clientsCount: 23,
      totalRevenue: 125450.00,
      phoneNumber: '555-0101',
      photoUrl: '',
      isActive: true,
      latestQuotes: [
        {'number': 'Q-2025-1045', 'client': 'ABC Restaurant', 'amount': '8750.00'},
        {'number': 'Q-2025-1044', 'client': 'XYZ Hotel', 'amount': '12340.00'},
        {'number': 'Q-2025-1043', 'client': 'Quick Cafe', 'amount': '5600.00'},
        {'number': 'Q-2025-1042', 'client': 'Prime Diner', 'amount': '9800.00'},
        {'number': 'Q-2025-1041', 'client': 'Metro Bar', 'amount': '4200.00'},
      ],
      topProducts: [
        {'name': 'TSR-49SD', 'count': 12},
        {'name': 'TBF-2SD', 'count': 8},
        {'name': 'PRO-26R', 'count': 7},
        {'name': 'M3R48', 'count': 6},
        {'name': 'TGF-23F', 'count': 5},
      ],
    ),
    UserInfo(
      uid: 'mock_2',
      email: 'maria.garcia@example.com',
      displayName: 'Maria Garcia',
      role: 'sales',
      createdAt: now.subtract(const Duration(days: 120)),
      lastLoginAt: now.subtract(const Duration(hours: 5)),
      isAdmin: false,
      quotesCount: 67,
      clientsCount: 31,
      totalRevenue: 89750.00,
      phoneNumber: '555-0102',
      photoUrl: '',
      isActive: true,
      latestQuotes: [
        {'number': 'Q-2025-1040', 'client': 'City Grill', 'amount': '6750.00'},
        {'number': 'Q-2025-1039', 'client': 'Ocean View', 'amount': '9850.00'},
        {'number': 'Q-2025-1038', 'client': 'Garden Bistro', 'amount': '4300.00'},
        {'number': 'Q-2025-1037', 'client': 'Mountain Lodge', 'amount': '11200.00'},
        {'number': 'Q-2025-1036', 'client': 'Urban Kitchen', 'amount': '7650.00'},
      ],
      topProducts: [
        {'name': 'TGM-50F', 'count': 15},
        {'name': 'TSR-23SD', 'count': 11},
        {'name': 'M3F72', 'count': 9},
        {'name': 'PRO-50R', 'count': 8},
        {'name': 'TBB-24', 'count': 7},
      ],
    ),
    UserInfo(
      uid: 'mock_3',
      email: 'james.wilson@example.com',
      displayName: 'James Wilson',
      role: 'sales',
      createdAt: now.subtract(const Duration(days: 90)),
      lastLoginAt: now.subtract(const Duration(days: 1)),
      isAdmin: false,
      quotesCount: 38,
      clientsCount: 18,
      totalRevenue: 67890.00,
      phoneNumber: '555-0103',
      photoUrl: '',
      isActive: true,
      latestQuotes: [
        {'number': 'Q-2025-1035', 'client': 'Downtown Deli', 'amount': '3450.00'},
        {'number': 'Q-2025-1034', 'client': 'Riverside Cafe', 'amount': '5670.00'},
        {'number': 'Q-2025-1033', 'client': 'Plaza Restaurant', 'amount': '8900.00'},
        {'number': 'Q-2025-1032', 'client': 'Corner Bakery', 'amount': '2340.00'},
        {'number': 'Q-2025-1031', 'client': 'Main Street Bar', 'amount': '6780.00'},
      ],
      topProducts: [
        {'name': 'TOM-40L', 'count': 10},
        {'name': 'TSR-72SD', 'count': 8},
        {'name': 'TBF-35SD', 'count': 7},
        {'name': 'M3R24', 'count': 6},
        {'name': 'PRO-15F', 'count': 5},
      ],
    ),
    UserInfo(
      uid: 'mock_4',
      email: 'sarah.johnson@example.com',
      displayName: 'Sarah Johnson',
      role: 'distributor',
      createdAt: now.subtract(const Duration(days: 60)),
      lastLoginAt: now.subtract(const Duration(days: 3)),
      isAdmin: false,
      quotesCount: 12,
      clientsCount: 8,
      totalRevenue: 34560.00,
      phoneNumber: '555-0104',
      photoUrl: '',
      isActive: true,
      latestQuotes: [
        {'number': 'Q-2025-1030', 'client': 'Sunset Grill', 'amount': '4560.00'},
        {'number': 'Q-2025-1029', 'client': 'Harbor View', 'amount': '3890.00'},
        {'number': 'Q-2025-1028', 'client': 'Forest Lodge', 'amount': '2340.00'},
        {'number': 'Q-2025-1027', 'client': 'Lake House', 'amount': '5670.00'},
        {'number': 'Q-2025-1026', 'client': 'Valley Inn', 'amount': '3120.00'},
      ],
      topProducts: [
        {'name': 'TGF-23F', 'count': 6},
        {'name': 'TSS-48', 'count': 5},
        {'name': 'M3F48', 'count': 4},
        {'name': 'TBR-72SD', 'count': 4},
        {'name': 'PRO-26F', 'count': 3},
      ],
    ),
    UserInfo(
      uid: 'mock_5',
      email: 'mike.davis@example.com',
      displayName: 'Mike Davis',
      role: 'distributor',
      createdAt: now.subtract(const Duration(days: 30)),
      lastLoginAt: now.subtract(const Duration(days: 7)),
      isAdmin: false,
      quotesCount: 5,
      clientsCount: 3,
      totalRevenue: 12340.00,
      phoneNumber: '555-0105',
      photoUrl: '',
      isActive: false,
      latestQuotes: [
        {'number': 'Q-2025-1025', 'client': 'Beach Cafe', 'amount': '2100.00'},
        {'number': 'Q-2025-1024', 'client': 'Hill Restaurant', 'amount': '3450.00'},
        {'number': 'Q-2025-1023', 'client': 'Park Diner', 'amount': '1890.00'},
        {'number': 'Q-2025-1022', 'client': 'River Grill', 'amount': '2780.00'},
        {'number': 'Q-2025-1021', 'client': 'Town Tavern', 'amount': '2120.00'},
      ],
      topProducts: [
        {'name': 'TSR-35SD', 'count': 3},
        {'name': 'TGM-77F', 'count': 2},
        {'name': 'M3R72', 'count': 2},
        {'name': 'PRO-12F', 'count': 2},
        {'name': 'TBF-24SD', 'count': 1},
      ],
    ),
  ];
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

class _UserInfoDashboardScreenState extends ConsumerState<UserInfoDashboardScreen> {
  String _searchQuery = '';
  String _selectedRole = 'all';
  String _sortBy = 'lastLogin';
  int? _selectedUserId; // For showing user details
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(allUsersProvider);
    final numberFormat = NumberFormat('#,###');
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final isMobile = ResponsiveHelper.isMobile(context);
    
    // Simple authentication check - allow any logged in user for now
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
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Text('No users found'),
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
          
          // Tile-based layout instead of tabs
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
                    childAspectRatio: isMobile ? 3 : 1.5,
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
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading users: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allUsersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withOpacity(0.2),
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
                      color: roleColor.withOpacity(0.2),
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
              
              const Spacer(),
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
              Text('Phone: ${user.phoneNumber}'),
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
  
  Widget _buildOverviewTab(
    List<UserInfo> allUsers,
    List<UserInfo> filteredUsers,
    ThemeData theme,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
    bool isMobile,
  ) {
    // Calculate statistics
    final totalUsers = allUsers.length;
    final activeUsers = allUsers.where((u) => u.isActive).length;
    final adminUsers = allUsers.where((u) => u.isAdmin).length;
    final totalRevenue = allUsers.fold(0.0, (sum, u) => sum + u.totalRevenue);
    final totalQuotes = allUsers.fold(0, (sum, u) => sum + u.quotesCount);
    final totalClients = allUsers.fold(0, (sum, u) => sum + u.clientsCount);
    
    // Get users by role
    final roleDistribution = <String, int>{};
    for (final user in allUsers) {
      roleDistribution[user.role] = (roleDistribution[user.role] ?? 0) + 1;
    }
    
    // Get recently active users
    final now = DateTime.now();
    final recentlyActive = allUsers.where((u) {
      return now.difference(u.lastLoginAt).inDays <= 7;
    }).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
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
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'lastLogin', child: Text('Last Login')),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'revenue', child: Text('Revenue')),
                    DropdownMenuItem(value: 'quotes', child: Text('Quotes')),
                    DropdownMenuItem(value: 'clients', child: Text('Clients')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Statistics Cards
          Text(
            'User Statistics',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isMobile ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isMobile ? 1.5 : 1.8,
            children: [
              _buildStatCard(
                title: 'Total Users',
                value: numberFormat.format(totalUsers),
                icon: Icons.people,
                color: Colors.blue,
                theme: theme,
              ),
              _buildStatCard(
                title: 'Active Users',
                value: numberFormat.format(activeUsers),
                icon: Icons.verified_user,
                color: Colors.green,
                theme: theme,
              ),
              _buildStatCard(
                title: 'Admin Users',
                value: numberFormat.format(adminUsers),
                icon: Icons.admin_panel_settings,
                color: Colors.purple,
                theme: theme,
              ),
              _buildStatCard(
                title: 'Total Revenue',
                value: currencyFormat.format(totalRevenue),
                icon: Icons.attach_money,
                color: Colors.orange,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Role Distribution
          Text(
            'Users by Role',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildRolePieChart(roleDistribution, theme),
          ),
          const SizedBox(height: 24),
          
          // Recently Active Users
          Text(
            'Recently Active Users (Last 7 Days)',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: recentlyActive.take(10).map((user) {
                final hoursSinceLogin = DateTime.now().difference(user.lastLoginAt).inHours;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Text(
                      user.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: hoursSinceLogin < 24 ? Colors.green.withOpacity(0.1) : theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hoursSinceLogin < 1 ? 'Just now' :
                      hoursSinceLogin < 24 ? '$hoursSinceLogin hours ago' :
                      '${hoursSinceLogin ~/ 24} days ago',
                      style: TextStyle(
                        color: hoursSinceLogin < 24 ? Colors.green : theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserListTab(
    List<UserInfo> users,
    ThemeData theme,
    DateFormat dateFormat,
    DateFormat timeFormat,
    NumberFormat currencyFormat,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: users.map((user) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
            child: ExpansionTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                    child: Text(
                      user.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: _getRoleColor(user.role),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  if (user.isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Text(
                    user.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (user.isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: theme.disabledColor),
                      const SizedBox(width: 4),
                      Text(
                        'Last login: ${dateFormat.format(user.lastLoginAt)} at ${timeFormat.format(user.lastLoginAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildUserMetric(
                            label: 'Quotes',
                            value: user.quotesCount.toString(),
                            icon: Icons.receipt_long,
                            color: Colors.blue,
                            theme: theme,
                          ),
                          _buildUserMetric(
                            label: 'Clients',
                            value: user.clientsCount.toString(),
                            icon: Icons.people_outline,
                            color: Colors.orange,
                            theme: theme,
                          ),
                          _buildUserMetric(
                            label: 'Revenue',
                            value: currencyFormat.format(user.totalRevenue),
                            icon: Icons.attach_money,
                            color: Colors.green,
                            theme: theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: theme.dividerColor),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Role', user.role.toUpperCase(), theme),
                                const SizedBox(height: 8),
                                _buildInfoRow('User ID', user.uid, theme),
                                const SizedBox(height: 8),
                                _buildInfoRow('Created', dateFormat.format(user.createdAt), theme),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Phone', user.phoneNumber.isEmpty ? 'Not provided' : user.phoneNumber, theme),
                                const SizedBox(height: 8),
                                _buildInfoRow('Status', user.isActive ? 'Active' : 'Inactive', theme),
                                const SizedBox(height: 8),
                                _buildInfoRow('Average Quote', 
                                  user.quotesCount > 0 
                                    ? currencyFormat.format(user.totalRevenue / user.quotesCount)
                                    : 'N/A', 
                                  theme
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildAnalyticsTab(
    List<UserInfo> users,
    ThemeData theme,
    NumberFormat currencyFormat,
    bool isMobile,
  ) {
    // Prepare data for charts
    final topPerformers = [...users]..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final topByQuotes = [...users]..sort((a, b) => b.quotesCount.compareTo(a.quotesCount));
    final topByClients = [...users]..sort((a, b) => b.clientsCount.compareTo(a.clientsCount));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Revenue Performers
          Text(
            'Top Revenue Performers',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildRevenueBarChart(topPerformers.take(10).toList(), theme),
          ),
          const SizedBox(height: 24),
          
          // Activity Distribution
          Text(
            'User Activity Distribution',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildActivityChart(users, theme),
          ),
          const SizedBox(height: 24),
          
          // Top Performers Lists
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTopPerformersList(
                  title: 'Top by Quotes',
                  users: topByQuotes.take(5).toList(),
                  metric: 'quotes',
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTopPerformersList(
                  title: 'Top by Clients',
                  users: topByClients.take(5).toList(),
                  metric: 'clients',
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
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
  
  Widget _buildUserMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.disabledColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTopPerformersList({
    required String title,
    required List<UserInfo> users,
    required String metric,
    required ThemeData theme,
  }) {
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
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...users.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final value = metric == 'quotes' ? user.quotesCount : user.clientsCount;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.displayName,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    value.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  // Chart building methods
  Widget _buildRolePieChart(Map<String, int> roleDistribution, ThemeData theme) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    
    final total = roleDistribution.values.fold(0, (sum, count) => sum + count);
    
    return PieChart(
      PieChartData(
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: roleDistribution.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final role = entry.value;
          final percentage = (role.value / total * 100);
          
          return PieChartSectionData(
            color: colors[index % colors.length],
            value: role.value.toDouble(),
            title: '${role.key}\n${percentage.toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildRevenueBarChart(List<UserInfo> users, ThemeData theme) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: users.first.totalRevenue * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final user = users[group.x.toInt()];
              return BarTooltipItem(
                '${user.displayName}\n\$${NumberFormat('#,###').format(rod.toY.toInt())}',
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
                if (value.toInt() >= 0 && value.toInt() < users.length) {
                  final name = users[value.toInt()].displayName;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        name.length > 10 ? '${name.substring(0, 10)}...' : name,
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
              reservedSize: 60,
              interval: users.first.totalRevenue / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value / 1000).toStringAsFixed(0)}K',
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
        barGroups: users.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: user.totalRevenue,
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
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
  
  Widget _buildActivityChart(List<UserInfo> users, ThemeData theme) {
    // Group users by last login time
    final now = DateTime.now();
    final activityData = {
      'Today': users.where((u) => now.difference(u.lastLoginAt).inDays == 0).length,
      '1-7 days': users.where((u) {
        final days = now.difference(u.lastLoginAt).inDays;
        return days > 0 && days <= 7;
      }).length,
      '8-30 days': users.where((u) {
        final days = now.difference(u.lastLoginAt).inDays;
        return days > 7 && days <= 30;
      }).length,
      '30+ days': users.where((u) => now.difference(u.lastLoginAt).inDays > 30).length,
    };
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: activityData.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = activityData.keys.elementAt(group.x.toInt());
              return BarTooltipItem(
                '$label\n${rod.toY.toInt()} users',
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
                final labels = activityData.keys.toList();
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 12),
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
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
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
        barGroups: activityData.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final count = entry.value.value;
          
          Color barColor;
          if (index == 0) barColor = Colors.green;
          else if (index == 1) barColor = Colors.blue;
          else if (index == 2) barColor = Colors.orange;
          else barColor = Colors.red;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: barColor,
                width: 30,
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
  
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'sales':
        return Colors.blue;
      case 'distributor':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}