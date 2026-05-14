import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/material_item.dart';
import '../repositories/materiales_repository.dart';

class BrowseCatalogParams extends Equatable {
  final String? cat;
  final int? programaId;
  final String? q;
  final int page;
  final int pageSize;

  const BrowseCatalogParams({
    this.cat,
    this.programaId,
    this.q,
    this.page = 1,
    this.pageSize = 20,
  });

  @override
  List<Object?> get props => [cat, programaId, q, page, pageSize];
}

/// Caso de uso: obtener catálogo de productos con filtros opcionales.
class BrowseCatalog
    implements UseCase<List<MaterialItem>, BrowseCatalogParams> {
  BrowseCatalog(this._repo);
  final MaterialesRepository _repo;

  @override
  Future<Either<Failure, List<MaterialItem>>> call(
          BrowseCatalogParams params) =>
      _repo.browseCatalog(
        cat: params.cat,
        programaId: params.programaId,
        q: params.q,
        page: params.page,
        pageSize: params.pageSize,
      );
}
