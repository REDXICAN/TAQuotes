// lib/features/projects/presentation/screens/projects_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/widgets/app_bar_with_client.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/projects_provider.dart';
import '../widgets/project_card.dart';
import '../widgets/project_form_dialog.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;
  String _sortBy = 'date'; // date, name, value, client

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Project> _filterAndSortProjects(List<Project> projects) {
    // Filter by search query
    var filtered = projects.where((project) {
      if (_searchQuery.isEmpty) return true;

      final matchesName = project.name.toLowerCase().contains(_searchQuery);
      final matchesClient = project.clientName.toLowerCase().contains(_searchQuery);
      final matchesLocation = project.location.toLowerCase().contains(_searchQuery);
      final matchesPerson = project.personInCharge.toLowerCase().contains(_searchQuery);

      return matchesName || matchesClient || matchesLocation || matchesPerson;
    }).toList();

    // Filter by status
    if (_selectedStatus != null) {
      filtered = filtered.where((p) => p.status == _selectedStatus).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'value':
        filtered.sort((a, b) {
          final aValue = a.estimatedValue ?? 0;
          final bValue = b.estimatedValue ?? 0;
          return bValue.compareTo(aValue); // Descending
        });
        break;
      case 'client':
        filtered.sort((a, b) => a.clientName.compareTo(b.clientName));
        break;
      case 'date':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
        break;
    }

    return filtered;
  }

  void _showProjectForm({Project? project}) {
    showDialog(
      context: context,
      builder: (context) => ProjectFormDialog(project: project),
    );
  }

  Future<void> _exportProjects(String format, List<Project> projects) async {
    try {
      if (projects.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No projects to export')),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('Generating $format export...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      if (format == 'excel') {
        final bytes = await ExportService.generateProjectsExcel(projects);
        final filename = 'projects_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await DownloadHelper.downloadFile(bytes: bytes, filename: filename);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${projects.length} projects to Excel')),
          );
        }
      } else if (format == 'pdf') {
        // For PDF, show message that individual PDFs can be exported from card menu
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tip: Export individual project PDFs from the card menu'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error exporting projects', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.deleteProject(project.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project "${project.name}" deleted')),
        );
      }
    } catch (e) {
      AppLogger.error('Error deleting project', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting project: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(projectsProvider);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      appBar: const AppBarWithClient(
        title: 'Projects',
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Filters and Sort Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Status Filter
                    FilterChip(
                      label: Text(_selectedStatus ?? 'All Status'),
                      selected: _selectedStatus != null,
                      onSelected: (selected) {
                        setState(() {
                          if (_selectedStatus == null) {
                            _selectedStatus = 'planning';
                          } else {
                            // Cycle through statuses
                            final statuses = ['planning', 'active', 'completed', 'on-hold', null];
                            final currentIndex = statuses.indexOf(_selectedStatus);
                            _selectedStatus = statuses[(currentIndex + 1) % statuses.length];
                          }
                        });
                      },
                    ),

                    // Sort Dropdown
                    DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(value: 'date', child: Text('Sort: Date')),
                        DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                        DropdownMenuItem(value: 'value', child: Text('Sort: Value')),
                        DropdownMenuItem(value: 'client', child: Text('Sort: Client')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortBy = value);
                        }
                      },
                    ),

                    // Export Menu
                    projectsAsync.when(
                      data: (allProjects) {
                        final filteredProjects = _filterAndSortProjects(allProjects);
                        return PopupMenuButton<String>(
                          icon: const Icon(Icons.download),
                          tooltip: 'Export',
                          onSelected: (value) => _exportProjects(value, filteredProjects),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'excel', child: Text('Export to Excel')),
                            const PopupMenuItem(value: 'pdf', child: Text('Export Info')),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
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
                final filteredProjects = _filterAndSortProjects(projects);

                if (filteredProjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty || _selectedStatus != null
                              ? Icons.search_off
                              : Icons.folder_open,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _selectedStatus != null
                              ? 'No projects match your filters'
                              : 'No projects yet',
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showProjectForm(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Project'),
                        ),
                      ],
                    ),
                  );
                }

                // Responsive Grid Layout
                int crossAxisCount = 1;
                if (isDesktop) {
                  crossAxisCount = 3;
                } else if (isTablet) {
                  crossAxisCount = 2;
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isDesktop ? 1.5 : (isTablet ? 1.3 : 1.8),
                  ),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = filteredProjects[index];
                    return ProjectCard(
                      project: project,
                      onTap: () {
                        // Navigate to project detail (if needed)
                        // For now, open edit dialog
                        _showProjectForm(project: project);
                      },
                      onEdit: () => _showProjectForm(project: project),
                      onDelete: () => _deleteProject(project),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                AppLogger.error('Error loading projects', error: error);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading projects',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(error.toString(), style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(projectsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProjectForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}
