import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin to add auto-refresh capability to any ConsumerStatefulWidget
mixin AutoRefreshMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _refreshTimer;
  Duration refreshInterval = const Duration(seconds: 30);

  /// Override this to specify which providers to refresh
  List<ProviderBase> get providersToRefresh => [];

  /// Override this to customize refresh behavior
  void onRefresh() {
    for (final provider in providersToRefresh) {
      if (provider is StateNotifierProvider) {
        // Force refresh by invalidating the provider
        ref.invalidate(provider);
      } else if (provider is FutureProvider) {
        // Refresh future providers
        ref.invalidate(provider);
      } else if (provider is StreamProvider) {
        // Stream providers auto-refresh, but we can force it
        ref.invalidate(provider);
      }
    }
  }

  void startAutoRefresh([Duration? customInterval]) {
    stopAutoRefresh();
    refreshInterval = customInterval ?? refreshInterval;
    _refreshTimer = Timer.periodic(refreshInterval, (_) => onRefresh());
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void initState() {
    super.initState();
    // Start auto-refresh on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startAutoRefresh();
    });
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

/// Extension to convert FutureProvider to auto-refreshing StreamProvider
extension AutoRefreshProvider on Ref {
  /// Creates a stream that refreshes at specified interval
  Stream<T> autoRefreshStream<T>(
    Future<T> Function() fetcher, {
    Duration interval = const Duration(seconds: 30),
    bool immediate = true,
  }) {
    final periodicStream = Stream.periodic(interval, (_) => null)
        .asyncMap((_) => fetcher());

    if (immediate) {
      // Emit initial value immediately, then continue with periodic updates
      return Stream.fromFuture(fetcher()).followedBy(periodicStream);
    } else {
      return periodicStream;
    }
  }
}

/// Helper to convert FutureProvider to StreamProvider with auto-refresh
StreamProvider<T> createAutoRefreshingProvider<T>({
  required Future<T> Function(Ref ref) fetcher,
  Duration refreshInterval = const Duration(seconds: 30),
}) {
  return StreamProvider<T>((ref) async* {
    // Initial fetch
    yield await fetcher(ref);

    // Periodic refresh
    await for (final _ in Stream.periodic(refreshInterval)) {
      yield await fetcher(ref);
    }
  });
}

/// Provider to manage global refresh state
final globalRefreshProvider = StateNotifierProvider<GlobalRefreshNotifier, DateTime>(
  (ref) => GlobalRefreshNotifier(),
);

class GlobalRefreshNotifier extends StateNotifier<DateTime> {
  GlobalRefreshNotifier() : super(DateTime.now());

  void refresh() {
    state = DateTime.now();
  }
}

/// Helper to force refresh all providers
void forceRefreshAll(WidgetRef ref) {
  ref.read(globalRefreshProvider.notifier).refresh();

  // Add specific providers to refresh here
  ref.invalidate(enhancedProductsProvider);
  ref.invalidate(clientsStreamProvider);
  ref.invalidate(quotesStreamProvider);
  ref.invalidate(pendingUserApprovalsProvider);
  // Add more providers as needed
}

// Import these providers from their respective files
final enhancedProductsProvider = StreamProvider<List<dynamic>>((ref) {
  throw UnimplementedError('Import from enhanced_providers.dart');
});

final clientsStreamProvider = StreamProvider<List<dynamic>>((ref) {
  throw UnimplementedError('Import from client_providers.dart');
});

final quotesStreamProvider = StreamProvider<List<dynamic>>((ref) {
  throw UnimplementedError('Import from quote_providers.dart');
});

final pendingUserApprovalsProvider = StreamProvider<List<dynamic>>((ref) {
  throw UnimplementedError('Import from user_approvals_widget.dart');
});