// lib/core/services/batch_data_loader.dart
import 'package:firebase_database/firebase_database.dart';
import 'app_logger.dart';

/// Batch Data Loader - Eliminates N+1 queries
///
/// Instead of making separate database calls for each user's quotes and clients,
/// this service loads ALL data in parallel with just 3 database calls total.
class BatchDataLoader {
  /// Load all users data in one call
  static Future<Map<String, dynamic>> getUsersData(FirebaseDatabase database) async {
    try {
      // Try 'user_profiles' first (recommended path with simpler permissions)
      try {
        final snapshot = await database.ref('user_profiles').get();
        if (snapshot.exists && snapshot.value != null) {
          AppLogger.info('Successfully accessed user_profiles path');
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
      } catch (e) {
        // If user_profiles fails, try fallback to 'users' path
        AppLogger.warning('user_profiles path failed, trying users path', error: e);
      }

      // Fallback to 'users' path
      final snapshot = await database.ref('users').get();
      if (snapshot.exists && snapshot.value != null) {
        AppLogger.info('Successfully accessed users path as fallback');
        return Map<String, dynamic>.from(snapshot.value as Map);
      }

      AppLogger.info('No user data found in database');
      return {};
    } catch (e) {
      AppLogger.error('Error loading users data', error: e);
      return {};
    }
  }

  /// Load ALL quotes for ALL users in one call
  ///
  /// Returns: Map with userId as key, Map of quote data as value
  static Future<Map<String, Map<String, dynamic>>> getAllQuotesData(FirebaseDatabase database) async {
    try {
      final snapshot = await database.ref('quotes').get();

      if (!snapshot.exists || snapshot.value == null) {
        return {};
      }

      final allQuotes = <String, Map<String, dynamic>>{};
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      for (final entry in data.entries) {
        final userId = entry.key;
        final userQuotes = Map<String, dynamic>.from(entry.value as Map);
        allQuotes[userId] = userQuotes;
      }

      AppLogger.info('Loaded quotes for ${allQuotes.length} users');
      return allQuotes;
    } catch (e) {
      AppLogger.error('Error loading all quotes data', error: e);
      return {};
    }
  }

  /// Load ALL clients counts for ALL users in one call
  ///
  /// Returns: Map with userId as key, client count as value
  static Future<Map<String, int>> getAllClientsData(FirebaseDatabase database) async {
    try {
      final snapshot = await database.ref('clients').get();

      if (!snapshot.exists || snapshot.value == null) {
        return {};
      }

      final clientCounts = <String, int>{};
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      for (final entry in data.entries) {
        final userId = entry.key;
        if (entry.value is Map) {
          final userClients = Map<String, dynamic>.from(entry.value as Map);
          clientCounts[userId] = userClients.length;
        }
      }

      AppLogger.info('Loaded client counts for ${clientCounts.length} users');
      return clientCounts;
    } catch (e) {
      AppLogger.error('Error loading all clients data', error: e);
      return {};
    }
  }

  /// Load all data in parallel (users, quotes, clients)
  ///
  /// This is the most efficient way - makes just 3 database calls total
  /// instead of N+1 calls (where N is the number of users)
  static Future<BatchLoadResult> loadAllData(FirebaseDatabase database) async {
    try {
      AppLogger.info('Starting batch data load...', category: LogCategory.performance);
      final stopwatch = Stopwatch()..start();

      // OPTIMIZATION: Load all 3 datasets in parallel
      final results = await Future.wait([
        getUsersData(database),
        getAllQuotesData(database),
        getAllClientsData(database),
      ]);

      stopwatch.stop();
      AppLogger.info(
        'Batch data load completed in ${stopwatch.elapsedMilliseconds}ms',
        category: LogCategory.performance,
      );

      return BatchLoadResult(
        users: results[0] as Map<String, dynamic>,
        allQuotes: results[1] as Map<String, Map<String, dynamic>>,
        clientCounts: results[2] as Map<String, int>,
        loadTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      AppLogger.error('Error in batch data load', error: e);
      return BatchLoadResult.empty();
    }
  }
}

/// Result of batch loading operation
class BatchLoadResult {
  final Map<String, dynamic> users;
  final Map<String, Map<String, dynamic>> allQuotes;
  final Map<String, int> clientCounts;
  final int loadTimeMs;

  const BatchLoadResult({
    required this.users,
    required this.allQuotes,
    required this.clientCounts,
    required this.loadTimeMs,
  });

  factory BatchLoadResult.empty() {
    return const BatchLoadResult(
      users: {},
      allQuotes: {},
      clientCounts: {},
      loadTimeMs: 0,
    );
  }

  bool get isEmpty => users.isEmpty;
  bool get isNotEmpty => users.isNotEmpty;
}
