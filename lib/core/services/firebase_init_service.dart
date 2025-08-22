import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'app_logger.dart';

class FirebaseInitService {
  static final FirebaseInitService _instance = FirebaseInitService._internal();
  factory FirebaseInitService() => _instance;
  FirebaseInitService._internal();

  bool _isInitialized = false;
  bool _isConnected = false;
  final _initCompleter = Completer<void>();
  
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  Future<void> get initComplete => _initCompleter.future;

  /// Initialize Firebase and wait for connection
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final database = FirebaseDatabase.instance;
      
      // Force database to go online
      database.goOnline();
      
      // Set up connection listener
      database.ref('.info/connected').onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        _isConnected = connected;
        AppLogger.info('Firebase connection status: $connected');
        
        if (connected && !_initCompleter.isCompleted) {
          _initCompleter.complete();
        }
      });
      
      // Try to establish connection by reading a simple value
      await _establishConnection();
      
      _isInitialized = true;
      
      // If not connected after 5 seconds, complete anyway to avoid blocking
      Future.delayed(const Duration(seconds: 5), () {
        if (!_initCompleter.isCompleted) {
          AppLogger.warning('Firebase initialization timeout - completing anyway');
          _initCompleter.complete();
        }
      });
      
    } catch (e) {
      AppLogger.error('Failed to initialize Firebase', error: e);
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Force a connection attempt
  Future<void> _establishConnection() async {
    try {
      // Try to read server time to establish connection
      final database = FirebaseDatabase.instance;
      final serverTime = await database.ref('/.info/serverTimeOffset').once();
      AppLogger.debug('Server time offset: ${serverTime.snapshot.value}');
      
      // Also try to warm up the products path
      final productsRef = database.ref('products');
      await productsRef.limitToFirst(1).once();
      
    } catch (e) {
      AppLogger.debug('Connection establishment attempt failed (expected on first try)', error: e);
    }
  }

  /// Force refresh of data
  Future<void> forceRefresh() async {
    try {
      final database = FirebaseDatabase.instance;
      
      // Go offline and online to force refresh
      database.goOffline();
      await Future.delayed(const Duration(milliseconds: 100));
      database.goOnline();
      
      await _establishConnection();
      
    } catch (e) {
      AppLogger.error('Failed to force refresh', error: e);
    }
  }

  /// Wait for authentication and then ensure connection
  Future<void> waitForAuth() async {
    try {
      // Wait for auth state
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      
      if (user == null) {
        // Wait for sign in
        await auth.authStateChanges().first;
      }
      
      // Ensure we're connected after auth
      if (!_isConnected) {
        await _establishConnection();
      }
      
    } catch (e) {
      AppLogger.error('Error waiting for auth', error: e);
    }
  }
}