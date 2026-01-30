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
  
  /// Verificar el estado inicial de autenticación
  Future<void> _checkInitialAuthState() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      _authStateController.add(token != null);
    } catch (e) {
      log('Error al verificar estado inicial: $e');
      _authStateController.add(false);
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
      
      // Configurar headers con el token
      _dio.options.headers['Authorization'] = 'Bearer $token';
      
      // Llamar a un endpoint para obtener datos del usuario actual
      // Esta implementación probablemente sea necesario adaptarla a tu API real
      // final response = await _dio.get('$_baseUrl/auth/me');
      // return UserModel.fromCustomApi(response.data);
      
      // Por ahora, devolvemos un usuario mock para que el flujo funcione
      return UserModel(
        id: 'current-user-id',
        email: 'usuario@ejemplo.com',
        name: 'Usuario Actual',
        postRegisterComplete: true,
      );
    } catch (e) {
      log('Error al obtener usuario actual: $e');
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
      final response = await _dio.post('$_baseUrl/auth/signin', data: {
        'email': email,
        'password': password,
      });
      
      log('📱 [AuthRemoteDataSource] Respuesta del servidor: ${response.statusCode}');
      
      // Verificar si la respuesta es exitosa
      if (response.statusCode != 200 && response.statusCode != 201) {
        log('📱 [AuthRemoteDataSource] Error en la respuesta: ${response.statusMessage}');
        throw AuthException(message: response.data['message'] ?? 'Error de autenticación');
      }
            
      // Verificar que la respuesta contenga el token
      final token = response.data['access_token'] as String?;
      if (token == null) {
        log('📱 [AuthRemoteDataSource] No se encontró token en la respuesta');
        throw AuthException(message: 'No se recibió token de autenticación');
      }
      
      log('📱 [AuthRemoteDataSource] Token obtenido correctamente');
      await _saveToken(token);
      
      final userId = response.data['user_context']['user_id'] as String?;
      if (userId == null) {
        log('📱 [AuthRemoteDataSource] No se encontró user_id en la respuesta');
        throw AuthException(message: 'No se recibió ID de usuario');
      }
      
      // Construir el modelo de usuario
      return UserModel(
        id: userId,
        email: email,
        name: response.data['name'] as String? ?? '',
        postRegisterComplete: response.data['post_register_complete'] as bool? ?? false,
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
}
