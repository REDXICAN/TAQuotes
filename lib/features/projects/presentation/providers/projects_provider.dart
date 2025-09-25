import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/realtime_database_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/project_model.dart';

// Projects Stream Provider
final projectsProvider = StreamProvider<List<Project>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getProjects().map((projectsList) {
    return projectsList.map((json) => Project.fromJson(json)).toList();
  });
});

// Single Project Provider with auto-refresh
final projectByIdProvider = StreamProvider.family<Project?, String>((ref, projectId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  final dbService = ref.watch(databaseServiceProvider);
  // Use real-time stream if available, otherwise poll every 30 seconds
  return Stream.periodic(const Duration(seconds: 30), (_) => null)
      .asyncMap((_) async {
        final projectData = await dbService.getProjectById(projectId);
        if (projectData != null) {
          return Project.fromJson(projectData);
        }
        return null;
      })
});

// Projects by Client Provider
final projectsByClientProvider = StreamProvider.family<List<Project>, String>((ref, clientId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getProjectsByClient(clientId).map((projectsList) {
    return projectsList.map((json) => Project.fromJson(json)).toList();
  });
});