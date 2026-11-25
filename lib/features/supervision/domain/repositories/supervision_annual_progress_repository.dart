import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_annual_progress.dart';

abstract class SupervisionAnnualProgressRepository {
  /// GET /catalogs/unions?divisionId=
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getUnions(
    int divisionId, {
    RequestCancelToken? cancelToken,
  });

  /// GET /catalogs/local-fields?unionId=
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getLocalFields(
    int unionId, {
    RequestCancelToken? cancelToken,
  });

  /// GET /annual-rankings
  Future<Either<Failure, SupervisionAnnualProgress>> getAnnualProgress(
    SupervisionAnnualProgressQuery query, {
    RequestCancelToken? cancelToken,
  });
}
