/// Modelo genérico para respuestas de la API
///
/// Envuelve las respuestas proporcionando una estructura consistente
/// para manejar datos, mensajes, estado de éxito y metadatos.
class ApiResponse<T> {
  /// Datos de la respuesta
  final T? data;

  /// Mensaje de la respuesta
  final String? message;

  /// Indica si la operación fue exitosa
  final bool success;

  /// Metadatos adicionales
  final Map<String, dynamic>? meta;

  const ApiResponse({
    this.data,
    this.message,
    required this.success,
    this.meta,
  });

  /// Crea una instancia desde JSON
  ///
  /// [fromJsonT] convierte un Map en el tipo T
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return ApiResponse<T>(
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : json['data'] as T?,
      message: json['message'] as String?,
      success: json['success'] as bool? ?? false,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  /// Crea una instancia desde JSON con lista de datos
  factory ApiResponse.fromJsonList(
    Map<String, dynamic> json,
    T Function(List<dynamic>) fromJsonList,
  ) {
    return ApiResponse<T>(
      data: json['data'] != null
          ? fromJsonList(json['data'] as List<dynamic>)
          : null,
      message: json['message'] as String?,
      success: json['success'] as bool? ?? false,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson([Map<String, dynamic> Function(T)? toJsonT]) {
    return {
      'data': data != null && toJsonT != null ? toJsonT(data as T) : data,
      'message': message,
      'success': success,
      'meta': meta,
    };
  }
}
