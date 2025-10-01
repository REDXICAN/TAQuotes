import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/auth/providers/rbac_provider.dart';
import '../../../core/auth/models/rbac_permissions.dart';
import '../../../core/utils/price_formatter.dart';
import '../../projects/presentation/providers/projects_provider.dart' as projects_providers;

// Provider for admin to get all projects across all users (with user info wrapper)
final dashboardAllProjectsProvider = StreamProvider.autoDispose<List<ProjectWithUser>>((ref) {
  final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

  return hasAdminAccess.when(
    data: (hasAccess) {
      if (!hasAccess) return Stream.value([]);

      // Get all projects from all users
      return FirebaseDatabase.instance.ref('projects').onValue.map((event) {
        final List<ProjectWithUser> allProjects = [];

        if (event.snapshot.value != null) {
          final usersData = Map<String, dynamic>.from(event.snapshot.value as Map);

          usersData.forEach((userId, userProjects) {
            if (userProjects is Map) {
              final projectsMap = Map<String, dynamic>.from(userProjects);

              projectsMap.forEach((projectId, projectData) {
                if (projectData is Map) {
                  try {
                    final projectMap = Map<String, dynamic>.from(projectData);
                    projectMap['id'] = projectId;
                    final project = Project.fromJson(projectMap);

                    allProjects.add(ProjectWithUser(
                      project: project,
                      userId: userId,
                      userName: 'User $userId', // Will be enhanced to fetch actual name later
                    ));
                  } catch (e) {
                    // Skip malformed projects
                  }
                }
              });
            }
          });
        }

        return allProjects;
      });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

class ProjectWithUser {
  final Project project;
  final String userId;
  final String userName;

  const ProjectWithUser({
    required this.project,
    required this.userId,
    required this.userName,
  });
}

class ProjectsDashboardWidget extends ConsumerWidget {
  const ProjectsDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

    return hasAdminAccess.when(
      data: (isAdmin) => isAdmin ? _buildAdminProjectsView(context, ref) : _buildUserProjectsView(context, ref),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _buildUserProjectsView(context, ref),
    );
  }

  Widget _buildUserProjectsView(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projects_providers.projectsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Projects',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/projects'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        projectsAsync.when(
          data: (projects) {
            if (projects.isEmpty) {
              return _buildEmptyState('No projects yet', 'Start your first project');
            }

            return Column(
              children: [
                _buildProjectsSummary(projects),
                const SizedBox(height: 16),
                _buildProjectsList(context, projects.take(3).toList()),
                if (projects.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${projects.length - 3} more projects...',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => _buildEmptyState('Error loading projects', error.toString()),
        ),
      ],
    );
  }

  Widget _buildAdminProjectsView(BuildContext context, WidgetRef ref) {
    final allProjectsAsync = ref.watch(dashboardAllProjectsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'All Projects (Admin)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/projects'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Manage All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        allProjectsAsync.when(
          data: (allProjects) {
            if (allProjects.isEmpty) {
              return _buildEmptyState('No projects in system', 'No projects have been created yet');
            }

            // Group projects by user
            final Map<String, List<ProjectWithUser>> projectsByUser = {};
            for (final projectWithUser in allProjects) {
              final userName = projectWithUser.userName;
              projectsByUser.putIfAbsent(userName, () => []);
              projectsByUser[userName]!.add(projectWithUser);
            }

            return Column(
              children: [
                _buildAllProjectsSummary(allProjects),
                const SizedBox(height: 16),
                ...projectsByUser.entries.take(3).map((entry) =>
                  _buildUserProjectsSection(context, entry.key, entry.value)
                ),
                if (projectsByUser.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${projectsByUser.length - 3} more users with projects...',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => _buildEmptyState('Error loading projects', error.toString()),
        ),
      ],
    );
  }

  Widget _buildProjectsSummary(List<Project> projects) {
    final activeProjects = projects.where((p) => p.status == 'active').length;
    final completedProjects = projects.where((p) => p.status == 'completed').length;
    final totalValue = projects.fold<double>(0, (sum, p) => sum + (p.estimatedValue ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem('Total', projects.length.toString(), Colors.blue),
          ),
          Container(width: 1, height: 40, color: Colors.blue.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryItem('Active', activeProjects.toString(), Colors.green),
          ),
          Container(width: 1, height: 40, color: Colors.blue.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryItem('Completed', completedProjects.toString(), Colors.orange),
          ),
          Container(width: 1, height: 40, color: Colors.blue.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryItem('Est. Value', '\$${PriceFormatter.formatPrice(totalValue)}', Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildAllProjectsSummary(List<ProjectWithUser> allProjects) {
    final activeProjects = allProjects.where((p) => p.project.status == 'active').length;
    final completedProjects = allProjects.where((p) => p.project.status == 'completed').length;
    final uniqueUsers = allProjects.map((p) => p.userId).toSet().length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem('Total', allProjects.length.toString(), Colors.purple),
          ),
          Container(width: 1, height: 40, color: Colors.purple.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryItem('Users', uniqueUsers.toString(), Colors.blue),
          ),
          Container(width: 1, height: 40, color: Colors.purple.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryItem('Active', activeProjects.toString(), Colors.green),
          ),
          Container(width: 1, height: 40, color: Colors.purple.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryItem('Completed', completedProjects.toString(), Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUserProjectsSection(BuildContext context, String userName, List<ProjectWithUser> projects) {
    return ExpansionTile(
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${projects.length} projects'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildProjectsList(context, projects.map((p) => p.project).take(3).toList()),
        ),
      ],
    );
  }

  Widget _buildProjectsList(BuildContext context, List<Project> projects) {
    return Column(
      children: projects.map((project) => _buildProjectCard(context, project)).toList(),
    );
  }

  Widget _buildProjectCard(BuildContext context, Project project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(project.status).withValues(alpha: 0.2),
          child: Icon(
            _getStatusIcon(project.status),
            color: _getStatusColor(project.status),
            size: 20,
          ),
        ),
        title: Text(
          project.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${project.clientName}'),
            if (project.productLines.isNotEmpty)
              Text('Product Lines: ${project.productLines.take(2).join(', ')}${project.productLines.length > 2 ? '...' : ''}'),
            if (project.estimatedValue != null)
              Text('Est. Value: \$${PriceFormatter.formatPrice(project.estimatedValue!)}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(project.status).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            project.statusDisplay,
            style: TextStyle(
              color: _getStatusColor(project.status),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () {
          // Navigate to project detail (if route exists)
          // context.go('/projects/${project.id}');
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'planning':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.orange;
      case 'on-hold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'planning':
        return Icons.lightbulb_outline;
      case 'active':
        return Icons.play_circle_outline;
      case 'completed':
        return Icons.check_circle_outline;
      case 'on-hold':
        return Icons.pause_circle_outline;
      default:
        return Icons.work_outline;
    }
  }
}