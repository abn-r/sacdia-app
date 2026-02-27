import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/supabase_constants.dart';
import '../errors/exceptions.dart';
import '../utils/app_logger.dart';


/// Clase para manejar la autenticación con Supabase
class SupabaseAuth {
  static const _tag = 'SupabaseAuth';

  /// Inicializa el cliente Supabase
  static Future<void> initialize() async {
    await supabase.Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
  }

  /// Devuelve la instancia del cliente Supabase
  static supabase.SupabaseClient get client => supabase.Supabase.instance.client;

  /// Devuelve la sesión actual si existe
  static supabase.Session? get currentSession => client.auth.currentSession;

  /// Devuelve el usuario actual si está autenticado
  static supabase.User? get currentUser => client.auth.currentUser;

  /// Verifica si el usuario está autenticado
  static bool get isAuthenticated => currentUser != null;

  /// Inicia sesión con email y contraseña
  static Future<supabase.AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on supabase.AuthException catch (e) {
      throw AuthException(
        message: e.message,
        code: e.statusCode != null ? int.tryParse(e.statusCode!) : null,
      );
    } catch (e) {
      throw AuthException(
        message: e.toString(),
        code: null,
      );
    }
  }

  /// Crea una nueva cuenta con email y contraseña
  static Future<supabase.AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
      return response;
    } on supabase.AuthException catch (e) {
      throw AuthException(
        message: e.message,
        code: e.statusCode != null ? int.tryParse(e.statusCode!) : null,
      );
    } catch (e) {
      throw AuthException(
        message: e.toString(),
        code: null,
      );
    }
  }

  /// Cierra la sesión actual (tanto local como en el servidor)
  static Future<void> signOut() async {
    try {
      await client.auth.signOut(scope: supabase.SignOutScope.global);
      await _forceClearSession();
    } on supabase.AuthException catch (e) {
      await _forceClearSession();
      throw AuthException(
        message: e.message,
        code: e.statusCode != null ? int.tryParse(e.statusCode!) : null,
      );
    } catch (e) {
      await _forceClearSession();
      throw AuthException(
        message: e.toString(),
        code: null,
      );
    }
  }

  /// Método para forzar la eliminación de todos los datos de sesión
  static Future<void> _forceClearSession() async {
    try {
      await client.auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase.auth.token');
      await prefs.remove('supabase.auth.refresh_token');
      await prefs.remove('supabase.auth.access_token');
      await prefs.remove('supabase.auth.expires_at');
      await prefs.remove('supabase.auth.expires_in');
      await prefs.remove('supabase.auth.provider_token');
      await prefs.remove('supabase.auth.provider_refresh_token');
      await prefs.remove('supabase.auth.user');

      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.contains('supabase.auth')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      AppLogger.e('Error al limpiar datos de sesión', tag: _tag, error: e);
    }
  }

  /// Envía email de recuperación de contraseña
  static Future<void> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
    } on supabase.AuthException catch (e) {
      throw AuthException(
        message: e.message,
        code: e.statusCode != null ? int.tryParse(e.statusCode!) : null,
      );
    } catch (e) {
      throw AuthException(
        message: e.toString(),
        code: null,
      );
    }
  }

  /// Actualiza contraseña del usuario
  static Future<supabase.UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await client.auth.updateUser(
        supabase.UserAttributes(
          password: newPassword,
        ),
      );
      return response;
    } on supabase.AuthException catch (e) {
      throw AuthException(
        message: e.message,
        code: e.statusCode != null ? int.tryParse(e.statusCode!) : null,
      );
    } catch (e) {
      throw AuthException(
        message: e.toString(),
        code: null,
      );
    }
  }

  /// Stream para escuchar cambios en el estado de autenticación
  static Stream<supabase.AuthState> get onAuthStateChange =>
      client.auth.onAuthStateChange;
}
