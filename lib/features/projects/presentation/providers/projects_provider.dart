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

// Single Project Provider
final projectByIdProvider = FutureProvider.family<Project?, String>((ref, projectId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final dbService = ref.watch(databaseServiceProvider);
  final projectData = await dbService.getProjectById(projectId);
  if (projectData != null) {
    return Project.fromJson(projectData);
  }
  return null;
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