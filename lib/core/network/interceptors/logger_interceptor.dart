import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Interceptor para registrar las peticiones y respuestas HTTP
class LoggerInterceptor extends Interceptor {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 75,
      colors: true,
      printEmojis: true,
      printTime: true,
      dateTimeFormat: DateTimeFormat.dateAndTime
    ),
  );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.i('┌── 🌐 Petición HTTP');
      _logger.i('│ URL: ${options.uri}');
      _logger.i('│ Método: ${options.method}');
      if (options.headers.isNotEmpty) {
        _logger.i('│ Headers: ${_filterHeaders(options.headers)}');
      }
      if (options.data != null) {
        _logger.i('│ Body: ${options.data}');
      }
      if (options.queryParameters.isNotEmpty) {
        _logger.i('│ Query params: ${options.queryParameters}');
      }
      _logger.i('└───────────────────────');
    }
    
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.i('┌── ✅ Respuesta HTTP');
      _logger.i('│ URL: ${response.requestOptions.uri}');
      _logger.i('│ Status: ${response.statusCode}');
      _logger.i('│ Headers: ${_filterHeaders(response.headers.map)}');
      
      if (response.data != null) {
        if (response.data is Map || response.data is List) {
          _logger.i('│ Body: ${response.data}');
        } else {
          _logger.i('│ Body: [Datos no serializables]');
        }
      }
      
      _logger.i('└───────────────────────');
    }
    
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.e('┌── ❌ Error HTTP');
      _logger.e('│ URL: ${err.requestOptions.uri}');
      _logger.e('│ Tipo de error: ${err.type}');
      _logger.e('│ Status: ${err.response?.statusCode ?? "N/A"}');
      
      if (err.response?.data != null) {
        if (err.response?.data is Map || err.response?.data is List) {
          _logger.e('│ Respuesta: ${err.response?.data}');
        } else {
          _logger.e('│ Respuesta: [Datos no serializables]');
        }
      }
      
      // El stackTrace siempre está disponible en un DioException
      _logger.e('│ Stack: ${err.stackTrace}');
      
      _logger.e('└───────────────────────');
    }
    
    handler.next(err);
  }
  
  /// Filtra headers para no mostrar información sensible
  Map<String, dynamic> _filterHeaders(Map<String, dynamic> headers) {
    final filteredHeaders = Map<String, dynamic>.from(headers);
    
    // Ocultar tokens y datos sensibles
    if (filteredHeaders.containsKey('Authorization')) {
      filteredHeaders['Authorization'] = '[FILTRADO]';
    }
    
    if (filteredHeaders.containsKey('Cookie')) {
      filteredHeaders['Cookie'] = '[FILTRADO]';
    }
    
    return filteredHeaders;
  }
}
