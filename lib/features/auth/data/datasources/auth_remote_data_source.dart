import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_model.dart';

/// Interfaz para la fuente de datos remota de autenticación
abstract class AuthRemoteDataSource {
  /// Stream que emite el estado de autenticación del usuario
  Stream<bool> get authStateChanges;

  /// Obtiene el usuario actual
  Future<UserModel?> getCurrentUser();

  /// Inicia sesión con email y contraseña
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registra un nuevo usuario con email y contraseña
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
  });

  /// Cierra la sesión del usuario
  Future<void> signOut();

  /// Envía un correo de recuperación de contraseña
  Future<void> resetPassword(String email);

  /// Actualiza la contraseña del usuario
  Future<UserModel> updatePassword(String newPassword);

  /// Inicia sesión con Google OAuth
  Future<UserModel> signInWithGoogle();

  /// Inicia sesión con Apple OAuth
  Future<UserModel> signInWithApple();

  /// Obtiene el estado de completitud del post-registro
  Future<bool> getCompletionStatus();

  /// Verifica si hay un token guardado localmente (sin llamar al API)
  Future<bool> hasLocalToken();

  /// Cambia el contexto activo de autorización del usuario.
  /// Llama a PATCH /auth/me/context con el assignment_id indicado.
  Future<void> switchContext(String assignmentId);
}

