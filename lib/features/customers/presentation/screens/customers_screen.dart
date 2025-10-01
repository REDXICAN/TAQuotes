// lib/features/customers/presentation/screens/customers_screen.dart
import 'package:flutter/material.dart';
import '../../../clients/presentation/screens/clients_screen.dart';
import '../../../projects/presentation/screens/projects_screen.dart';

/// Customers Screen with Tabs - Groups Clients and Projects
///
/// This screen implements Architecture A's "Customers" navigation item,
/// consolidating client management and project tracking under one section.
///
/// NN/g Compliance:
/// - Guideline #8: Groups related items logically (all customer relationship management)
/// - Guideline #6: Provides local navigation (tabs for sub-sections)
/// - Guideline #5: Indicates current location (selected tab)
/// - Guideline #7: Clear labels ("Clients" and "Projects")
/// - Guideline #16: Familiar tabbed pattern
class CustomersScreen extends StatefulWidget {
  /// Optional initial tab index (0=Clients, 1=Projects)
  final int initialTabIndex;

  const CustomersScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 2 tabs (Clients, Projects)
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
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
        title: const Text('Customers'),
        // Tab bar for sub-navigation between Clients and Projects
        // NN/g Guideline #6: Local navigation for related sections
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.people_outline),
              text: 'Clients',
            ),
            Tab(
              icon: Icon(Icons.folder_outlined),
              text: 'Projects',
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
          // Clients Tab - Customer database and management
          ClientsScreen(),

          // Projects Tab - Client project tracking
          ProjectsScreen(),
        ],
      ),
    );
  }
}
