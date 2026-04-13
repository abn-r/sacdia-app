import '../../domain/entities/transaction.dart';
import 'transaction_model.dart';

/// Pagination metadata returned by `GET /clubs/:clubId/finances/transactions`.
class PaginationMeta {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
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

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// Parsed response for the paginated transactions endpoint.
class PaginatedTransactionsResponse {
  final List<FinanceTransaction> data;
  final PaginationMeta meta;

  const PaginatedTransactionsResponse({
    required this.data,
    required this.meta,
  });

  factory PaginatedTransactionsResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List<dynamic>? ?? [];
    final transactions = rawList
        .map((e) => FinanceTransactionModel.fromJson(e as Map<String, dynamic>)
            .toEntity())
        .toList();

    final metaJson = json['meta'] as Map<String, dynamic>? ?? {};
    return PaginatedTransactionsResponse(
      data: transactions,
      meta: PaginationMeta.fromJson(metaJson),
    );
  }
}
