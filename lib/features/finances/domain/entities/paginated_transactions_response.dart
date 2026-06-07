import 'transaction.dart';

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
}

/// Domain response for the paginated transactions endpoint.
class PaginatedTransactionsResponse {
  final List<FinanceTransaction> data;
  final PaginationMeta meta;

  const PaginatedTransactionsResponse({
    required this.data,
    required this.meta,
  });
}