/// Implementación de la fuente de datos remota con Dio para API personalizada
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final StreamController<bool> _authStateController;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'AuthDS';
  bool _attemptedContextAutoActivation = false;

  AuthRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _authStateController = StreamController<bool>.broadcast(),
        _secureStorage = const FlutterSecureStorage() {
    _checkInitialAuthState();
  }

  /// Verifica el estado inicial de autenticación usando solo almacenamiento local.
  /// No realiza llamadas de red — AuthNotifier.build() ya valida el token
  /// contra la API mediante getCurrentUser(). Este método solo alimenta el
  /// stream authStateChanges con un valor inicial sin generar tráfico HTTP.
  Future<void> _checkInitialAuthState() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      _authStateController.add(token != null);
    } catch (e) {
      AppLogger.w('Error al leer token local en estado inicial',
          tag: _tag, error: e);
      _authStateController.add(false);
    }
  }

  Future<void> _saveToken(
    String token, {
    String? refreshToken,
    int? expiresAt,
    String? tokenType,
  }) async {
    await _secureStorage.write(key: 'auth_token', value: token);
    if (refreshToken != null) {
      await _secureStorage.write(
          key: 'auth_refresh_token', value: refreshToken);
    }
    if (expiresAt != null) {
      await _secureStorage.write(
          key: 'auth_expires_at', value: expiresAt.toString());
    }
    if (tokenType != null) {
      await _secureStorage.write(key: 'auth_token_type', value: tokenType);
    }
    _authStateController.add(true);
  }

  Future<void> _clearToken() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'auth_refresh_token');
    await _secureStorage.delete(key: 'auth_expires_at');
    await _secureStorage.delete(key: 'auth_token_type');
    _authStateController.add(false);
  }

  bool? _parseBool(dynamic rawValue) {
    if (rawValue is bool) return rawValue;
    if (rawValue is num) return rawValue != 0;
    if (rawValue is String) {
      final value = rawValue.trim().toLowerCase();
      if (value == 'true' || value == '1' || value == 'yes') return true;
      if (value == 'false' || value == '0' || value == 'no') return false;
    }
    return null;
  }

  Future<void> _persistCompletionCache(bool value) async {
    await _secureStorage.write(
      key: 'cached_post_register_complete',
      value: value.toString(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cached_post_register_complete', value);
  }

  Future<bool> _readCompletionCache() async {
    final prefs = await SharedPreferences.getInstance();
    final sharedValue = prefs.getBool('cached_post_register_complete');
    if (sharedValue != null) {
      return sharedValue;
    }
    final secureValue = await _secureStorage.read(
      key: 'cached_post_register_complete',
    );
    return _parseBool(secureValue) ?? false;
  }

  Future<bool?> _fetchCompletionStatus(String token) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/auth/profile/completion-status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      if (response.data is! Map<String, dynamic>) {
        return null;
      }

      final body = response.data as Map<String, dynamic>;
      final nested = body['data'];
      final rawComplete = nested is Map<String, dynamic>
          ? nested['complete']
          : body['complete'];

      return _parseBool(rawComplete);
    } catch (e) {
      AppLogger.w(
        'No se pudo consultar /auth/profile/completion-status como fallback',
        tag: _tag,
        error: e,
      );
      return null;
    }
  }

  Future<bool> _activateAuthorizationContext(
    String token,
    String assignmentId,
  ) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl/auth/me/context',
        data: {'assignment_id': assignmentId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      AppLogger.w(
        'No se pudo activar contexto RBAC canonico',
        tag: _tag,
        error: e,
      );
      return false;
    }
  }

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) return null;

      final response = await _dio.get(
        '$_baseUrl/auth/me',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseBody;
        if (response.data is Map<String, dynamic>) {
          responseBody = response.data as Map<String, dynamic>;
        } else {
          AppLogger.w(
              'Respuesta inesperada de /auth/me: ${response.data.runtimeType}',
              tag: _tag);
          return null;
        }

        // The nested user payload lives under 'data'; fall back to root level.
        final Map<String, dynamic> userData;
        final nestedData = responseBody['data'];
        if (nestedData is Map<String, dynamic>) {
          userData = nestedData;
        } else {
          userData = responseBody;
        }

        // 'post_register_complete' may sit at the root envelope OR inside 'data'.
        // Check both explicitly and cast safely so a missing field never silently
        // defaults to false when the user has actually completed post-registration.
        final dynamic rawFlag = responseBody['post_register_complete'] ??
            userData['post_register_complete'];
        final bool postRegisterComplete;
        final parsedFlag = _parseBool(rawFlag);
        if (parsedFlag != null) {
          postRegisterComplete = parsedFlag;
        } else {
          final completionFromApi = await _fetchCompletionStatus(token);
          if (completionFromApi != null) {
            postRegisterComplete = completionFromApi;
            AppLogger.i(
              'post_register_complete ausente en /auth/me; usando /auth/profile/completion-status: $postRegisterComplete',
              tag: _tag,
            );
          } else {
            // Last-resort fallback: cached value to avoid forcing user back to
            // post-registration when the API field is temporarily missing.
            postRegisterComplete = await _readCompletionCache();
            AppLogger.w(
              'post_register_complete ausente en /auth/me y completion-status no disponible; usando caché: $postRegisterComplete',
              tag: _tag,
            );
          }
        }

        await _persistCompletionCache(postRegisterComplete);

        final user = UserModel.fromCustomApi(
          userData,
          postRegisterComplete: postRegisterComplete,
        );

        if (user.authorization?.hasCanonicalPermissions ?? false) {
          AppLogger.i('rbac_canonical_used', tag: _tag);
        } else if ((user.metadata?['permissions']) is List ||
            (user.metadata?['roles']) is List) {
          AppLogger.w('rbac_legacy_fallback_used', tag: _tag);
        }

        final hasActiveAssignment =
            (user.authorization?.activeAssignmentId?.trim().isNotEmpty ??
                false);

        String? fallbackAssignmentId;
        if (!hasActiveAssignment) {
          for (final grant in user.authorization?.clubAssignments ?? const []) {
            final candidate = grant.assignmentId?.trim();
            if (candidate != null && candidate.isNotEmpty) {
              fallbackAssignmentId = candidate;
              break;
            }
          }
        }

        if (!_attemptedContextAutoActivation &&
            !hasActiveAssignment &&
            fallbackAssignmentId != null) {
          _attemptedContextAutoActivation = true;
          final contextActivated = await _activateAuthorizationContext(
            token,
            fallbackAssignmentId,
          );

          if (contextActivated) {
            final refreshedUser = await getCurrentUser();
            _attemptedContextAutoActivation = false;
            return refreshedUser;
          }

          _attemptedContextAutoActivation = false;
        }

        return user;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger.w('Token inválido (${response.statusCode}), limpiando sesión',
            tag: _tag);
        await _clearToken();
      }

      return null;
    } catch (e) {
      AppLogger.e('Error al obtener usuario actual', tag: _tag, error: e);
      if (e is DioException && e.response?.statusCode == 401) {
        await _clearToken();
      }
      return null;
    }
  }

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.i('Login: $email', tag: _tag);

      final response = await _dio.post('$_baseUrl/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
            message: response.data['message'] ?? 'Error de autenticación');
      }

      final responseData = response.data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        throw AuthException(message: 'Respuesta del servidor inválida');
      }

      final token = responseData['accessToken'] as String?;
      if (token == null) {
        throw AuthException(message: 'No se recibió token de autenticación');
      }

      final refreshToken = responseData['refreshToken'] as String?;
      final expiresAt = responseData['expiresAt'] as int?;
      final tokenType = responseData['tokenType'] as String?;
      await _saveToken(
        token,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        tokenType: tokenType,
      );

      final userData = responseData['user'] as Map<String, dynamic>?;
      final userId = userData?['id'] as String?;
      if (userId == null) {
        throw AuthException(message: 'No se recibió ID de usuario');
      }

      final needsPostRegistration =
          responseData['needsPostRegistration'] as bool? ?? true;

      AppLogger.i('Login exitoso: $email', tag: _tag);
      return UserModel(
        id: userId,
        email: userData?['email'] as String? ?? email,
        name: userData?['name'] as String? ?? '',
        postRegisterComplete: !needsPostRegistration,
      );
    } catch (e) {
      AppLogger.e('Error en login', tag: _tag, error: e);
      if (e is DioException) {
        throw AuthException(message: e.message ?? 'Error de conexión');
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
  }) async {
    try {
      AppLogger.i('Registro: $email', tag: _tag);

      final response = await _dio.post('$_baseUrl/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'paternal_last_name': paternalSurname,
        'maternal_last_name': maternalSurname,
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
          message: response.data['message'] ?? 'Error en el registro',
        );
      }

      final userData = response.data['user'] as Map<String, dynamic>?;
      final userId = userData?['id'] as String?;

      if (userId == null) {
        throw AuthException(message: 'No se recibió ID de usuario');
      }

      AppLogger.i('Usuario registrado: $userId', tag: _tag);
      return UserModel(
        id: userId,
        email: userData?['email'] as String? ?? email,
        name: userData?['name'] as String? ?? name,
        postRegisterComplete: false,
      );
    } catch (e) {
      AppLogger.e('Error en registro', tag: _tag, error: e);
      if (e is DioException) {
        final message =
            e.response?.data?['message'] ?? e.message ?? 'Error de conexión';
        throw AuthException(message: message);
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    AppLogger.i('Cerrando sesión', tag: _tag);

    // Read tokens before clearing — needed to notify the server.
    final token = await _secureStorage.read(key: 'auth_token');
    final refreshToken = await _secureStorage.read(key: 'auth_refresh_token');

    // Always clear local state first, regardless of network outcome.
    await _clearToken();
    await _clearAllPersistentData();

    // Best-effort server invalidation: send whatever tokens we have.
    // The backend responds 200 even with an expired access token (fail-safe).
    try {
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = <String, dynamic>{};
      if (refreshToken != null && refreshToken.isNotEmpty) {
        body['refreshToken'] = refreshToken;
      }

      await _dio.post(
        '$_baseUrl/auth/logout',
        data: body.isNotEmpty ? body : null,
        options: Options(
          headers: headers.isNotEmpty ? headers : null,
          // Do not throw on non-2xx — any response means server acknowledged.
          validateStatus: (status) => status != null,
        ),
      );
      AppLogger.i('Logout notificado al servidor', tag: _tag);
    } catch (e) {
      // Network error is acceptable; local state is already cleared.
      AppLogger.w('Logout: no se pudo contactar el servidor',
          tag: _tag, error: e);
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      AppLogger.i('Recuperación de contraseña: $email', tag: _tag);

      final response = await _dio.post(
        '$_baseUrl/auth/request-password-reset',
        data: {'email': email},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.i('Correo de recuperación enviado', tag: _tag);
      }
    } catch (e) {
      AppLogger.e('Error en reset password', tag: _tag, error: e);
      if (e is DioException) {
        throw AuthException(
          message: e.response?.data?['message'] ??
              'Si el correo existe, recibirás un enlace de recuperación',
        );
      }
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<UserModel> updatePassword(String newPassword) async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        throw AuthException(message: 'No hay sesión activa');
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      await _dio.post('$_baseUrl/auth/update-password', data: {
        'password': newPassword,
      });

      return UserModel(
        id: 'current-user-id',
        email: 'usuario@ejemplo.com',
        name: 'Usuario Actual',
        postRegisterComplete: true,
      );
    } catch (e) {
      if (e is DioException) {
        throw AuthException(
            message: e.message ?? 'Error al actualizar contraseña');
      }
      throw AuthException(message: e.toString());
    }
  }

  Future<void> _clearAllPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keysToRemove = [
        'auth-token',
        'auth-refresh-token',
        'auth-type',
        // Legacy snake_case keys — remove during migration window.
        'refresh_token',
      ];

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.contains('auth')) {
          await prefs.remove(key);
        }
      }

      final secureKeys = await _secureStorage.readAll();
      for (final entry in secureKeys.entries) {
        if (entry.key.contains('auth')) {
          await _secureStorage.delete(key: entry.key);
        }
      }
    } catch (e) {
      AppLogger.e('Error al limpiar datos persistentes', tag: _tag, error: e);
    }
  }

  // ── OAuth ─────────────────────────────────────────────────────────────────────
  //
  // El flujo OAuth en móvil es redirect-based, no síncrono:
  //   1. signInWithOAuth() abre el navegador del sistema.
  //   2. El usuario autoriza y Supabase redirige al URL scheme de la app
  //      (ej. "io.sacdia.app://auth/callback") con access_token en la URL.
  //   3. El router intercepta el deep link → extrae el token → llama a
  //      GET /auth/oauth/callback?access_token=... en el backend → recibe
  //      el JWT interno de SACDIA → _saveToken() → AuthNotifier se refresca.
  //
  // Prerequisitos de configuración (fuera de este archivo):
  //   - ios/Runner/Info.plist: CFBundleURLSchemes → "io.sacdia.app"
  //   - android/app/src/main/AndroidManifest.xml: intent-filter con scheme
  //   - Supabase Dashboard → Auth → URL Configuration → Redirect URLs:
  //       io.sacdia.app://auth/callback
  //   - Google OAuth habilitado en Supabase Dashboard
  //   - Apple: Services ID + Key + "Sign In with Apple" capability en Xcode
  //
  // Referencia: https://supabase.com/docs/guides/auth/social-login?platform=flutter

  static const _oauthRedirectUrl = 'io.sacdia.app://auth/callback';

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      AppLogger.i('Iniciando OAuth con Google', tag: _tag);
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.platformDefault,
      );

      if (!launched) {
        throw AuthException(
          message: 'No se pudo abrir el navegador para autenticación con Google',
        );
      }

      // El resultado llega de forma asíncrona a través del deep link.
      // El caller (AuthNotifier) debe escuchar authStateChanges o manejar el
      // callback desde el router. Lanzamos una excepción especializada para
      // indicar que el flujo fue iniciado y no falló.
      throw OAuthFlowInitiatedException(provider: 'Google');
    } on OAuthFlowInitiatedException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      AppLogger.e('Error iniciando OAuth Google', tag: _tag, error: e);
      throw AuthException(
        message: 'Error al iniciar sesión con Google. Intenta de nuevo.',
      );
    }
  }

  @override
  Future<UserModel> signInWithApple() async {
    try {
      AppLogger.i('Iniciando OAuth con Apple', tag: _tag);
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.platformDefault,
      );

      if (!launched) {
        throw AuthException(
          message: 'No se pudo abrir el navegador para autenticación con Apple',
        );
      }

      throw OAuthFlowInitiatedException(provider: 'Apple');
    } on OAuthFlowInitiatedException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      AppLogger.e('Error iniciando OAuth Apple', tag: _tag, error: e);
      throw AuthException(
        message: 'Error al iniciar sesión con Apple. Intenta de nuevo.',
      );
    }
  }

  @override
  Future<bool> hasLocalToken() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      return token != null;
    } catch (e) {
      AppLogger.e('Error al verificar token local', tag: _tag, error: e);
      return false;
    }
  }

  @override
  Future<void> switchContext(String assignmentId) async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) {
      throw AuthException(message: 'No hay sesión activa');
    }

    final response = await _dio.patch(
      '$_baseUrl/auth/me/context',
      data: {'assignment_id': assignmentId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(
        message: response.data?['message'] ?? 'Error al cambiar contexto',
      );
    }
  }

  @override
  Future<bool> getCompletionStatus() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        throw AuthException(message: 'No hay sesión activa');
      }

      final response = await _dio.get(
        '$_baseUrl/auth/profile/completion-status',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>?;
        return data?['complete'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      if (e is DioException) {
        throw AuthException(
          message: e.message ?? 'Error al verificar estado de completitud',
        );
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }
}
