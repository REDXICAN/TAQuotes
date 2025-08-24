// lib/core/services/csrf_protection_service.dart
// CSRF (Cross-Site Request Forgery) protection service

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import '../config/env_config.dart';

class CsrfProtectionService {
  static final CsrfProtectionService _instance = CsrfProtectionService._internal();
  factory CsrfProtectionService() => _instance;
  CsrfProtectionService._internal();

  static const String _csrfBoxName = 'csrf_tokens';
  static const String _csrfTokenKey = 'csrf_token';
  static const String _csrfSessionKey = 'csrf_session';
  static const int _tokenLength = 32;
  static const Duration _tokenExpiration = Duration(hours: 4);

  Box? _csrfBox;
  String? _currentToken;
  DateTime? _tokenGeneratedAt;

  /// Initialize the CSRF protection service
  Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_csrfBoxName)) {
        _csrfBox = await Hive.openBox(_csrfBoxName);
      } else {
        _csrfBox = Hive.box(_csrfBoxName);
      }
      
      // Load existing token if valid
      await _loadExistingToken();
      
      // Generate new token if needed
      if (_currentToken == null || _isTokenExpired()) {
        await generateNewToken();
      }
    } catch (e) {
      print('Error initializing CSRF protection: $e');
      // Generate in-memory token as fallback
      _currentToken = _generateRandomToken();
      _tokenGeneratedAt = DateTime.now();
    }
  }

  /// Get the current CSRF token
  String? get currentToken => _currentToken;

  /// Generate a new CSRF token
  Future<String> generateNewToken() async {
    _currentToken = _generateRandomToken();
    _tokenGeneratedAt = DateTime.now();
    
    // Store token persistently
    await _storeToken();
    
    return _currentToken!;
  }

  /// Verify a CSRF token
  bool verifyToken(String? token) {
    if (token == null || _currentToken == null) {
      return false;
    }
    
    // Check if token is expired
    if (_isTokenExpired()) {
      return false;
    }
    
    // Constant-time comparison to prevent timing attacks
    return _constantTimeCompare(token, _currentToken!);
  }

  /// Validate a request with CSRF token
  CsrfValidationResult validateRequest({
    required String? providedToken,
    required String requestMethod,
    required String? origin,
    required String? referer,
    List<String>? allowedOrigins,
  }) {
    // Skip CSRF check for safe methods
    if (_isSafeMethod(requestMethod)) {
      return CsrfValidationResult(
        isValid: true,
        reason: 'Safe HTTP method',
      );
    }

    // Check token presence
    if (providedToken == null || providedToken.isEmpty) {
      return CsrfValidationResult(
        isValid: false,
        reason: 'CSRF token missing',
        shouldRegenerateToken: true,
      );
    }

    // Check if token is expired
    if (_isTokenExpired()) {
      return CsrfValidationResult(
        isValid: false,
        reason: 'CSRF token expired',
        shouldRegenerateToken: true,
      );
    }

    // Verify token
    if (!verifyToken(providedToken)) {
      return CsrfValidationResult(
        isValid: false,
        reason: 'Invalid CSRF token',
        shouldRegenerateToken: false,
      );
    }

    // Additional origin checking for web platforms
    if (origin != null || referer != null) {
      final isOriginValid = _validateOrigin(
        origin: origin,
        referer: referer,
        allowedOrigins: allowedOrigins ?? _defaultAllowedOrigins,
      );
      
      if (!isOriginValid) {
        return CsrfValidationResult(
          isValid: false,
          reason: 'Origin/Referer validation failed',
          shouldRegenerateToken: false,
        );
      }
    }

    return CsrfValidationResult(
      isValid: true,
      reason: 'CSRF validation passed',
    );
  }

  /// Generate token for inclusion in forms/requests
  Map<String, String> getTokenHeaders() {
    if (_currentToken == null || _isTokenExpired()) {
      generateNewToken();
    }
    
    return {
      'X-CSRF-Token': _currentToken!,
      'X-Requested-With': 'XMLHttpRequest',
    };
  }

  /// Generate HTML meta tag for web
  String getMetaTag() {
    if (_currentToken == null || _isTokenExpired()) {
      generateNewToken();
    }
    
    return '<meta name="csrf-token" content="$_currentToken">';
  }

  /// Generate hidden form field
  String getFormField() {
    if (_currentToken == null || _isTokenExpired()) {
      generateNewToken();
    }
    
    return '<input type="hidden" name="csrf_token" value="$_currentToken">';
  }

  /// Rotate token (call after successful authentication)
  Future<String> rotateToken() async {
    return await generateNewToken();
  }

  /// Clear token (call on logout)
  Future<void> clearToken() async {
    _currentToken = null;
    _tokenGeneratedAt = null;
    
    if (_csrfBox != null && _csrfBox!.isOpen) {
      await _csrfBox!.delete(_csrfTokenKey);
      await _csrfBox!.delete(_csrfSessionKey);
    }
  }

  // Private helper methods

  String _generateRandomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(_tokenLength, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  bool _isTokenExpired() {
    if (_tokenGeneratedAt == null) return true;
    return DateTime.now().difference(_tokenGeneratedAt!) > _tokenExpiration;
  }

  Future<void> _storeToken() async {
    if (_csrfBox != null && _csrfBox!.isOpen) {
      await _csrfBox!.put(_csrfTokenKey, _currentToken);
      await _csrfBox!.put(_csrfSessionKey, _tokenGeneratedAt?.toIso8601String());
    }
  }

  Future<void> _loadExistingToken() async {
    if (_csrfBox != null && _csrfBox!.isOpen) {
      _currentToken = _csrfBox!.get(_csrfTokenKey);
      final sessionStr = _csrfBox!.get(_csrfSessionKey);
      if (sessionStr != null) {
        _tokenGeneratedAt = DateTime.tryParse(sessionStr);
      }
    }
  }

  bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    
    var result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  bool _isSafeMethod(String method) {
    const safeMethods = ['GET', 'HEAD', 'OPTIONS', 'TRACE'];
    return safeMethods.contains(method.toUpperCase());
  }

  bool _validateOrigin({
    String? origin,
    String? referer,
    required List<String> allowedOrigins,
  }) {
    // If no origin or referer, reject for state-changing operations
    if (origin == null && referer == null) {
      return false;
    }
    
    // Check origin first
    if (origin != null) {
      return allowedOrigins.any((allowed) => 
        origin.startsWith(allowed) || allowed == '*');
    }
    
    // Fall back to referer
    if (referer != null) {
      return allowedOrigins.any((allowed) => 
        referer.startsWith(allowed) || allowed == '*');
    }
    
    return false;
  }

  List<String> get _defaultAllowedOrigins => [
    'https://taquotes.web.app',
    'https://taquotes.firebaseapp.com',
    'http://localhost',
    'http://127.0.0.1',
  ];

  /// Generate a double-submit cookie token
  DoubleSubmitToken generateDoubleSubmitToken() {
    final token = _generateRandomToken();
    final signature = _signToken(token);
    
    return DoubleSubmitToken(
      token: token,
      signature: signature,
      cookieValue: '$token.$signature',
    );
  }

  /// Verify double-submit cookie token
  bool verifyDoubleSubmitToken(String cookieValue, String headerToken) {
    final parts = cookieValue.split('.');
    if (parts.length != 2) return false;
    
    final token = parts[0];
    final signature = parts[1];
    
    // Verify signature
    if (_signToken(token) != signature) return false;
    
    // Compare with header token
    return _constantTimeCompare(token, headerToken);
  }

  String _signToken(String token) {
    // Load secret key from environment configuration
    // This keeps the secret out of source code
    final secret = EnvConfig.csrfSecretKey;
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(token));
    return digest.toString();
  }
}

