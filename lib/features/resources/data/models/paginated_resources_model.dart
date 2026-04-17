import '../../domain/entities/paginated_resources.dart';
import 'resource_model.dart';

/// Modelo de respuesta paginada de recursos para la capa de datos
class PaginatedResourcesModel {
  final List<ResourceModel> data;
  final int total;
  final int page;
  final int limit;

  const PaginatedResourcesModel({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  /// Crea una instancia desde JSON.
  ///
  /// Soporta dos formatos de respuesta del backend:
  /// - Objeto paginado: { data: [...], total, page, limit }
  /// - Lista plana: [...]
  factory PaginatedResourcesModel.fromJson(dynamic json) {
    if (json is List) {
      final items = json
          .map((e) => ResourceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return PaginatedResourcesModel(
        data: items,
        total: items.length,
        page: 1,
        limit: items.length,
      );
    }

    final map = json as Map<String, dynamic>;
    final rawData = map['data'] as List<dynamic>? ?? [];
    return PaginatedResourcesModel(
      data: rawData
          .map((e) => ResourceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (map['total'] as int?) ?? rawData.length,
      page: (map['page'] as int?) ?? 1,
      limit: (map['limit'] as int?) ?? rawData.length,
    );
  }

  /// Convierte el modelo a entidad de dominio
  PaginatedResources toEntity() {
    return PaginatedResources(
      data: data.map((m) => m.toEntity()).toList(),
      total: total,
      page: page,
      limit: limit,
    );
  }
}
