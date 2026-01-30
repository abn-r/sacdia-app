import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/supabase_auth.dart';

/// Provider para la instancia de SupabaseClient
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return SupabaseAuth.client;
});