// Supporting classes

class CsrfValidationResult {
  final bool isValid;
  final String reason;
  final bool shouldRegenerateToken;

  CsrfValidationResult({
    required this.isValid,
    required this.reason,
    this.shouldRegenerateToken = false,
  });
}

class DoubleSubmitToken {
  final String token;
  final String signature;
  final String cookieValue;

  DoubleSubmitToken({
    required this.token,
    required this.signature,
    required this.cookieValue,
  });
}

// CSRF Middleware for HTTP requests
class CsrfMiddleware {
  final CsrfProtectionService _csrfService = CsrfProtectionService();

  /// Add CSRF token to request headers
  Map<String, String> addCsrfHeaders(Map<String, String> headers) {
    final csrfHeaders = _csrfService.getTokenHeaders();
    return {...headers, ...csrfHeaders};
  }

  /// Validate incoming request
  Future<bool> validateRequest({
    required String method,
    required Map<String, String> headers,
    String? origin,
    String? referer,
  }) async {
    final token = headers['X-CSRF-Token'] ?? headers['x-csrf-token'];
    
    final result = _csrfService.validateRequest(
      providedToken: token,
      requestMethod: method,
      origin: origin ?? headers['Origin'] ?? headers['origin'],
      referer: referer ?? headers['Referer'] ?? headers['referer'],
    );
    
    if (result.shouldRegenerateToken) {
      await _csrfService.generateNewToken();
    }
    
    return result.isValid;
  }
}