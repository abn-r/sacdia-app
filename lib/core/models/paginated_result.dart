/// Generic pagination metadata returned by paginated endpoints.
///
/// Matches the `meta` object shape:
/// ```json
/// { "page": 1, "limit": 50, "total": 120,
///   "totalPages": 3, "hasNextPage": true, "hasPreviousPage": false }
/// ```
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
    final limit = _parseInt(json['limit'] ?? 50);
    final total = _parseInt(json['total'] ?? 0);
    final totalPages =
        _parseInt(json['totalPages'] ?? json['total_pages'] ?? 1);
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

/// Generic wrapper for paginated API responses.
///
/// Usage:
/// ```dart
/// final result = PaginatedResult.fromJson(
///   json,
///   (e) => MyModel.fromJson(e),
/// );
/// ```
class PaginatedResult<T> {
  final List<T> data;
  final PaginationMeta meta;

  const PaginatedResult({
    required this.data,
    required this.meta,
  });

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final rawList = json['data'] as List<dynamic>? ?? [];
    final metaJson = json['meta'] as Map<String, dynamic>? ?? {};
    return PaginatedResult<T>(
      data: rawList
          .map((e) => parseItem(e as Map<String, dynamic>))
          .toList(),
      meta: PaginationMeta.fromJson(metaJson),
    );
  }
}
