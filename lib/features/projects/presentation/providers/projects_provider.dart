import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/auth/providers/rbac_provider.dart';
import '../../../../core/auth/models/rbac_permissions.dart';

// Projects Stream Provider (for current user)
final projectsProvider = StreamProvider.autoDispose<List<Project>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getProjects().map((projectsList) {
    return projectsList.map((json) => Project.fromJson(json)).toList();
  });
});

// Single Project Provider with auto-refresh
final projectByIdProvider = StreamProvider.autoDispose.family<Project?, String>((ref, projectId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  final dbService = ref.watch(databaseServiceProvider);

  return Stream.periodic(const Duration(seconds: 30), (_) => null)
      .asyncMap((_) async {
        final projectData = await dbService.getProjectById(projectId);
        if (projectData != null) {
          return Project.fromJson(projectData);
        }
        return null;
      })
      .handleError((error) => null);
});

// Projects by Client Provider
final projectsByClientProvider = StreamProvider.autoDispose.family<List<Project>, String>((ref, clientId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getProjectsByClient(clientId).map((projectsList) {
    return projectsList.map((json) => Project.fromJson(json)).toList();
  });
});

// ============ ADMIN PROVIDERS ============

// All Projects Provider (admin only - streams all projects from all users)
final allProjectsProvider = StreamProvider.autoDispose<List<Project>>((ref) {
  final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

  return hasAdminAccess.when(
    data: (hasAccess) {
      if (!hasAccess) return Stream.value([]);

      final dbService = ref.watch(databaseServiceProvider);
      return dbService.getAllProjectsForAdmin().map((projectsList) {
        return projectsList.map((json) => Project.fromJson(json)).toList();
      });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// Top Clients by Projects Provider (admin analytics)
final topClientsByProjectsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, limit) async {
  final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

  return hasAdminAccess.when(
    data: (hasAccess) async {
      if (!hasAccess) return [];

      final dbService = ref.watch(databaseServiceProvider);
      return await dbService.getTopClientsByProjects(limit: limit);
    },
    loading: () async => [],
    error: (_, __) async => [],
  );
});

// Project Stats by User Provider (admin analytics)
final projectStatsByUserProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, userId) async {
  final hasAdminAccess = ref.watch(hasPermissionProvider(Permission.accessAdminPanel));

  return hasAdminAccess.when(
    data: (hasAccess) async {
      if (!hasAccess) {
        return {
          'totalProjects': 0,
          'activeProjects': 0,
          'completedProjects': 0,
          'totalValue': 0.0,
        };
      }

      final dbService = ref.watch(databaseServiceProvider);
      return await dbService.getProjectStatsByUser(userId);
    },
    loading: () async => {
      'totalProjects': 0,
      'activeProjects': 0,
      'completedProjects': 0,
      'totalValue': 0.0,
    },
    error: (_, __) async => {
      'totalProjects': 0,
      'activeProjects': 0,
      'completedProjects': 0,
      'totalValue': 0.0,
    },
  );
});