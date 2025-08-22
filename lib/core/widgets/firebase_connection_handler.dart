import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_init_service.dart';
import '../services/app_logger.dart';

/// Provider for Firebase connection status
final firebaseConnectionProvider = StreamProvider<bool>((ref) {
  return FirebaseDatabase.instance
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value as bool? ?? false);
});

/// Widget that handles Firebase connection and shows appropriate UI
class FirebaseConnectionHandler extends ConsumerStatefulWidget {
  final Widget child;
  final bool showConnectionStatus;
  
  const FirebaseConnectionHandler({
    super.key,
    required this.child,
    this.showConnectionStatus = true,
  });

  @override
  ConsumerState<FirebaseConnectionHandler> createState() => _FirebaseConnectionHandlerState();
}

class _FirebaseConnectionHandlerState extends ConsumerState<FirebaseConnectionHandler> {
  bool _hasConnectedOnce = false;
  int _retryCount = 0;
  
  @override
  void initState() {
    super.initState();
    _checkConnection();
  }
  
  Future<void> _checkConnection() async {
    final firebaseInit = FirebaseInitService();
    
    // Wait for initial connection
    await firebaseInit.initComplete;
    
    if (!mounted) return;
    
    setState(() {
      _hasConnectedOnce = true;
    });
  }
  
  Future<void> _retryConnection() async {
    setState(() {
      _retryCount++;
    });
    
    AppLogger.info('Retrying Firebase connection (attempt $_retryCount)');
    
    final firebaseInit = FirebaseInitService();
    await firebaseInit.forceRefresh();
    
    // Give it a moment to establish connection
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Check if we're connected now
    final database = FirebaseDatabase.instance;
    final snapshot = await database.ref('.info/connected').once();
    final isConnected = snapshot.snapshot.value as bool? ?? false;
    
    if (isConnected) {
      setState(() {
        _hasConnectedOnce = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(firebaseConnectionProvider);
    
    return connectionAsync.when(
      data: (isConnected) {
        // If connected or has connected once, show the child
        if (isConnected || _hasConnectedOnce) {
          return Stack(
            children: [
              widget.child,
              if (widget.showConnectionStatus && !isConnected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    child: Container(
                      color: Colors.orange.shade100,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Working offline - Changes will sync when reconnected',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                          TextButton(
                            onPressed: _retryConnection,
                            child: const Text('Retry', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        
        // Not connected and never has been - show connection screen
        return Scaffold(
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connecting to server...',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _retryConnection,
                    icon: const Icon(Icons.refresh),
                    label: Text('Retry Connection (Attempt $_retryCount)'),
                  ),
                  if (_retryCount > 2) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _hasConnectedOnce = true;
                        });
                      },
                      child: const Text('Continue Offline'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Firebase...'),
            ],
          ),
        ),
      ),
      error: (error, stack) {
        AppLogger.error('Firebase connection error', error: error);
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to connect to Firebase'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retryConnection,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}