import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/secure_storage.dart';

/// Provider para la instancia de SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider debe ser anulado durante la inicialización');
});

/// Provider para el almacenamiento local
final localStorageProvider = Provider<LocalStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesStorage(prefs);
});

/// Provider para el almacenamiento seguro
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorageImpl();
});
