import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_union_camporee.dart';

abstract class SupervisionUnionCamporeesRepository {
  /// GET /camporees/union (active, first 100)
  Future<Either<Failure, List<SupervisionUnionCamporee>>> getCamporees({
    RequestCancelToken? cancelToken,
  });

  /// GET /camporees/union/:camporeeId
  Future<Either<Failure, SupervisionUnionCamporee>> getCamporee(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  });

  /// Pending clubs, members and payments of one camporee.
  Future<Either<Failure, SupervisionCamporeePending>> getPending(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, Unit>> decideClub(
    int camporeeId,
    int camporeeClubId, {
    required bool approve,
    String? reason,
  });

  Future<Either<Failure, Unit>> decideMember(
    int camporeeId,
    int camporeeMemberId, {
    required bool approve,
    String? reason,
  });

  Future<Either<Failure, Unit>> decidePayment(
    String paymentId, {
    required bool approve,
    String? reason,
  });
}
