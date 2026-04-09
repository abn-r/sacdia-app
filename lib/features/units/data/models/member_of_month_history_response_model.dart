import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/member_of_month_history_response.dart';
import 'member_of_month_model.dart';

/// Modelo de la respuesta paginada del historial de Miembros del Mes.
///
/// Respuesta esperada del backend:
/// ```json
/// {
///   "data": [{ "month": 3, "year": 2026, "members": [...] }],
///   "pagination": { "total": 24, "page": 1, "limit": 12 }
/// }
/// ```
class MemberOfMonthHistoryResponseModel extends MemberOfMonthHistoryResponse {
  const MemberOfMonthHistoryResponseModel({
    required super.data,
    required super.total,
    required super.page,
    required super.limit,
  });

  factory MemberOfMonthHistoryResponseModel.fromJson(
      Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    final items = rawData
        .whereType<Map<String, dynamic>>()
        .map((j) => MemberOfMonthModel.fromJson(j).toEntity())
        .toList();

    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    return MemberOfMonthHistoryResponseModel(
      data: items,
      total: parseInt(pagination['total']) ?? 0,
      page: parseInt(pagination['page']) ?? 1,
      limit: parseInt(pagination['limit']) ?? 12,
    );
  }

  MemberOfMonthHistoryResponse toEntity() => MemberOfMonthHistoryResponse(
        data: data,
        total: total,
        page: page,
        limit: limit,
      );
}
