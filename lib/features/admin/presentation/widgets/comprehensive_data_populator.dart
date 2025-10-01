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
/// Creates realistic business data for all existing users:
/// - 20 quotes per user (Draft, Sent, Closed statuses)
/// - 10-15 clients per user
/// - Realistic product distributions
/// - Geographic diversity
/// - Financial diversity ($1K-$50K quotes)
class ComprehensiveDataPopulatorWidget extends ConsumerStatefulWidget {
  const ComprehensiveDataPopulatorWidget({super.key});

  @override
  ConsumerState<ComprehensiveDataPopulatorWidget> createState() =>
      _ComprehensiveDataPopulatorWidgetState();
}

class _ComprehensiveDataPopulatorWidgetState
    extends ConsumerState<ComprehensiveDataPopulatorWidget> {
  bool _isPopulating = false;
  String _progressMessage = '';
  int _progressValue = 0;
  int _totalSteps = 0;

  // Business type templates
  final List<Map<String, dynamic>> _businessTypes = [
    {
      'type': 'Restaurant',
      'contactTitles': ['Head Chef', 'Owner', 'Manager', 'Kitchen Manager'],
      'productFocus': ['Refrigeration', 'Freezers', 'Prep Tables', 'Ice Machines'],
    },
    {
      'type': 'Hotel',
      'contactTitles': ['Facilities Manager', 'GM', 'Operations Director', 'F&B Director'],
      'productFocus': ['Refrigeration', 'Ice Machines', 'Display Cases', 'Walk-ins'],
    },
    {
      'type': 'Catering',
      'contactTitles': ['Owner', 'Operations Manager', 'Purchasing Manager'],
      'productFocus': ['Transport Refrigeration', 'Prep Tables', 'Freezers', 'Ice Machines'],
    },
    {
      'type': 'Hospital',
      'contactTitles': ['Facilities Director', 'Purchasing', 'Operations Manager'],
      'productFocus': ['Medical Refrigeration', 'Freezers', 'Ice Machines'],
    },
    {
      'type': 'School',
      'contactTitles': ['Cafeteria Manager', 'Facilities', 'Purchasing'],
      'productFocus': ['Refrigeration', 'Freezers', 'Display Cases', 'Ice Machines'],
    },
    {
      'type': 'Supermarket',
      'contactTitles': ['Store Manager', 'Owner', 'Operations Manager'],
      'productFocus': ['Display Cases', 'Walk-ins', 'Freezers', 'Refrigeration'],
    },
    {
      'type': 'Bar',
      'contactTitles': ['Owner', 'Manager', 'GM'],
      'productFocus': ['Ice Machines', 'Refrigeration', 'Display Cases'],
    },
    {
      'type': 'Casino',
      'contactTitles': ['F&B Director', 'Facilities Manager', 'Purchasing'],
      'productFocus': ['Ice Machines', 'Refrigeration', 'Display Cases', 'Walk-ins'],
    },
  ];

  // Geographic locations
  final List<Map<String, String>> _locations = [
    {'city': 'Cancún', 'state': 'Quintana Roo', 'country': 'Mexico'},
    {'city': 'Playa del Carmen', 'state': 'Quintana Roo', 'country': 'Mexico'},
    {'city': 'Tulum', 'state': 'Quintana Roo', 'country': 'Mexico'},
    {'city': 'Mexico City', 'state': 'CDMX', 'country': 'Mexico'},
    {'city': 'Guadalajara', 'state': 'Jalisco', 'country': 'Mexico'},
    {'city': 'Monterrey', 'state': 'Nuevo León', 'country': 'Mexico'},
    {'city': 'Puebla', 'state': 'Puebla', 'country': 'Mexico'},
    {'city': 'Mérida', 'state': 'Yucatán', 'country': 'Mexico'},
    {'city': 'Los Cabos', 'state': 'Baja California Sur', 'country': 'Mexico'},
    {'city': 'Puerto Vallarta', 'state': 'Jalisco', 'country': 'Mexico'},
  ];

  // First and last names for contacts
  final List<String> _firstNames = [
    'Carlos', 'Maria', 'José', 'Ana', 'Miguel', 'Sofia', 'Luis', 'Carmen',
    'Diego', 'Laura', 'Fernando', 'Patricia', 'Alejandro', 'Isabel', 'Roberto',
    'Elena', 'Ricardo', 'Gabriela', 'Eduardo', 'Monica', 'Jorge', 'Daniela',
  ];

  final List<String> _lastNames = [
    'García', 'Rodríguez', 'Martínez', 'López', 'González', 'Hernández',
    'Pérez', 'Sánchez', 'Ramírez', 'Torres', 'Flores', 'Rivera', 'Gómez',
    'Díaz', 'Morales', 'Jiménez', 'Álvarez', 'Romero', 'Mendoza', 'Vargas',
  ];

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
          'Comprehensive Mock Data Population',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Generate realistic business data for all users'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This will create for each existing user:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• 20 quotes with varied statuses and dates'),
                const Text('• 10-15 diverse clients'),
                const Text('• Realistic business scenarios'),
                const Text('• Geographic and financial diversity'),
                const SizedBox(height: 16),

                if (_isPopulating) ...[
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
                  ElevatedButton.icon(
                    onPressed: _populateComprehensiveData,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Populate Comprehensive Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Note: This operation may take several minutes to complete.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
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
        title: const Text('Populate Comprehensive Data'),
        content: const Text(
          'This will create extensive mock data for all existing users. '
          'This operation cannot be easily undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Populate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isPopulating = true;
      _progressValue = 0;
      _progressMessage = 'Fetching existing users...';
    });

    try {
      final dbService = ref.read(hybridDatabaseProvider);

      // Get all existing users
      final usersSnapshot = await dbService.getAllUsersOnce();
      final users = usersSnapshot.map((u) => UserProfile.fromJson(u)).toList();

      if (users.isEmpty) {
        throw Exception('No users found. Please create users first.');
      }

      // Get all products to use in quotes
      final productsData = await dbService.getAllProductsOnce();
      final products = productsData
          .map((p) => Product.fromMap(Map<String, dynamic>.from(p)))
          .toList();

      if (products.isEmpty) {
        throw Exception('No products found. Please add products first.');
      }

      // Calculate total steps
      _totalSteps = users.length * (15 + 20); // avg clients + quotes per user

      setState(() {
        _progressMessage = 'Found ${users.length} users. Starting population...';
      });

      // Process each user
      for (final user in users) {
        await _populateDataForUser(dbService, user, products);
      }

      setState(() {
        _isPopulating = false;
        _progressMessage = 'Complete!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully populated data for ${users.length} users!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      AppLogger.info('Comprehensive mock data population completed', data: {
        'users': users.length,
        'estimated_clients': users.length * 12,
        'estimated_quotes': users.length * 20,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to populate comprehensive data', error: e, stackTrace: stackTrace);

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
  ) async {
    setState(() {
      _progressMessage = 'Processing user: ${user.displayName ?? user.email}';
    });

    // Temporarily authenticate as this user to create their data
    // Note: This requires admin privileges

    // Generate 10-15 clients
    final numClients = 10 + _random.nextInt(6);
    final clients = <Map<String, dynamic>>[];

    for (int i = 0; i < numClients; i++) {
      try {
        final client = await _createClientDirectly(user.uid);
        clients.add(client);

        setState(() {
          _progressValue++;
          _progressMessage = 'Created client ${i + 1}/$numClients for ${user.displayName ?? user.email}';
        });
      } catch (e) {
        AppLogger.warning('Failed to create client', error: e, data: {'userId': user.uid, 'clientIndex': i});
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 50));
    }


    // Generate 20 quotes with varied statuses and dates
    for (int i = 0; i < 20; i++) {
      try {
        await _createQuoteDirectly(user.uid, clients, products);

        setState(() {
          _progressValue++;
          _progressMessage = 'Created quote ${i + 1}/20 for ${user.displayName ?? user.email}';
        });
      } catch (e) {
        AppLogger.warning('Failed to create quote', error: e, data: {'userId': user.uid, 'quoteIndex': i});
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<Map<String, dynamic>> _createClientDirectly(String userId) async {
    final businessType = _businessTypes[_random.nextInt(_businessTypes.length)];
    final location = _locations[_random.nextInt(_locations.length)];
    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final contactTitle = (businessType['contactTitles'] as List)[_random.nextInt((businessType['contactTitles'] as List).length)];

    final companyName = '${businessType['type']} ${_generateCompanyName()}';
    final contactName = '$firstName $lastName';
    final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@${companyName.toLowerCase().replaceAll(' ', '')}.com';
    final phone = _generatePhoneNumber();

    final client = {
      'company': companyName,
      'contactName': contactName,
      'name': contactName,
      'email': email,
      'phone': phone,
      'address': '${_random.nextInt(9999) + 100} ${_generateStreetName()}',
      'city': location['city'],
      'state': location['state'],
      'zipCode': '${_random.nextInt(90000) + 10000}',
      'country': location['country'],
      'notes': '$contactTitle at $companyName - Interested in ${(businessType['productFocus'] as List).join(', ')}',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    // Write directly to Firebase Realtime Database
    final database = rtdb.FirebaseDatabase.instance;
    final newClientRef = database.ref('clients/$userId').push();
    await newClientRef.set(client);
    client['id'] = newClientRef.key!;
    return client;
  }


  Future<void> _createQuoteDirectly(
    String userId,
    List<Map<String, dynamic>> clients,
    List<Product> products,
  ) async {
    if (clients.isEmpty || products.isEmpty) return;

    final client = clients[_random.nextInt(clients.length)];
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
      'clientName': client['company'] as String,
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
      'notes': 'Quote created with ${items.length} items - Total: \$${total.toStringAsFixed(2)}',
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': createdAt.add(const Duration(days: 30)).toIso8601String(),
      'createdBy': userId,
    };

    // Write directly to Firebase Realtime Database
    final database = rtdb.FirebaseDatabase.instance;
    final newQuoteRef = database.ref('quotes/$userId').push();
    await newQuoteRef.set(quoteData);
  }

  String _getRandomQuoteStatus() {
    // Simply return one of the 3 allowed statuses randomly
    return _quoteStatuses[_random.nextInt(_quoteStatuses.length)];
  }

  String _generateCompanyName() {
    final prefixes = ['La', 'El', 'Las', 'Los', 'Grand', 'Royal', 'Premium', 'Elite'];
    final suffixes = ['Palace', 'Plaza', 'Resort', 'Garden', 'Paradise', 'Bay', 'Coast', 'Beach'];

    return '${prefixes[_random.nextInt(prefixes.length)]} ${suffixes[_random.nextInt(suffixes.length)]}';
  }

  String _generateStreetName() {
    final streets = [
      'Av. Kukulkán', 'Av. Tulum', 'Av. Bonampak', 'Calle Constituyentes',
      'Av. Nichupté', 'Blvd. Luis Donaldo Colosio', 'Av. Cobá', 'Av. Yaxchilán',
    ];
    return streets[_random.nextInt(streets.length)];
  }

  String _generatePhoneNumber() {
    return '+52-${_random.nextInt(900) + 100}-${_random.nextInt(900) + 100}-${_random.nextInt(9000) + 1000}';
  }
}

// Provider for hybrid database service
final hybridDatabaseProvider = Provider<HybridDatabaseService>((ref) {
  return HybridDatabaseService();
});
