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
  
  /// Guardar token en almacenamiento seguro
  Future<void> _saveToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
    _authStateController.add(true);
  }
  
  /// Eliminar token
  Future<void> _clearToken() async {
    await _secureStorage.delete(key: 'auth_token');
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
      
      log('📱 [AuthRemoteDataSource] Token obtenido correctamente');
      await _saveToken(token);
      
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
      // Implementación del flujo de registro personalizado
      final response = await _dio.post('$_baseUrl/auth/signUp', data: {
        "email": email,
        "password": password,
        "name": name,
        "p_lastname": paternalSurname,
        "m_lastname": maternalSurname,
      });
      
      log('Respuesta del registro: ${response.data}');
      
      final userId = response.data['user_id'] as String;
      final token = response.data['access_token'] as String;
      
      // Guardar el token
      await _saveToken(token);
      
      // Verificar si el post-registro está completo
      final postRegisterComplete = await _checkPostRegisterComplete(userId);
      
      return UserModel.fromCustomApi(
        response.data,
        postRegisterComplete: postRegisterComplete,
      );
    } catch (e) {
      if (e is DioException) {
        throw AuthException(message: e.message ?? 'Error de conexión');
      }
      throw AuthException(message: e.toString());
    }
  }

  /// Método para verificar si el post-registro está completo
  Future<bool> _checkPostRegisterComplete(String userId) async {
    try {
      final response = await _dio.post('$_baseUrl/auth/pr-check', data: {
        'user_id': userId
      }, options: Options(headers: {
        'Authorization': 'Bearer ${await _secureStorage.read(key: 'auth_token')}',
      }));
      
      if (response.data != null && response.data['complete'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      log('Error al verificar post-registro: $e');
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Borrar el token de autenticación
      await _clearToken();
      
      // Limpiar todos los datos de autenticación almacenados
      await _clearAllPersistentData();
      
      // Llamada a la API para cerrar sesión (opcional)
      // await _dio.post('$_baseUrl/auth/logout');
    } catch (e) {
      log('Error al cerrar sesión: $e');
      // Aún si la llamada falla, eliminamos el token local
      await _clearToken();
      throw AuthException(message: e.toString());
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      // Implementación para solicitar cambio de contraseña
      // En una API personalizada, esto generalmente envía un correo
      await _dio.post('$_baseUrl/auth/reset-password', data: {
        'email': email,
      });
    } catch (e) {
      if (e is DioException) {
        throw AuthException(message: e.message ?? 'Error al solicitar cambio de contraseña');
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
