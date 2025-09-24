// lib/features/clients/presentation/screens/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../cart/presentation/screens/cart_screen.dart'; // For cartClientProvider

// Clients provider using StreamProvider for real-time updates
final clientsProvider = StreamProvider<List<Client>>((ref) {
  // Use currentUserProvider instead of authStateProvider to avoid loading states
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    // Not logged in
    return Stream.value([]);
  }

  try {
    final database = FirebaseDatabase.instance;

    // Return a stream that listens to clients changes
    return database.ref('clients/${user.uid}').onValue.map((event) {
      final List<Client> clients = [];

      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        data.forEach((key, value) {
          final clientMap = Map<String, dynamic>.from(value);
          clientMap['id'] = key;
          try {
            clients.add(Client.fromMap(clientMap));
          } catch (e) {
            AppLogger.error('Error parsing client $key', error: e);
          }
        });
      }

      // Sort by company name
      clients.sort((a, b) => a.company.compareTo(b.company));
      return clients;
    }).handleError((error) {
      AppLogger.error('Error in clients stream', error: error);
      return <Client>[];
    });
  } catch (e) {
    AppLogger.error('Error setting up clients stream', error: e);
    return Stream.value([]);
  }
});

// Selected client provider
final selectedClientProvider = StateProvider<Client?>((ref) => null);

// Provider to fetch quotes for a specific client
final clientQuotesProvider = FutureProvider.family<List<Quote>, String>((ref, clientId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }
  
  try {
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('quotes/${user.uid}').get();
    
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final List<Quote> quotes = [];
    
    data.forEach((key, value) {
      try {
        final quoteMap = Map<String, dynamic>.from(value);
        quoteMap['id'] = key;
        final quote = Quote.fromMap(quoteMap);
        
        // Filter quotes for this specific client
        if (quote.clientId == clientId) {
          quotes.add(quote);
        }
      } catch (e) {
        AppLogger.error('Error parsing quote $key', error: e);
      }
    });
    
    // Sort by created date (most recent first)
    quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quotes;
  } catch (e) {
    AppLogger.error('Error loading client quotes', error: e);
    return [];
  }
});

