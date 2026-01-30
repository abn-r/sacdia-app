import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interceptor para añadir token de autenticación a las peticiones
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Obtener la sesión actual directamente del cliente de Supabase
    final session = Supabase.instance.client.auth.currentSession;

    // Si hay una sesión activa y un token, lo añadimos a la cabecera
    if (session != null && session.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    handler.next(options);
  }
  
  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Manejar errores 401 (Unauthorized) - Token expirado o inválido
    if (err.response?.statusCode == 401) {
      debugPrint('⚠️ Token inválido o expirado');
      // Aquí podríamos implementar la lógica de refresh token
      // o redireccionar al login
    }
    
    handler.next(err);
  }
}
