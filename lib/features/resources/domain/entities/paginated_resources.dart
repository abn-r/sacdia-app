import 'package:equatable/equatable.dart';
import 'resource.dart';

/// Respuesta paginada de recursos
class PaginatedResources extends Equatable {
  final List<Resource> data;
  final int total;
  final int page;
  final int limit;

  const PaginatedResources({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  bool get hasMore => (page * limit) < total;

  @override
  List<Object?> get props => [data, total, page, limit];
}
