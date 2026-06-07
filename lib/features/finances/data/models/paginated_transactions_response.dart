import '../../domain/entities/paginated_transactions_response.dart';
import 'transaction_model.dart';

PaginatedTransactionsResponse parsePaginatedTransactionsResponse(
  Map<String, dynamic> json,
) {
  final rawList = json['data'] as List<dynamic>? ?? [];
  final transactions = rawList
      .map((e) => FinanceTransactionModel.fromJson(e as Map<String, dynamic>)
          .toEntity())
      .toList();

  final metaJson = json['meta'] as Map<String, dynamic>? ?? {};
  return PaginatedTransactionsResponse(
    data: transactions,
    meta: _parsePaginationMeta(metaJson),
  );
}

PaginationMeta _parsePaginationMeta(Map<String, dynamic> json) {
  final page = _parseInt(json['page'] ?? 1);
  final limit = _parseInt(json['limit'] ?? 20);
  final total = _parseInt(json['total'] ?? 0);
  final totalPages = _parseInt(json['totalPages'] ?? json['total_pages'] ?? 1);
  return PaginationMeta(
    page: page,
    limit: limit,
    total: total,
    totalPages: totalPages,
    hasNextPage: json['hasNextPage'] as bool? ??
        json['has_next_page'] as bool? ??
        page < totalPages,
    hasPreviousPage: json['hasPreviousPage'] as bool? ??
        json['has_previous_page'] as bool? ??
        page > 1,
  );
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
