import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth.dart';

/// Provider para el estado de autenticación actual
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseAuth.onAuthStateChange;
});

/// Provider para el usuario autenticado actual
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).asData?.value;
  return authState?.session?.user;
});

/// Provider para verificar si el usuario está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
