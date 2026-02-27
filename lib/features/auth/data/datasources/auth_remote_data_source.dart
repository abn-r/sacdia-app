import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
}

/// Implementación de la fuente de datos remota con Dio para API personalizada
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final StreamController<bool> _authStateController;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'AuthDS';

  AuthRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _authStateController = StreamController<bool>.broadcast(),
        _secureStorage = const FlutterSecureStorage() {
    _checkInitialAuthState();
  }

  /// Verificar el estado inicial de autenticación validando el token contra la API
  Future<void> _checkInitialAuthState() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');

      if (token == null) {
        AppLogger.i('Sin token local, usuario no autenticado', tag: _tag);
        _authStateController.add(false);
        return;
      }

      AppLogger.i('Token encontrado, validando con el servidor', tag: _tag);
      final response = await _dio.get(
        '$_baseUrl/auth/me',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.i('Token válido, usuario autenticado', tag: _tag);
        _authStateController.add(true);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger.w(
            'Token expirado/inválido (${response.statusCode}), limpiando sesión',
            tag: _tag);
        await _clearToken();
      } else {
        AppLogger.w(
            'Error de servidor (${response.statusCode}), conservando token',
            tag: _tag);
      }
    } catch (e) {
      if (e is AuthException) {
        AppLogger.w('AuthException en estado inicial, limpiando tokens',
            tag: _tag, error: e);
        await _clearToken();
      } else {
        AppLogger.w('Error de red al verificar estado inicial',
            tag: _tag, error: e);
        _authStateController.add(false);
      }
    }
  }

  Future<void> _saveToken(String token, {String? refreshToken}) async {
    await _secureStorage.write(key: 'auth_token', value: token);
    if (refreshToken != null) {
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    }
    _authStateController.add(true);
  }

  Future<void> _clearToken() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
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

        return UserModel.fromCustomApi(
          userData,
          postRegisterComplete: postRegisterComplete,
        );
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
      await _saveToken(token, refreshToken: refreshToken);

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
    try {
      AppLogger.i('Cerrando sesión', tag: _tag);

      final token = await _secureStorage.read(key: 'auth_token');
      final refreshToken = await _secureStorage.read(key: 'refresh_token');

      await _clearToken();
      await _clearAllPersistentData();

      if (token != null && refreshToken != null) {
        try {
          await _dio.post(
            '$_baseUrl/auth/logout',
            data: {'refresh_token': refreshToken},
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          AppLogger.i('Sesión invalidada en servidor', tag: _tag);
        } catch (e) {
          AppLogger.w('No se pudo invalidar sesión en servidor',
              tag: _tag, error: e);
        }
      }
    } catch (e) {
      AppLogger.e('Error al cerrar sesión', tag: _tag, error: e);
      await _clearToken();
      throw AuthException(message: e.toString());
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

  @override
  Future<UserModel> signInWithGoogle() async {
    // TODO: Implementar cuando el backend OAuth esté listo
    throw AuthException(message: 'OAuth con Google no disponible aún');
  }

  @override
  Future<UserModel> signInWithApple() async {
    // TODO: Implementar cuando el backend OAuth esté listo
    throw AuthException(message: 'OAuth con Apple no disponible aún');
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
  Future<bool> getCompletionStatus() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        throw AuthException(message: 'No hay sesión activa');
      }

      final response = await _dio.post(
        '$_baseUrl/auth/pr-check',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['complete'] as bool? ?? false;
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
