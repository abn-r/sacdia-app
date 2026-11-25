import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_club.dart';

abstract class SupervisionClubsRepository {
  /// GET /clubs
  Future<Either<Failure, SupervisionClubPage>> getClubs({
    required SupervisionClubActiveFilter filter,
    required String search,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  });

  /// GET /clubs/:id + /overview + /leadership in parallel. Only a profile
  /// failure fails the call.
  Future<Either<Failure, SupervisionClubSummary>> getClubSummary(
    int clubId, {
    RequestCancelToken? cancelToken,
  });
}
