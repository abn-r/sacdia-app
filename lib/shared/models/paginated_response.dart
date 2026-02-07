/// Modelo genérico para respuestas paginadas de la API
///
/// Proporciona una estructura consistente para manejar listas de datos
/// paginados, incluyendo información de página, límite y totales.
class PaginatedResponse<T> {
  /// Lista de elementos de la página actual
  final List<T> data;

  /// Número de página actual (base 1)
  final int page;

  /// Elementos por página
  final int limit;

  /// Total de elementos en todas las páginas
  final int total;

  /// Total de páginas disponibles
  final int totalPages;

  const PaginatedResponse({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  /// Crea una instancia desde JSON
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    return PaginatedResponse<T>(
      data: dataList
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 10,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }

  /// Indica si hay una página siguiente
  bool get hasNextPage => page < totalPages;

  /// Indica si hay una página anterior
  bool get hasPreviousPage => page > 1;

  /// Indica si la lista está vacía
  bool get isEmpty => data.isEmpty;

  /// Indica si la lista no está vacía
  bool get isNotEmpty => data.isNotEmpty;
}
