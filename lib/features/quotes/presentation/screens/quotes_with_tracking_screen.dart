// lib/features/quotes/presentation/screens/quotes_with_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quotes_screen.dart';
import '../widgets/tracking_tab_widget.dart';

/// Main quotes screen with tabs for Quotes and Tracking
class QuotesWithTrackingScreen extends ConsumerStatefulWidget {
  const QuotesWithTrackingScreen({super.key});

  @override
  ConsumerState<QuotesWithTrackingScreen> createState() => _QuotesWithTrackingScreenState();
}

class _QuotesWithTrackingScreenState extends ConsumerState<QuotesWithTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotes & Tracking'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primaryColor,
          labelColor: theme.primaryColor,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          tabs: const [
            Tab(
              icon: Icon(Icons.receipt_long),
              text: 'Quotes',
            ),
            Tab(
              icon: Icon(Icons.local_shipping),
              text: 'Tracking',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Quotes tab - using existing quotes screen content
          _QuotesTabContent(),
          // Tracking tab - new shipment tracking
          TrackingTabWidget(),
        ],
      ),
    );
  }
}

/// Quotes tab content extracted from QuotesScreen
class _QuotesTabContent extends ConsumerStatefulWidget {
  const _QuotesTabContent();

  @override
  ConsumerState<_QuotesTabContent> createState() => _QuotesTabContentState();
}

class _QuotesTabContentState extends ConsumerState<_QuotesTabContent> {
  @override
  Widget build(BuildContext context) {
    // Use the existing QuotesScreen widget but without AppBar
    // since it's now in a tab
    return const QuotesScreenContent();
  }
}

/// Content-only version of QuotesScreen for use in tabs
/// This should be created by extracting the body from QuotesScreen
class QuotesScreenContent extends ConsumerWidget {
  const QuotesScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, just use the full QuotesScreen
    // In production, you would extract just the body content
    return const QuotesScreen();
  }
}
