import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/models/models.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Simple clients provider - just load once
final clientsProviderV2 = FutureProvider<List<Client>>((ref) async {
  try {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('clients/${user.uid}').get();
    
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final clients = <Client>[];
    
    for (final entry in data.entries) {
      try {
        final clientMap = Map<String, dynamic>.from(entry.value);
        clientMap['id'] = entry.key;
        clients.add(Client.fromMap(clientMap));
      } catch (e) {
        AppLogger.debug('Error parsing client ${entry.key}: $e');
      }
    }
    
    clients.sort((a, b) => a.company.compareTo(b.company));
    return clients;
  } catch (e) {
    AppLogger.error('Error loading clients: $e');
    return [];
  }
});

class ClientsScreenV2 extends ConsumerStatefulWidget {
  const ClientsScreenV2({super.key});
  
  @override
  ConsumerState<ClientsScreenV2> createState() => _ClientsScreenV2State();
}

class _ClientsScreenV2State extends ConsumerState<ClientsScreenV2> {
  String _searchQuery = '';
  bool _showAddForm = false;
  String? _editingClientId;
  
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
  void dispose() {
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
  
  void _resetForm() {
    _companyController.clear();
    _contactNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _cityController.clear();
    _stateController.clear();
    _zipCodeController.clear();
    _notesController.clear();
    setState(() {
      _showAddForm = false;
      _editingClientId = null;
    });
  }
  
  void _editClient(Client client) {
    _companyController.text = client.company;
    _contactNameController.text = client.contactName;
    _emailController.text = client.email;
    _phoneController.text = client.phone;
    _addressController.text = client.address ?? '';
    _cityController.text = client.city ?? '';
    _stateController.text = client.state ?? '';
    _zipCodeController.text = client.zipCode ?? '';
    _notesController.text = client.notes ?? '';
    
    setState(() {
      _showAddForm = true;
      _editingClientId = client.id;
    });
  }
  
  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      
      final database = FirebaseDatabase.instance;
      final clientData = {
        'company': _companyController.text.trim(),
        'contact_name': _contactNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zip_code': _zipCodeController.text.trim(),
        'notes': _notesController.text.trim(),
        'user_id': user.uid,
        'updated_at': ServerValue.timestamp,
      };
      
      if (_editingClientId != null) {
        // Update existing
        await database.ref('clients/${user.uid}/$_editingClientId').update(clientData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client updated successfully')),
          );
        }
      } else {
        // Add new
        clientData['created_at'] = ServerValue.timestamp;
        await database.ref('clients/${user.uid}').push().set(clientData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client added successfully')),
          );
        }
      }
      
      _resetForm();
      ref.invalidate(clientsProviderV2);
      
    } catch (e) {
      AppLogger.error('Error saving client: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _deleteClient(String clientId) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      
      final database = FirebaseDatabase.instance;
      await database.ref('clients/${user.uid}/$clientId').remove();
      
      ref.invalidate(clientsProviderV2);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client deleted successfully')),
        );
      }
    } catch (e) {
      AppLogger.error('Error deleting client: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  List<Client> _filterClients(List<Client> clients) {
    if (_searchQuery.isEmpty) return clients;
    
    final query = _searchQuery.toLowerCase();
    return clients.where((client) =>
      client.company.toLowerCase().contains(query) ||
      client.contactName.toLowerCase().contains(query) ||
      client.email.toLowerCase().contains(query) ||
      client.phone.toLowerCase().contains(query) ||
      (client.city ?? '').toLowerCase().contains(query) ||
      (client.state ?? '').toLowerCase().contains(query)
    ).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProviderV2);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBarWithClient(
        title: 'Clients',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(clientsProviderV2),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Add button
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search clients...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(_showAddForm ? Icons.close : Icons.add),
                  label: Text(_showAddForm ? 'Cancel' : 'Add Client'),
                  onPressed: () {
                    if (_showAddForm) {
                      _resetForm();
                    } else {
                      setState(() => _showAddForm = true);
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Add/Edit form
          if (_showAddForm)
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.primaryColor.withOpacity(0.05),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _companyController,
                            decoration: const InputDecoration(
                              labelText: 'Company *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => 
                              value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _contactNameController,
                            decoration: const InputDecoration(
                              labelText: 'Contact Name *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => 
                              value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Required';
                              if (!value!.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => 
                              value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _zipCodeController,
                            decoration: const InputDecoration(
                              labelText: 'ZIP',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _resetForm,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(_editingClientId != null ? 'Update' : 'Save'),
                          onPressed: _saveClient,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          // Clients list
          Expanded(
            child: clientsAsync.when(
              data: (clients) {
                final filtered = _filterClients(clients);
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No clients yet' : 'No clients found',
                          style: theme.textTheme.titleLarge,
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add your first client'),
                            onPressed: () => setState(() => _showAddForm = true),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final client = filtered[index];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.primaryColor,
                          child: Text(
                            client.company.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          client.company,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(client.contactName),
                            Text(
                              '${client.email} • ${client.phone}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (client.city != null && client.city!.isNotEmpty)
                              Text(
                                '${client.city}, ${client.state} ${client.zipCode}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editClient(client),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Client'),
                                    content: Text('Delete ${client.company}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          if (client.id != null) _deleteClient(client.id!);
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Failed to load clients'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(clientsProviderV2),
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
}