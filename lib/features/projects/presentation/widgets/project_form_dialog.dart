// lib/features/projects/presentation/widgets/project_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/app_logger.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../clients/presentation/screens/clients_screen.dart'; // For clientsProvider

class ProjectFormDialog extends ConsumerStatefulWidget {
  final Project? project; // null for create, not-null for edit

  const ProjectFormDialog({
    super.key,
    this.project,
  });

  @override
  ConsumerState<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _personInChargeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedClientId;
  String? _selectedClientName;
  String _selectedStatus = 'planning';
  List<String> _selectedProductLines = [];
  DateTime? _startDate;
  DateTime? _completionDate;
  bool _isSaving = false;

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
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.project != null) {
      // Edit mode - populate form with existing data
      final project = widget.project!;
      _nameController.text = project.name;
      _locationController.text = project.location;
      _personInChargeController.text = project.personInCharge;
      _phoneController.text = project.phone ?? '';
      _emailController.text = project.email ?? '';
      _estimatedValueController.text = project.estimatedValue?.toStringAsFixed(2) ?? '';
      _notesController.text = project.notes ?? '';
      _selectedClientId = project.clientId;
      _selectedClientName = project.clientName;
      _selectedStatus = project.status;
      _selectedProductLines = List.from(project.productLines);
      _startDate = project.startDate;
      _completionDate = project.completionDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _personInChargeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _estimatedValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_completionDate ?? DateTime.now());

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _completionDate = picked;
        }
      });
    }
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dbService = ref.read(databaseServiceProvider);
      final estimatedValue = _estimatedValueController.text.isEmpty
          ? null
          : double.tryParse(_estimatedValueController.text);

      if (widget.project == null) {
        // Create new project
        await dbService.createProject(
          name: _nameController.text.trim(),
          clientId: _selectedClientId!,
          clientName: _selectedClientName!,
          location: _locationController.text.trim(),
          personInCharge: _personInChargeController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          productLines: _selectedProductLines,
          status: _selectedStatus,
          estimatedValue: estimatedValue,
          startDate: _startDate,
          completionDate: _completionDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Project "${_nameController.text}" created')),
          );
        }
      } else {
        // Update existing project
        await dbService.updateProject(
          widget.project!.id,
          {
            'name': _nameController.text.trim(),
            'clientId': _selectedClientId!,
            'clientName': _selectedClientName!,
            'location': _locationController.text.trim(),
            'personInCharge': _personInChargeController.text.trim(),
            if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
            if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
            'productLines': _selectedProductLines,
            'status': _selectedStatus,
            if (estimatedValue != null) 'estimatedValue': estimatedValue,
            if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
            if (_completionDate != null) 'completionDate': _completionDate!.toIso8601String(),
            if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Project "${_nameController.text}" updated')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.error('Error saving project', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving project: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');
    final clientsAsync = ref.watch(clientsProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                widget.project == null ? 'New Project' : 'Edit Project',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // Form
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Name
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Project Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter project name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Client Selection
                        clientsAsync.when(
                          data: (clients) {
                            return DropdownButtonFormField<String>(
                              initialValue: _selectedClientId,
                              decoration: const InputDecoration(
                                labelText: 'Client *',
                                border: OutlineInputBorder(),
                              ),
                              items: clients.map((client) {
                                return DropdownMenuItem(
                                  value: client.id,
                                  child: Text(client.company),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedClientId = value;
                                  _selectedClientName = clients
                                      .firstWhere((c) => c.id == value)
                                      .company;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a client';
                                }
                                return null;
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) => Text('Error loading clients: $error'),
                        ),
                        const SizedBox(height: 16),

                        // Location
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location *',
                            hintText: 'e.g., Cancún, Quintana Roo',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Person in Charge
                        TextFormField(
                          controller: _personInChargeController,
                          decoration: const InputDecoration(
                            labelText: 'Person in Charge *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter person in charge';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone and Email Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Status
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status.substring(0, 1).toUpperCase() + status.substring(1)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedStatus = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Product Lines
                        Text(
                          'Product Lines',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _productLineOptions.map((line) {
                            final isSelected = _selectedProductLines.contains(line);
                            return FilterChip(
                              label: Text(line),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
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

                        // Estimated Value
                        TextFormField(
                          controller: _estimatedValueController,
                          decoration: const InputDecoration(
                            labelText: 'Estimated Value',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dates Row
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    _startDate == null
                                        ? 'Select date'
                                        : dateFormat.format(_startDate!),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Completion Date',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    _completionDate == null
                                        ? 'Select date'
                                        : dateFormat.format(_completionDate!),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProject,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.project == null ? 'Create' : 'Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
