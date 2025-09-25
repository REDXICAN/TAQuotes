import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
// import '../../../clients/domain/models/client_model.dart';
// import '../../../clients/presentation/providers/clients_provider.dart';
import '../../../../core/models/models.dart';
import '../../../clients/presentation/screens/clients_screen.dart';
// import '../../domain/models/project_model.dart';
import '../providers/projects_provider.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedClient;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _completionDate;
  String? _selectedClientId;
  String _selectedProjectStatus = 'planning';
  List<String> _selectedProductLines = [];

  final List<String> _statusOptions = ['planning', 'active', 'completed', 'on-hold'];
  final List<String> _productLineOptions = [
    'Refrigeration',
    'Freezers',
    'Prep Tables',
    'Display Cases',
    'Ice Machines',
    'Cooking Equipment',
    'Ventilation',
    'Storage',
    'Bar Equipment',
    'Spare Parts',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _estimatedValueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'on-hold':
        return Colors.orange;
      case 'planning':
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return '🚀';
      case 'completed':
        return '✅';
      case 'on-hold':
        return '⏸️';
      case 'planning':
      default:
        return '📋';
    }
  }

  void _showProjectDialog({Project? project}) {
    setState(() {
      if (project != null) {
        _nameController.text = project.name;
        _addressController.text = project.address;
        _estimatedValueController.text = project.estimatedValue?.toStringAsFixed(2) ?? '0.00';
        _descriptionController.text = project.description ?? '';
        _startDate = project.startDate;
        _completionDate = project.completionDate;
        _selectedClientId = project.clientId;
        _selectedProjectStatus = project.status;
        _selectedProductLines = List.from(project.productLines);
      } else {
        _clearForm();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildProjectDialog(project),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _addressController.clear();
    _estimatedValueController.clear();
    _descriptionController.clear();
    _startDate = DateTime.now();
    _completionDate = null;
    _selectedClientId = null;
    _selectedProjectStatus = 'planning';
    _selectedProductLines = [];
  }

  Widget _buildProjectDialog(Project? project) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(project != null ? 'Edit Project' : 'New Project'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Project Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Project Name',
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Project name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Client Selection
                  Consumer(
                    builder: (context, ref, child) {
                      final clientsAsync = ref.watch(clientsProvider);
                      return clientsAsync.when(
                        data: (clients) => DropdownButtonFormField<String>(
                          initialValue: _selectedClientId,
                          decoration: const InputDecoration(
                            labelText: 'Select Client',
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: clients.map((client) {
                            return DropdownMenuItem(
                              value: client.id,
                              child: Text(client.company),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedClientId = value;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a client' : null,
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading clients'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Product Lines
                  const Text('Product Lines Interested In:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _productLineOptions.map((line) {
                      final isSelected = _selectedProductLines.contains(line);
                      return FilterChip(
                        label: Text(line),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              _selectedProductLines.add(line);
                            } else {
                              _selectedProductLines.remove(line);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Project Address',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    maxLines: 2,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Status
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProjectStatus,
                    decoration: const InputDecoration(
                      labelText: 'Project Status',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Row(
                          children: [
                            Text(_getStatusIcon(status)),
                            const SizedBox(width: 8),
                            Text(status[0].toUpperCase() + status.substring(1)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedProjectStatus = value ?? 'planning';
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Estimated Value
                  TextFormField(
                    controller: _estimatedValueController,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Project Value',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Value is required';
                      if (double.tryParse(value!) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Start Date
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      _startDate != null
                          ? DateFormat('MMM dd, yyyy').format(_startDate!)
                          : 'Not selected',
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          _startDate = picked;
                        });
                      }
                    },
                  ),

                  // Completion Date
                  ListTile(
                    leading: const Icon(Icons.event_available),
                    title: const Text('Completion Date (Optional)'),
                    subtitle: Text(
                      _completionDate != null
                          ? DateFormat('MMM dd, yyyy').format(_completionDate!)
                          : 'Not selected',
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _completionDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          _completionDate = picked;
                        });
                      }
                    },
                  ),

                  // Description
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description/Notes (Optional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _clearForm();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _saveProject(project?.id),
              child: Text(project != null ? 'Update' : 'Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProject(String? projectId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product line')),
      );
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date')),
      );
      return;
    }

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');

      final dbService = ref.read(databaseServiceProvider);

      if (projectId != null) {
        // Update existing project
        await dbService.updateProject(projectId, {
          'name': _nameController.text,
          'clientId': _selectedClientId,
          'productLines': _selectedProductLines,
          'address': _addressController.text,
          'status': _selectedProjectStatus,
          'estimatedValue': double.parse(_estimatedValueController.text),
          'startDate': _startDate!.toIso8601String(),
          'completionDate': _completionDate?.toIso8601String(),
          'salesRepId': user.uid,
          'salesRepName': user.email,
          'description': _descriptionController.text,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project updated successfully')),
          );
        }
      } else {
        // Create new project
        await dbService.createProject(
          name: _nameController.text,
          clientId: _selectedClientId!,
          description: _descriptionController.text,
          status: _selectedProjectStatus,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project created successfully')),
          );
        }
      }

      _clearForm();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dbService = ref.read(databaseServiceProvider);
        await dbService.deleteProject(projectId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting project: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProjectDialog(),
            tooltip: 'Add Project',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
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
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Filter chips
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Status filter
                            PopupMenuButton<String>(
                              initialValue: _selectedStatus,
                              onSelected: (status) {
                                setState(() {
                                  _selectedStatus = status == 'all' ? null : status;
                                });
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'all',
                                  child: Text('All Status'),
                                ),
                                ..._statusOptions.map((status) => PopupMenuItem(
                                      value: status,
                                      child: Row(
                                        children: [
                                          Text(_getStatusIcon(status)),
                                          const SizedBox(width: 8),
                                          Text(status[0].toUpperCase() +
                                              status.substring(1)),
                                        ],
                                      ),
                                    )),
                              ],
                              child: Chip(
                                avatar: const Icon(Icons.filter_list, size: 18),
                                label: Text(_selectedStatus != null
                                    ? _selectedStatus![0].toUpperCase() +
                                        _selectedStatus!.substring(1)
                                    : 'All Status'),
                                onDeleted: _selectedStatus != null
                                    ? () {
                                        setState(() {
                                          _selectedStatus = null;
                                        });
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Client filter
                            clientsAsync.when(
                              data: (clients) => PopupMenuButton<String>(
                                initialValue: _selectedClient,
                                onSelected: (clientId) {
                                  setState(() {
                                    _selectedClient = clientId == 'all' ? null : clientId;
                                  });
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'all',
                                    child: Text('All Clients'),
                                  ),
                                  ...clients.map((client) => PopupMenuItem(
                                        value: client.id,
                                        child: Text(client.company),
                                      )),
                                ],
                                child: Chip(
                                  avatar: const Icon(Icons.person, size: 18),
                                  label: Text(_selectedClient != null
                                      ? clients
                                              .firstWhere(
                                                  (c) => c.id == _selectedClient)
                                              .company
                                          : 'All Clients'),
                                  onDeleted: _selectedClient != null
                                      ? () {
                                          setState(() {
                                            _selectedClient = null;
                                          });
                                        }
                                      : null,
                                ),
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Projects List
          Expanded(
            child: projectsAsync.when(
              data: (projects) {
                // Apply filters
                var filteredProjects = projects.where((project) {
                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final searchLower = _searchQuery.toLowerCase();
                    if (!project.name.toLowerCase().contains(searchLower) &&
                        !project.address.toLowerCase().contains(searchLower) &&
                        !(project.description?.toLowerCase().contains(searchLower) ??
                            false) &&
                        !project.productLines.any(
                            (line) => line.toLowerCase().contains(searchLower))) {
                      return false;
                    }
                  }
                  // Status filter
                  if (_selectedStatus != null && project.status != _selectedStatus) {
                    return false;
                  }
                  // Client filter
                  if (_selectedClient != null &&
                      project.clientId != _selectedClient) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filteredProjects.isEmpty) {
                  return const Center(
                    child: Text('No projects found'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = filteredProjects[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(project.status),
                          child: Text(
                            _getStatusIcon(project.status),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          project.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Client: ${project.clientName ?? project.clientId}'),
                            Text('Value: ${PriceFormatter.formatPrice(project.estimatedValue ?? 0.0)}'),
                            Text('Start: ${project.startDate != null ? DateFormat('MMM dd, yyyy').format(project.startDate!) : 'Not set'}'),
                            Wrap(
                              spacing: 4,
                              children: project.productLines
                                  .take(3)
                                  .map((line) => Chip(
                                        label: Text(
                                          line,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        padding: const EdgeInsets.all(0),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showProjectDialog(project: project),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProject(project.id),
                            ),
                          ],
                        ),
                        onTap: () => _showProjectDetails(project),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Error loading projects: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProjectDetails(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(_getStatusIcon(project.status)),
            const SizedBox(width: 8),
            Expanded(child: Text(project.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Client', project.clientName ?? project.clientId ?? ''),
              _buildDetailRow('Address', project.address),
              _buildDetailRow(
                  'Status', '${project.status[0].toUpperCase()}${project.status.substring(1)}'),
              _buildDetailRow('Estimated Value',
                  PriceFormatter.formatPrice(project.estimatedValue ?? 0.0)),
              _buildDetailRow(
                  'Start Date', project.startDate != null ? DateFormat('MMM dd, yyyy').format(project.startDate!) : 'Not set'),
              if (project.completionDate != null)
                _buildDetailRow('Completion Date',
                    DateFormat('MMM dd, yyyy').format(project.completionDate!)),
              _buildDetailRow('Sales Rep', project.salesRepName ?? project.salesRepId ?? 'Not assigned'),
              const SizedBox(height: 8),
              const Text('Product Lines:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: project.productLines
                    .map((line) => Chip(
                          label: Text(line, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
              if (project.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(project.description!),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}