// lib/features/admin/presentation/widgets/comprehensive_data_populator.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import '../../../../core/services/hybrid_database_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/models/models.dart';

/// Comprehensive Mock Data Populator Widget
///
/// Creates realistic business data for registered users:
/// - Uses real registered users from Firebase Auth
/// - Assigns 20 clients per user from real client list
/// - Generates 100 quotes distributed among the 20 clients with varied volumes
/// - Provides undo functionality to remove generated data
class ComprehensiveDataPopulatorWidget extends ConsumerStatefulWidget {
  const ComprehensiveDataPopulatorWidget({super.key});

  @override
  ConsumerState<ComprehensiveDataPopulatorWidget> createState() =>
      _ComprehensiveDataPopulatorWidgetState();
}

class _ComprehensiveDataPopulatorWidgetState
    extends ConsumerState<ComprehensiveDataPopulatorWidget> {
  bool _isPopulating = false;
  bool _isUndoing = false;
  String _progressMessage = '';
  int _progressValue = 0;
  int _totalSteps = 0;

  // Track generated data for undo functionality
  final List<String> _generatedQuoteIds = [];
  final Map<String, List<String>> _generatedQuotesByUser = {};

  // Quote statuses - only the 3 requested statuses
  final List<String> _quoteStatuses = [
    'Draft',
    'Sent',
    'Closed',
  ];

  final Random _random = Random();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.dataset, color: Colors.blue),
        title: const Text(
          'Mock Data Population',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Generate quotes for registered users using real clients'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This will use registered users and real clients:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Assign 20 clients per user from existing client list'),
                const Text('• Generate 100 quotes distributed across 20 clients'),
                const Text('• Varied quote volumes per client'),
                const Text('• Mixed statuses (Draft, Sent, Closed)'),
                const SizedBox(height: 16),

                if (_isPopulating || _isUndoing) ...[
                  LinearProgressIndicator(
                    value: _totalSteps > 0 ? _progressValue / _totalSteps : 0,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progressMessage,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_progressValue / $_totalSteps completed',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _populateComprehensiveData,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Generate Mock Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generatedQuoteIds.isEmpty ? null : _undoMockData,
                          icon: const Icon(Icons.undo),
                          label: const Text('Undo Mock Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _generatedQuoteIds.isEmpty
                      ? 'No mock data to undo. Generate data first.'
                      : '${_generatedQuoteIds.length} mock quotes ready to undo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _generatedQuoteIds.isEmpty ? Colors.grey : Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _populateComprehensiveData() async {
    if (_isPopulating) return;

    // Confirm action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Mock Data'),
        content: const Text(
          'This will generate 100 quotes for registered users using real clients from the database. '
          'Each user will be assigned 20 clients. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isPopulating = true;
      _progressValue = 0;
      _progressMessage = 'Fetching registered users...';
      _generatedQuoteIds.clear();
      _generatedQuotesByUser.clear();
    });

    try {
      final dbService = ref.read(hybridDatabaseProvider);

      // Get all registered users from Firebase Auth
      final usersSnapshot = await dbService.getAllUsersOnce();
      final users = usersSnapshot.map((u) => UserProfile.fromJson(u)).toList();

      if (users.isEmpty) {
        throw Exception('No registered users found.');
      }

      // Get ALL existing clients from database
      final database = rtdb.FirebaseDatabase.instance;
      final clientsSnapshot = await database.ref('clients').get();

      if (!clientsSnapshot.exists) {
        throw Exception('No clients found in database. Please add clients first.');
      }

      // Flatten all clients from all users
      final allClients = <Map<String, dynamic>>[];
      final clientsData = Map<String, dynamic>.from(clientsSnapshot.value as Map);

      for (final userEntry in clientsData.entries) {
        if (userEntry.value is Map) {
          final userClients = Map<String, dynamic>.from(userEntry.value as Map);
          for (final clientEntry in userClients.entries) {
            if (clientEntry.value is Map) {
              final clientData = Map<String, dynamic>.from(clientEntry.value as Map);
              clientData['id'] = clientEntry.key;
              clientData['userId'] = userEntry.key;
              allClients.add(clientData);
            }
          }
        }
      }

      if (allClients.isEmpty) {
        throw Exception('No clients found. Please add clients first.');
      }

      // Get all products to use in quotes
      final productsData = await dbService.getAllProductsOnce();
      final products = productsData
          .map((p) => Product.fromMap(Map<String, dynamic>.from(p)))
          .toList();

      if (products.isEmpty) {
        throw Exception('No products found. Please add products first.');
      }

      // Total steps: 100 quotes
      _totalSteps = 100;

      setState(() {
        _progressMessage = 'Found ${users.length} users and ${allClients.length} clients. Generating quotes...';
      });

      // Process each user
      for (final user in users) {
        await _populateDataForUser(dbService, user, products, allClients);
      }

      setState(() {
        _isPopulating = false;
        _progressMessage = 'Complete!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${_generatedQuoteIds.length} quotes for ${users.length} users!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      AppLogger.info('Mock data population completed', data: {
        'users': users.length,
        'quotes_generated': _generatedQuoteIds.length,
        'clients_used': allClients.length,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to populate mock data', error: e, stackTrace: stackTrace);

      setState(() {
        _isPopulating = false;
        _progressMessage = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _populateDataForUser(
    HybridDatabaseService dbService,
    UserProfile user,
    List<Product> products,
    List<Map<String, dynamic>> allClients,
  ) async {
    setState(() {
      _progressMessage = 'Processing user: ${user.displayName ?? user.email}';
    });

    // Randomly assign 20 clients to this user (or all if less than 20 available)
    final numClientsToAssign = allClients.length < 20 ? allClients.length : 20;
    final assignedClients = List<Map<String, dynamic>>.from(allClients)..shuffle(_random);
    final userClients = assignedClients.take(numClientsToAssign).toList();

    // Generate quote distribution: varied volumes across 20 clients
    // Some clients get more quotes (high volume), others get fewer
    final quoteDistribution = _generateQuoteDistribution(userClients.length);

    int totalQuotesToGenerate = quoteDistribution.reduce((a, b) => a + b);

    // Limit total quotes to not exceed remaining progress
    if (_progressValue + totalQuotesToGenerate > _totalSteps) {
      totalQuotesToGenerate = _totalSteps - _progressValue;
    }

    int quotesGenerated = 0;
    for (int clientIndex = 0; clientIndex < userClients.length && quotesGenerated < totalQuotesToGenerate; clientIndex++) {
      final client = userClients[clientIndex];
      final quotesForThisClient = quoteDistribution[clientIndex];

      for (int i = 0; i < quotesForThisClient && quotesGenerated < totalQuotesToGenerate; i++) {
        try {
          final quoteId = await _createQuoteDirectly(user.uid, client, products);

          if (quoteId != null) {
            _generatedQuoteIds.add(quoteId);
            _generatedQuotesByUser.putIfAbsent(user.uid, () => []).add(quoteId);
          }

          quotesGenerated++;
          setState(() {
            _progressValue++;
            _progressMessage = 'Generated quote $quotesGenerated for ${user.displayName ?? user.email}';
          });
        } catch (e) {
          AppLogger.warning('Failed to create quote', error: e, data: {'userId': user.uid, 'clientId': client['id']});
        }

        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
  }

  // Generate quote distribution across clients with varied volumes
  List<int> _generateQuoteDistribution(int numClients) {
    // Total quotes to distribute: 100 / number of users (roughly)
    // But we'll distribute them unevenly across 20 clients
    final distribution = <int>[];

    // High volume clients (2-3 clients): 10-20 quotes each
    final highVolumeClients = _random.nextInt(2) + 2; // 2-3 clients
    for (int i = 0; i < highVolumeClients && i < numClients; i++) {
      distribution.add(_random.nextInt(11) + 10); // 10-20 quotes
    }

    // Medium volume clients (5-7 clients): 3-8 quotes each
    final mediumVolumeClients = _random.nextInt(3) + 5; // 5-7 clients
    for (int i = 0; i < mediumVolumeClients && distribution.length < numClients; i++) {
      distribution.add(_random.nextInt(6) + 3); // 3-8 quotes
    }

    // Low volume clients (remaining): 1-3 quotes each
    while (distribution.length < numClients) {
      distribution.add(_random.nextInt(3) + 1); // 1-3 quotes
    }

    distribution.shuffle(_random);
    return distribution;
  }

  Future<String?> _createQuoteDirectly(
    String userId,
    Map<String, dynamic> client,
    List<Product> products,
  ) async {
    if (products.isEmpty) return null;

    final status = _getRandomQuoteStatus();

    // Create quote date in the past 12 months
    final daysAgo = _random.nextInt(365);
    final createdAt = DateTime.now().subtract(Duration(days: daysAgo));

    // Select 1-8 products
    final numProducts = 1 + _random.nextInt(8);
    final selectedProducts = <Product>[];
    for (int i = 0; i < numProducts; i++) {
      selectedProducts.add(products[_random.nextInt(products.length)]);
    }

    // Create quote items
    final items = <Map<String, dynamic>>[];
    double subtotal = 0;

    for (final product in selectedProducts) {
      final quantity = 1 + _random.nextInt(20);
      final unitPrice = product.price;
      final total = unitPrice * quantity;

      items.add({
        'productId': product.id ?? '',
        'productName': product.displayName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
        'addedAt': createdAt.toIso8601String(),
        'discount': 0,
      });

      subtotal += total;
    }

    // Random discount (0-15%)
    final discountPercentage = _random.nextDouble() * 15;
    final discountAmount = subtotal * (discountPercentage / 100);

    // Tax (16%)
    final taxableAmount = subtotal - discountAmount;
    final tax = taxableAmount * 0.16;

    final total = subtotal - discountAmount + tax;

    final quoteData = {
      'quoteNumber': 'Q-${DateTime.now().year}-${_random.nextInt(99999).toString().padLeft(5, '0')}',
      'clientId': client['id'] as String,
      'clientName': client['company'] as String? ?? client['name'] as String? ?? 'Unknown',
      'items': items,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'discountType': 'percentage',
      'discountValue': discountPercentage,
      'tax': tax,
      'total': total,
      'totalAmount': total,
      'status': status,
      'archived': false,
      'notes': '[MOCK] Quote created with ${items.length} items - Total: \$${total.toStringAsFixed(2)}',
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': createdAt.add(const Duration(days: 30)).toIso8601String(),
      'createdBy': userId,
      'isMockData': true, // Flag to identify mock data for undo
    };

    // Write directly to Firebase Realtime Database
    final database = rtdb.FirebaseDatabase.instance;
    final newQuoteRef = database.ref('quotes/$userId').push();
    await newQuoteRef.set(quoteData);
    return newQuoteRef.key; // Return quote ID for tracking
  }

  String _getRandomQuoteStatus() {
    // Simply return one of the 3 allowed statuses randomly
    return _quoteStatuses[_random.nextInt(_quoteStatuses.length)];
  }

  Future<void> _undoMockData() async {
    if (_isUndoing || _generatedQuoteIds.isEmpty) return;

    // Confirm action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Mock Data'),
        content: Text(
          'This will delete ${_generatedQuoteIds.length} mock quotes that were generated. '
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Delete Mock Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUndoing = true;
      _progressValue = 0;
      _totalSteps = _generatedQuoteIds.length;
      _progressMessage = 'Deleting mock quotes...';
    });

    try {
      final database = rtdb.FirebaseDatabase.instance;
      int deletedCount = 0;

      // Delete quotes by user
      for (final entry in _generatedQuotesByUser.entries) {
        final userId = entry.key;
        final quoteIds = entry.value;

        for (final quoteId in quoteIds) {
          try {
            await database.ref('quotes/$userId/$quoteId').remove();
            deletedCount++;

            setState(() {
              _progressValue++;
              _progressMessage = 'Deleted $deletedCount/${_generatedQuoteIds.length} mock quotes...';
            });
          } catch (e) {
            AppLogger.warning('Failed to delete quote', error: e, data: {'userId': userId, 'quoteId': quoteId});
          }

          await Future.delayed(const Duration(milliseconds: 30));
        }
      }

      setState(() {
        _isUndoing = false;
        _progressMessage = 'Cleanup complete!';
        _generatedQuoteIds.clear();
        _generatedQuotesByUser.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $deletedCount mock quotes!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      AppLogger.info('Mock data cleanup completed', data: {
        'quotes_deleted': deletedCount,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to undo mock data', error: e, stackTrace: stackTrace);

      setState(() {
        _isUndoing = false;
        _progressMessage = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

// Provider for hybrid database service
final hybridDatabaseProvider = Provider<HybridDatabaseService>((ref) {
  return HybridDatabaseService();
});
