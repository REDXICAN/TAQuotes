/// Offline Service Stub
///
/// This app uses Firebase's built-in offline persistence:
/// - Mobile (iOS/Android): Firebase automatically caches data and syncs when online
/// - Web: Firebase Realtime Database maintains connection state
///
/// No custom offline implementation needed - Firebase handles everything!

import 'dart:async';

class OfflineService {
  // Always initialized since Firebase handles offline
  static bool get isInitialized => true;

  // No initialization needed - Firebase handles it
  static Future<void> staticInitialize() async {
    // Firebase offline persistence is already enabled in RealtimeDatabaseService
    return;
  }

  // No queue needed - Firebase handles sync
  static Stream<List<dynamic>> get staticQueueStream => Stream.value([]);

  // Firebase automatically syncs, so queue is always empty
  static Future<int> staticGetSyncQueueCount() async => 0;

  // Firebase always has offline data when persistence is enabled
  static Future<bool> staticHasOfflineData() async => false;

  // Firebase automatically syncs when connection is restored
  static Future<void> syncPendingChanges() async {
    // Firebase handles this automatically
    return;
  }

  // Cart is handled by Firebase persistence
  static Map<String, dynamic> getStaticCart() => {};
}