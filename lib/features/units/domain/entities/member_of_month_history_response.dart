import 'member_of_month.dart';

/// Respuesta paginada del historial de Miembros del Mes.
class MemberOfMonthHistoryResponse {
  final List<MemberOfMonth> data;
  final int total;
  final int page;
  final int limit;

  const MemberOfMonthHistoryResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  /// Indica si hay más páginas disponibles.
  bool get hasMore => data.length + (page - 1) * limit < total;
}
