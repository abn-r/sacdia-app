import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
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
  
  // Constructor
  AuthRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  }) : _dio = dio, 
       _baseUrl = baseUrl,
       _authStateController = StreamController<bool>.broadcast(),
       _secureStorage = const FlutterSecureStorage() {
    // Inicializar el estado de autenticación
    _checkInitialAuthState();
  }
  
  /// Verificar el estado inicial de autenticación validando el token contra la API
  Future<void> _checkInitialAuthState() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      
      // Paso 1: No hay token → no autenticado
      if (token == null) {
        log('🔒 [AuthRemoteDataSource] No hay token local, usuario no autenticado');
        _authStateController.add(false);
        return;
      }
      
      // Paso 2: Hay token → validar contra /auth/me
      log('🔑 [AuthRemoteDataSource] Token encontrado, validando con el servidor...');
      final response = await _dio.get(
        '$_baseUrl/auth/me',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        log('✅ [AuthRemoteDataSource] Token válido, usuario autenticado');
        _authStateController.add(true);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        log('🔒 [AuthRemoteDataSource] Token expirado/inválido (${response.statusCode}), limpiando sesión');
        await _clearToken();
      } else {
        log('⚠️ [AuthRemoteDataSource] Respuesta inesperada (${response.statusCode}), limpiando sesión');
        await _clearToken();
      }
    } catch (e) {
      log('❌ [AuthRemoteDataSource] Error al verificar estado inicial: $e');
      // En caso de error de red, limpiar token para evitar que la app se quede pasmada
      await _clearToken();
    }
  }
  
  /// Guardar tokens en almacenamiento seguro
  Future<void> _saveToken(String token, {String? refreshToken}) async {
    await _secureStorage.write(key: 'auth_token', value: token);
    if (refreshToken != null) {
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    }
    _authStateController.add(true);
  }
  
  /// Eliminar tokens
  Future<void> _clearToken() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
    _authStateController.add(false);
  }
  
  @override
  Stream<bool> get authStateChanges => _authStateController.stream;
  
  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        return null;
      }

      // Llamar al endpoint /auth/me para obtener datos del usuario actual
      final response = await _dio.get(
        '$_baseUrl/auth/me',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UserModel.fromCustomApi(
          response.data,
          postRegisterComplete: response.data['post_register_complete'] as bool? ?? false,
        );
      }

      // Token inválido o expirado, limpiar sesión
      if (response.statusCode == 401 || response.statusCode == 403) {
        log('🔒 [AuthRemoteDataSource] Token inválido (${response.statusCode}), limpiando sesión');
        await _clearToken();
      }

      return null;
    } catch (e) {
      log('Error al obtener usuario actual: $e');
      if (e is DioException && e.response?.statusCode == 401) {
        // Token inválido, limpiar sesión
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
      log('📱 [AuthRemoteDataSource] Iniciando login para: $email');
      
      // Llamar a la API para iniciar sesión
      final response = await _dio.post('$_baseUrl/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      log('📱 [AuthRemoteDataSource] Respuesta del servidor: ${response.statusCode}');
      
      // Verificar si la respuesta es exitosa
      if (response.statusCode != 200 && response.statusCode != 201) {
        log('📱 [AuthRemoteDataSource] Error en la respuesta: ${response.statusMessage}');
        throw AuthException(message: response.data['message'] ?? 'Error de autenticación');
      }
            
      // Extraer el objeto 'data' de la respuesta
      final responseData = response.data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        log('📱 [AuthRemoteDataSource] No se encontró "data" en la respuesta');
        throw AuthException(message: 'Respuesta del servidor inválida');
      }

      // Verificar que la respuesta contenga el token
      final token = responseData['accessToken'] as String?;
      if (token == null) {
        log('📱 [AuthRemoteDataSource] No se encontró accessToken en la respuesta');
        throw AuthException(message: 'No se recibió token de autenticación');
      }

      // Extraer refresh token si existe
      final refreshToken = responseData['refreshToken'] as String?;

      log('📱 [AuthRemoteDataSource] Token obtenido correctamente');
      await _saveToken(token, refreshToken: refreshToken);
      
      // Extraer datos del usuario
      final userData = responseData['user'] as Map<String, dynamic>?;
      final userId = userData?['id'] as String?;
      if (userId == null) {
        log('📱 [AuthRemoteDataSource] No se encontró user.id en la respuesta');
        throw AuthException(message: 'No se recibió ID de usuario');
      }

      // Verificar estado de post-registro
      final needsPostRegistration = responseData['needsPostRegistration'] as bool? ?? true;
      
      // Construir el modelo de usuario
      return UserModel(
        id: userId,
        email: userData?['email'] as String? ?? email,
        name: userData?['name'] as String? ?? '',
        postRegisterComplete: !needsPostRegistration,
      );
    } catch (e) {
      log('📱 [AuthRemoteDataSource] Error en login: $e');
      if (e is DioException) {
        log('📱 [AuthRemoteDataSource] Dio error: ${e.message}, código: ${e.response?.statusCode}, datos: ${e.response?.data}');
        throw AuthException(message: e.message ?? 'Error de conexión');
      }
      if (e is AuthException) {
        rethrow;
      }
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
      log('📱 [AuthRemoteDataSource] Iniciando registro para: $email');

      // Llamar al endpoint correcto según API spec
      final response = await _dio.post('$_baseUrl/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'paternal_last_name': paternalSurname,
        'maternal_last_name': maternalSurname,
      });

      log('📱 [AuthRemoteDataSource] Respuesta del registro: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
          message: response.data['message'] ?? 'Error en el registro',
        );
      }

      // Extraer datos de la respuesta
      // El registro exitoso retorna el usuario creado
      final userData = response.data['user'] as Map<String, dynamic>?;
      final userId = userData?['id'] as String?;

      if (userId == null) {
        throw AuthException(message: 'No se recibió ID de usuario');
      }

      log('✅ [AuthRemoteDataSource] Usuario registrado: $userId');

      // El registro no devuelve token, el usuario debe hacer login
      // Retornamos el modelo sin sesión activa
      return UserModel(
        id: userId,
        email: userData?['email'] as String? ?? email,
        name: userData?['name'] as String? ?? name,
        postRegisterComplete: false, // Registro nuevo siempre requiere post-registro
      );
    } catch (e) {
      log('❌ [AuthRemoteDataSource] Error en registro: $e');
      if (e is DioException) {
        final message = e.response?.data?['message'] ?? e.message ?? 'Error de conexión';
        throw AuthException(message: message);
      }
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      log('📱 [AuthRemoteDataSource] Iniciando cierre de sesión');

      // Obtener tokens antes de limpiar para invalidar en servidor
      final token = await _secureStorage.read(key: 'auth_token');
      final refreshToken = await _secureStorage.read(key: 'refresh_token');

      // Borrar tokens locales primero
      await _clearToken();

      // Limpiar todos los datos de autenticación almacenados
      await _clearAllPersistentData();

      // Llamar a la API para invalidar el refresh token en el servidor
      if (token != null && refreshToken != null) {
        try {
          await _dio.post(
            '$_baseUrl/auth/logout',
            data: {'refresh_token': refreshToken},
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          log('✅ [AuthRemoteDataSource] Sesión invalidada en servidor');
        } catch (e) {
          // Si falla la llamada al servidor, no es crítico
          // ya limpiamos los tokens locales
          log('⚠️ [AuthRemoteDataSource] No se pudo invalidar en servidor: $e');
        }
      }
    } catch (e) {
      log('❌ [AuthRemoteDataSource] Error al cerrar sesión: $e');
      // Aún si algo falla, aseguramos limpiar tokens locales
      await _clearToken();
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      log('📱 [AuthRemoteDataSource] Solicitando recuperación para: $email');

      // Endpoint correcto según API spec: /auth/request-password-reset
      final response = await _dio.post(
        '$_baseUrl/auth/request-password-reset',
        data: {'email': email},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('✅ [AuthRemoteDataSource] Correo de recuperación enviado');
      }
    } catch (e) {
      log('❌ [AuthRemoteDataSource] Error en reset password: $e');
      if (e is DioException) {
        // La API devuelve mensaje genérico por seguridad
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
      
      // Configurar headers con el token
      _dio.options.headers['Authorization'] = 'Bearer $token';
      
      // Implementación para actualizar la contraseña
      await _dio.post('$_baseUrl/auth/update-password', data: {
        'password': newPassword,
      });
      
      // Devolver usuario actualizado
      return UserModel(
        id: 'current-user-id', // Idealmente obtener de la respuesta
        email: 'usuario@ejemplo.com', // Idealmente obtener de la respuesta
        name: 'Usuario Actual', // Idealmente obtener de la respuesta
        postRegisterComplete: true,
      );
    } catch (e) {
      if (e is DioException) {
        throw AuthException(message: e.message ?? 'Error al actualizar contraseña');
      }
      throw AuthException(message: e.toString());
    }
  }
  
  /// Método para limpiar todos los datos persistentes relacionados con la autenticación
  Future<void> _clearAllPersistentData() async {
    try {
      // 1. Limpiar datos de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Limpiar claves relacionadas con la autenticación
      final keysToRemove = [
        'auth-token',
        'auth-refresh-token',
        'auth-type',
      ];
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      // Borrar cualquier otra clave relacionada con autenticación
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.contains('auth')) {
          await prefs.remove(key);
        }
      }
      
      // 2. Limpiar FlutterSecureStorage (también puede contener tokens)
      final secureKeys = await _secureStorage.readAll();
      
      for (final entry in secureKeys.entries) {
        if (entry.key.contains('auth')) {
          await _secureStorage.delete(key: entry.key);
        }
      }
      
      log('Limpieza completa de datos de autenticación realizada');
    } catch (e) {
      log('Error al limpiar datos: $e');
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
      log('Error al verificar token local: $e');
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