// Provider to fetch projects for a specific client
final clientProjectsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  try {
    final user = ref.read(currentUserProvider);
    if (user == null) return [];
    
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('projects/${user.uid}').orderByChild('clientId').equalTo(clientId).get();
    
    if (!snapshot.exists || snapshot.value == null) return [];
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final projects = <Map<String, dynamic>>[];
    
    data.forEach((key, value) {
      try {
        final projectMap = Map<String, dynamic>.from(value);
        projectMap['id'] = key;
        projects.add(projectMap);
      } catch (e) {
        AppLogger.error('Error parsing project $key', error: e);
      }
    });
    
    // Sort by created date (most recent first)
    projects.sort((a, b) {
      final aDate = a['createdAt'] ?? 0;
      final bDate = b['createdAt'] ?? 0;
      return bDate.compareTo(aDate);
    });
    
    return projects;
  } catch (e) {
    AppLogger.error('Error loading client projects', error: e);
    return [];
  }
});

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _showAddForm = false;
  String? _editingClientId;
  String _searchQuery = '';
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // No need to invalidate on init - let the provider handle its own lifecycle
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _companyController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final clientsAsync = ref.watch(clientsProvider);
    final selectedClient = ref.watch(selectedClientProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Clients',
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.download,
              size: ResponsiveHelper.getIconSize(context),
            ),
            onSelected: (value) async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              
              switch (value) {
                case 'xlsx':
                  await _exportClientsToXLSX(user.uid);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'xlsx',
                child: ListTile(
                  leading: Icon(
                    Icons.table_chart,
                    size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                  ),
                  title: Text(
                    'Export as Excel',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        baseFontSize: 14,
                        minFontSize: 12,
                        maxFontSize: 16,
                      ),
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              _showAddForm ? Icons.close : Icons.add,
              size: ResponsiveHelper.getIconSize(context),
            ),
            onPressed: () {
              setState(() {
                _showAddForm = !_showAddForm;
                if (!_showAddForm) {
                  _clearForm();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected Client Display
          if (selectedClient != null)
            Container(
              padding: EdgeInsets.all(
                ResponsiveHelper.getSpacing(context, medium: 12),
              ),
              color: Colors.green.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: ResponsiveHelper.getIconSize(context, baseSize: 20),
                  ),
                  SizedBox(
                    width: ResponsiveHelper.getSpacing(context, medium: 8),
                  ),
                  Expanded(
                    child: Text(
                      'Selected: ${selectedClient.company}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          baseFontSize: 14,
                          minFontSize: 12,
                          maxFontSize: 16,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(selectedClientProvider.notifier).state = null;
                    },
                    child: Text('Clear', style: TextStyle(color: Colors.green[700])),
                  ),
                ],
              ),
            ),
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.cardColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by company, contact, email, or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Add Client Form
          if (_showAddForm)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingClientId != null ? 'Edit Client' : 'Add New Client',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _companyController,
                        decoration: const InputDecoration(
                          labelText: 'Company Name *',
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactNameController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                          hintText: 'Numbers only',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _zipCodeController,
                              decoration: const InputDecoration(
                                labelText: 'ZIP',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAddForm = false;
                                _clearForm();
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _saveClient,
                            icon: const Icon(Icons.save),
                            label: Text(_editingClientId != null ? 'Update Client' : 'Save Client'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Clients List
          Expanded(
            child: clientsAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              data: (clients) {
                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No clients yet',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first client to get started',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _showAddForm = true);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Client'),
                        ),
                      ],
                    ),
                  );
                }

                // Filter clients based on search query
                final filteredClients = _searchQuery.isEmpty
                    ? clients
                    : clients.where((client) {
                        final companyLower = client.company.toLowerCase();
                        final contactLower = (client.contactName ?? '').toLowerCase();
                        final emailLower = (client.email ?? '').toLowerCase();
                        final phoneLower = (client.phone ?? '').toLowerCase();
                        
                        return companyLower.contains(_searchQuery) ||
                               contactLower.contains(_searchQuery) ||
                               emailLower.contains(_searchQuery) ||
                               phoneLower.contains(_searchQuery);
                      }).toList();

                if (filteredClients.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No clients found',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search terms',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredClients.length,
                  itemBuilder: (context, index) {
                    final client = filteredClients[index];
                    final isSelected = selectedClient?.id == client.id;

                    return Card(
                      elevation: isSelected ? 4 : 1,
                      color: isSelected
                          ? theme.primaryColor.withOpacity(0.1)
                          : null,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: GestureDetector(
                          onTap: () => _showProfilePictureOptions(client),
                          child: CircleAvatar(
                            backgroundColor: isSelected
                                ? theme.primaryColor
                                : theme.disabledColor.withOpacity(0.3),
                            backgroundImage: client.profilePictureUrl != null
                                ? NetworkImage(client.profilePictureUrl!)
                                : null,
                            child: client.profilePictureUrl == null
                                ? Icon(
                                    Icons.business,
                                    color: isSelected
                                        ? Colors.white
                                        : theme.textTheme.bodyLarge?.color,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                client.company,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                            // Show incomplete info tag if email or phone is missing
                            if (client.email.isEmpty || client.phone.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                ),
                                child: Text(
                                  'Incomplete',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          client.contactName.isNotEmpty 
                              ? client.contactName 
                              : 'No contact name',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Check if we're in selection mode (came from cart)
                            if (ModalRoute.of(context)?.settings.arguments == 'select')
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context, client);
                                },
                                child: const Text('Select'),
                              )
                            else
                              // Selection toggle switch
                              Switch(
                                value: isSelected,
                                onChanged: (bool value) {
                                  if (value) {
                                    // Select this client (only one can be selected)
                                    ref
                                        .read(selectedClientProvider.notifier)
                                        .state = client;
                                    // Also sync with cart screen
                                    ref
                                        .read(cartClientProvider.notifier)
                                        .state = client;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Selected: ${client.company}'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  } else {
                                    // Deselect
                                    ref
                                        .read(selectedClientProvider.notifier)
                                        .state = null;
                                    // Also sync with cart screen
                                    ref
                                        .read(cartClientProvider.notifier)
                                        .state = null;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Deselected: ${client.company}'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                activeColor: Colors.green,
                                activeTrackColor: Colors.green.withOpacity(0.5),
                              ),
                          ],
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Contact Information
                                if (client.email.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.email, size: 16, color: theme.disabledColor),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(client.email)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (client.phone.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 16, color: theme.disabledColor),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(client.phone)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                // Address
                                if (client.address != null && client.address!.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 16, color: theme.disabledColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${client.address}${client.city != null ? ', ${client.city}' : ''}${client.state != null ? ', ${client.state}' : ''}${client.zipCode != null ? ' ${client.zipCode}' : ''}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                // Notes
                                if (client.notes != null && client.notes!.isNotEmpty) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.note, size: 16, color: theme.disabledColor),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(client.notes!)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                // Action Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _editClient(client),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Edit'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _deleteClient(client),
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Order History and Projects Tabs
                                if (client.id != null) ...[
                                  const Divider(height: 32),
                                  // Tab Bar
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.dividerColor),
                                    ),
                                    child: TabBar(
                                      controller: _tabController,
                                      indicatorColor: theme.primaryColor,
                                      labelColor: theme.primaryColor,
                                      unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                                      tabs: const [
                                        Tab(text: 'Order History'),
                                        Tab(text: 'Projects'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Tab Views
                                  SizedBox(
                                    height: 400, // Fixed height for tab view
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        // Order History Tab
                                        Consumer(
                                          builder: (context, ref, child) {
                                            final quotesAsync = ref.watch(clientQuotesProvider(client.id!));
                                            
                                            return quotesAsync.when(
                                              data: (quotes) {
                                          if (quotes.isEmpty) {
                                            return Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: theme.disabledColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'No quotes yet',
                                                  style: TextStyle(
                                                    color: theme.disabledColor,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          
                                          return Column(
                                            children: quotes.map((quote) {
                                              final dateFormat = DateFormat('MMM dd, yyyy');
                                              final currencyFormat = NumberFormat.currency(symbol: '\$');
                                              
                                              return Card(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                child: Theme(
                                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                  child: ExpansionTile(
                                                    initiallyExpanded: false,
                                                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                    childrenPadding: const EdgeInsets.all(12),
                                                    leading: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: theme.primaryColor.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.receipt_long,
                                                        color: theme.primaryColor,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    title: Row(
                                                      children: [
                                                        Text(
                                                          'Quote #${quote.quoteNumber ?? quote.id?.substring(0, 8) ?? 'N/A'}',
                                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: _getStatusColor(quote.status).withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            quote.status ?? 'Pending',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: _getStatusColor(quote.status),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    subtitle: Text(
                                                      '${dateFormat.format(quote.createdAt)} • ${currencyFormat.format(quote.totalAmount)}',
                                                      style: theme.textTheme.bodySmall,
                                                    ),
                                                    children: [
                                                      // Quote Details
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          // Items Summary
                                                          Row(
                                                            children: [
                                                              Icon(Icons.inventory_2, size: 14, color: theme.disabledColor),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '${quote.items.length} item${quote.items.length != 1 ? 's' : ''}',
                                                                style: theme.textTheme.bodySmall,
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 8),
                                                          
                                                          // Financial Summary
                                                          Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration: BoxDecoration(
                                                              color: theme.cardColor,
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: theme.dividerColor),
                                                            ),
                                                            child: Column(
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    const Text('Subtotal:'),
                                                                    Text(currencyFormat.format(quote.subtotal)),
                                                                  ],
                                                                ),
                                                                if (quote.discountAmount > 0) ...[
                                                                  const SizedBox(height: 4),
                                                                  Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: [
                                                                      const Text('Discount:'),
                                                                      Text(
                                                                        '-${currencyFormat.format(quote.discountAmount)}',
                                                                        style: TextStyle(color: Colors.green[700]),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                                const SizedBox(height: 4),
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    const Text('Tax:'),
                                                                    Text(currencyFormat.format(quote.tax)),
                                                                  ],
                                                                ),
                                                                const Divider(height: 12),
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    const Text(
                                                                      'Total:',
                                                                      style: TextStyle(fontWeight: FontWeight.bold),
                                                                    ),
                                                                    Text(
                                                                      currencyFormat.format(quote.totalAmount),
                                                                      style: TextStyle(
                                                                        fontWeight: FontWeight.bold,
                                                                        color: theme.primaryColor,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          
                                                          // Comments if any
                                                          if (quote.comments != null && quote.comments!.isNotEmpty) ...[
                                                            const SizedBox(height: 12),
                                                            Row(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Icon(Icons.comment, size: 14, color: theme.disabledColor),
                                                                const SizedBox(width: 4),
                                                                Expanded(
                                                                  child: Text(
                                                                    quote.comments!,
                                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                                      fontStyle: FontStyle.italic,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                          
                                                          // View in Quotes Button
                                                          const SizedBox(height: 12),
                                                          SizedBox(
                                                            width: double.infinity,
                                                            child: ElevatedButton.icon(
                                                              onPressed: () {
                                                                // Navigate to quotes section with this quote opened
                                                                context.push('/quotes/${quote.id}');
                                                              },
                                                              icon: const Icon(Icons.open_in_new, size: 18),
                                                              label: const Text('View Full Quote'),
                                                              style: ElevatedButton.styleFrom(
                                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                              loading: () => const Center(
                                                child: Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: CircularProgressIndicator(),
                                                ),
                                              ),
                                              error: (error, stack) => Text(
                                                'Error loading quotes: $error',
                                                style: TextStyle(color: theme.colorScheme.error),
                                              ),
                                            );
                                          },
                                        ),
                                    // Projects Tab
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final projectsAsync = ref.watch(clientProjectsProvider(client.id!));
                                        
                                        return projectsAsync.when(
                                          data: (projects) {
                                            if (projects.isEmpty) {
                                              return Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: theme.disabledColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.folder_outlined,
                                                        size: 48,
                                                        color: theme.disabledColor,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'No projects yet',
                                                        style: TextStyle(
                                                          color: theme.disabledColor,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Projects will appear when quotes are created',
                                                        style: TextStyle(
                                                          color: theme.disabledColor.withOpacity(0.7),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                            
                                            return ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: projects.length,
                                              itemBuilder: (context, index) {
                                                final project = projects[index];
                                                final dateFormat = DateFormat('MMM dd, yyyy');
                                                final createdAt = project['createdAt'] != null
                                                    ? DateTime.fromMillisecondsSinceEpoch(project['createdAt'])
                                                    : DateTime.now();
                                                
                                                return Card(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  child: Theme(
                                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                    child: ExpansionTile(
                                                      initiallyExpanded: false,
                                                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                      childrenPadding: const EdgeInsets.all(12),
                                                      leading: Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: _getProjectStatusColor(project['status']).withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Icon(
                                                          Icons.folder,
                                                          color: _getProjectStatusColor(project['status']),
                                                          size: 20,
                                                        ),
                                                      ),
                                                      title: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              project['name'] ?? 'Unnamed Project',
                                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: _getProjectStatusColor(project['status']).withOpacity(0.2),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              project['status'] ?? 'active',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: _getProjectStatusColor(project['status']),
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      subtitle: Text(
                                                        'Created ${dateFormat.format(createdAt)}',
                                                        style: theme.textTheme.bodySmall,
                                                      ),
                                                      children: [
                                                        // Project Details
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            if (project['description'] != null && project['description'].toString().isNotEmpty) ...[
                                                              Row(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Icon(Icons.description, size: 14, color: theme.disabledColor),
                                                                  const SizedBox(width: 4),
                                                                  Expanded(
                                                                    child: Text(
                                                                      project['description'],
                                                                      style: theme.textTheme.bodySmall,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 12),
                                                            ],
                                                            
                                                            // Load project quotes
                                                            FutureBuilder<List<Quote>>(
                                                              future: _loadProjectQuotes(project['id']),
                                                              builder: (context, snapshot) {
                                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                                  return const Center(
                                                                    child: Padding(
                                                                      padding: EdgeInsets.all(8.0),
                                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                                    ),
                                                                  );
                                                                }
                                                                
                                                                final projectQuotes = snapshot.data ?? [];
                                                                
                                                                if (projectQuotes.isEmpty) {
                                                                  return Container(
                                                                    padding: const EdgeInsets.all(12),
                                                                    decoration: BoxDecoration(
                                                                      color: theme.disabledColor.withOpacity(0.05),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(Icons.info_outline, size: 14, color: theme.disabledColor),
                                                                        const SizedBox(width: 8),
                                                                        Text(
                                                                          'No quotes in this project yet',
                                                                          style: TextStyle(
                                                                            color: theme.disabledColor,
                                                                            fontSize: 12,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );
                                                                }
                                                                
                                                                return Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        Icon(Icons.receipt_long, size: 14, color: theme.disabledColor),
                                                                        const SizedBox(width: 4),
                                                                        Text(
                                                                          '${projectQuotes.length} quote${projectQuotes.length != 1 ? 's' : ''}',
                                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                                            fontWeight: FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(height: 8),
                                                                    ...projectQuotes.map((quote) {
                                                                      final currencyFormat = NumberFormat.currency(symbol: '\$');
                                                                      return InkWell(
                                                                        onTap: () {
                                                                          context.push('/quotes/${quote.id}');
                                                                        },
                                                                        child: Container(
                                                                          padding: const EdgeInsets.all(8),
                                                                          margin: const EdgeInsets.only(bottom: 4),
                                                                          decoration: BoxDecoration(
                                                                            color: theme.cardColor,
                                                                            borderRadius: BorderRadius.circular(4),
                                                                            border: Border.all(color: theme.dividerColor),
                                                                          ),
                                                                          child: Row(
                                                                            children: [
                                                                              Expanded(
                                                                                child: Text(
                                                                                  '#${quote.quoteNumber ?? 'N/A'}',
                                                                                  style: const TextStyle(
                                                                                    fontSize: 12,
                                                                                    fontWeight: FontWeight.w500,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                currencyFormat.format(quote.totalAmount),
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  color: theme.primaryColor,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(width: 8),
                                                                              Icon(
                                                                                Icons.arrow_forward_ios,
                                                                                size: 12,
                                                                                color: theme.disabledColor,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }).toList(),
                                                                  ],
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          loading: () => const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                          error: (error, stack) => Text(
                                            'Error loading projects: $error',
                                            style: TextStyle(color: theme.colorScheme.error),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error loading clients: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(clientsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _companyController.clear();
    _contactNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _cityController.clear();
    _stateController.clear();
    _zipCodeController.clear();
    _notesController.clear();
    _editingClientId = null;
  }
  
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getProjectStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'on-hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<List<Quote>> _loadProjectQuotes(String projectId) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return [];
      
      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('quotes/${user.uid}').get();
      
      if (!snapshot.exists || snapshot.value == null) return [];
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final quotes = <Quote>[];
      
      data.forEach((key, value) {
        try {
          final quoteMap = Map<String, dynamic>.from(value);
          quoteMap['id'] = key;
          
          // Only include quotes for this project
          if (quoteMap['project_id'] == projectId) {
            final quote = Quote.fromMap(quoteMap);
            quotes.add(quote);
          }
        } catch (e) {
          AppLogger.error('Error parsing quote $key', error: e);
        }
      });
      
      // Sort by created date (most recent first)
      quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return quotes;
    } catch (e) {
      AppLogger.error('Error loading project quotes', error: e);
      return [];
    }
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final dbService = ref.read(databaseServiceProvider);

      final clientData = {
        'company': _companyController.text,
        'contact_name': _contactNameController.text.isEmpty
            ? null
            : _contactNameController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
        'address':
            _addressController.text.isEmpty ? null : _addressController.text,
        'city': _cityController.text.isEmpty ? null : _cityController.text,
        'state': _stateController.text.isEmpty ? null : _stateController.text,
        'zip_code':
            _zipCodeController.text.isEmpty ? null : _zipCodeController.text,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      if (_editingClientId != null) {
        // Update existing client
        await dbService.updateClient(_editingClientId!, clientData);
      } else {
        // Add new client
        await dbService.addClient(clientData);
      }

      // Refresh the clients list
      ref.invalidate(clientsProvider);
      
      setState(() {
        _showAddForm = false;
        _clearForm();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingClientId != null 
                ? 'Client updated successfully' 
                : 'Client added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingClientId != null 
                ? 'Error updating client: $e'
                : 'Error adding client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editClient(Client client) {
    // Populate form with existing client data
    setState(() {
      _editingClientId = client.id;
      _companyController.text = client.company;
      _contactNameController.text = client.contactName;
      _emailController.text = client.email;
      _phoneController.text = client.phone;
      _addressController.text = client.address ?? '';
      _cityController.text = client.city ?? '';
      _stateController.text = client.state ?? '';
      _zipCodeController.text = client.zipCode ?? '';
      _notesController.text = client.notes ?? '';
      _showAddForm = true;
    });
  }

  Future<void> _deleteClient(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Are you sure you want to delete ${client.company}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.deleteClient(client.id ?? '');
      
      // Refresh the clients list
      ref.invalidate(clientsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client deleted successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show profile picture options
  void _showProfilePictureOptions(Client client) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (client.profilePictureUrl != null)
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Profile Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _viewProfilePicture(client);
                },
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Upload New Picture'),
              onTap: () {
                Navigator.pop(context);
                _uploadProfilePicture(client);
              },
            ),
            if (client.profilePictureUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Picture', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture(client);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // View profile picture in a dialog
  void _viewProfilePicture(Client client) {
    if (client.profilePictureUrl == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('${client.company} Profile'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Image.network(
                    client.profilePictureUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 48, color: Colors.red),
                            SizedBox(height: 8),
                            Text('Failed to load image'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Upload profile picture
  Future<void> _uploadProfilePicture(Client client) async {
    try {
      // Pick image file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      final file = result.files.single;
      
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading profile picture...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Upload to Firebase Storage
      final downloadUrl = await StorageService.uploadClientProfilePicture(
        clientId: client.id ?? '',
        imageBytes: file.bytes!,
        fileName: file.name,
      );

      if (downloadUrl != null) {
        // Update client in database
        final dbService = ref.read(databaseServiceProvider);
        await dbService.updateClient(client.id ?? '', {
          'profile_picture_url': downloadUrl,
        });

        // Refresh clients list
        ref.invalidate(clientsProvider);

        // Hide loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Hide loading dialog
        if (mounted) Navigator.pop(context);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload profile picture'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Remove profile picture
  Future<void> _removeProfilePicture(Client client) async {
    if (client.profilePictureUrl == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text('Are you sure you want to remove the profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Delete from storage
      await StorageService.deleteProfilePicture(client.profilePictureUrl!);

      // Update client in database
      final dbService = ref.read(databaseServiceProvider);
      await dbService.updateClient(client.id ?? '', {
        'profile_picture_url': null,
      });

      // Refresh clients list
      ref.invalidate(clientsProvider);

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
          ),
        );
      }
    } catch (e) {
      // Hide loading
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Export clients to XLSX
  Future<void> _exportClientsToXLSX(String userId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: SizedBox(
            height: 100,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating Excel file...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Get clients data
      final clientsAsync = ref.read(clientsProvider);
      final clients = clientsAsync.valueOrNull ?? [];

      if (clients.isEmpty) {
        throw Exception('No clients to export');
      }

      // Generate Excel using ExportService
      final bytes = await ExportService.generateClientsExcel(clients);
      
      // Hide loading indicator
      if (mounted) Navigator.pop(context);
      
      // Download the file
      final filename = 'Clients_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await DownloadHelper.downloadFile(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clients exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting clients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
