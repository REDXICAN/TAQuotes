// lib/core/providers/sync_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';

/// Provider for the sync service instance
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();

  // Initialize on first access
  service.initialize();

  // Clean up when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream provider for sync progress updates
final syncProgressProvider = StreamProvider.autoDispose<SyncProgress>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.syncStatusStream;
});

/// Provider for last sync time
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.lastSyncTime;
});

/// Provider for sync conflicts
final syncConflictsProvider = Provider<List<SyncConflict>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.conflicts;
});

/// Provider to check if sync is needed
final isSyncNeededProvider = Provider<bool>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.isSyncNeeded;
});

/// Future provider to trigger sync
final syncDataProvider = FutureProvider<SyncResult>((ref) async {
  final syncService = ref.read(syncServiceProvider);
  return await syncService.syncAll();
});

/// Provider for manual sync trigger
final triggerSyncProvider = Provider<Future<SyncResult> Function()>((ref) {
  final syncService = ref.read(syncServiceProvider);
  return () => syncService.syncAll();
});