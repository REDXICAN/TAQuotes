// lib/core/providers/client_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// Selected client provider - used across the app
final selectedClientProvider = StateProvider<Client?>((ref) => null);

// Cart client provider - separate but will sync with selectedClientProvider
final cartClientProvider = StateProvider<Client?>((ref) => null);