import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/scoring_category.dart';
import '../repositories/units_repository.dart';

class GetScoringCategoriesParams extends Equatable {
  final int localFieldId;

  const GetScoringCategoriesParams({required this.localFieldId});

  @override
  List<Object> get props => [localFieldId];
}

/// Caso de uso: obtiene las categorías de puntuación activas para un campo local.
///
/// Las categorías incluyen herencia jerárquica:
/// División (readonly) + Unión (readonly) + Campo Local (editables).
class GetScoringCategories {
  final UnitsRepository _repository;

  const GetScoringCategories(this._repository);

  Future<Either<Failure, List<ScoringCategory>>> call(
    GetScoringCategoriesParams params, {
    CancelToken? cancelToken,
  }) {
    return _repository.getScoringCategories(
      localFieldId: params.localFieldId,
      cancelToken: cancelToken,
    );
  }
}
