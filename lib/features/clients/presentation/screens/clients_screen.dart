// lib/features/clients/presentation/screens/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/app_logger.dart';

// Clients provider using Realtime Database
final clientsProvider = FutureProvider<List<Client>>((ref) async {
  // Clients require authentication
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }
  
  final dbService = ref.watch(databaseServiceProvider);
  
  try {
    // Get clients as a one-time read
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('clients/${user.uid}').get();
    
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final List<Client> clients = [];
    
    data.forEach((key, value) {
      final clientMap = Map<String, dynamic>.from(value);
      clientMap['id'] = key;
      try {
        clients.add(Client.fromMap(clientMap));
      } catch (e) {
        AppLogger.error('Error parsing client $key', error: e);
      }
    });
    
    // Sort by company name
    clients.sort((a, b) => a.company.compareTo(b.company));
    return clients;
  } catch (e) {
    AppLogger.error('Error loading clients', error: e);
    return [];
  }
});

// Selected client provider
final selectedClientProvider = StateProvider<Client?>((ref) => null);

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  bool _showAddForm = false;
  String? _editingClientId;
  String _searchQuery = '';
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

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final selectedClient = ref.watch(selectedClientProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
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
              const PopupMenuItem(
                value: 'xlsx',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Export as Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_showAddForm ? Icons.close : Icons.add),
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
              padding: const EdgeInsets.all(12),
              color: Colors.green.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${selectedClient.company}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
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
                        ),
                        keyboardType: TextInputType.phone,
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
                                ? Text(
                                    client.company[0].toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : theme.textTheme.bodyLarge?.color,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        title: Text(
                          client.company,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
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
                              // Selection checkbox/button
                              IconButton(
                                icon: Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? Colors.green : theme.disabledColor,
                                  size: 28,
                                ),
                                onPressed: () {
                                  if (isSelected) {
                                    // Deselect if already selected
                                    ref
                                        .read(selectedClientProvider.notifier)
                                        .state = null;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Deselected: ${client.company}'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  } else {
                                    // Select if not selected
                                    ref
                                        .read(selectedClientProvider.notifier)
                                        .state = client;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Selected: ${client.company}'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
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
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // For now, show not implemented message
      throw Exception('Excel export not yet implemented');
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
