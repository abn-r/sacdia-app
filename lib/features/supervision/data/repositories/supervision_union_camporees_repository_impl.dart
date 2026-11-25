import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_union_camporee.dart';
import '../../domain/repositories/supervision_union_camporees_repository.dart';
import '../datasources/supervision_union_camporees_remote_data_source.dart';

class SupervisionUnionCamporeesRepositoryImpl
    implements SupervisionUnionCamporeesRepository {
  final SupervisionUnionCamporeesRemoteDataSource remoteDataSource;

  SupervisionUnionCamporeesRepositoryImpl({required this.remoteDataSource});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  Future<Either<Failure, Unit>> _guardVoid(Future<void> Function() call) =>
      _guard(() async {
        await call();
        return unit;
      });

  @override
  Future<Either<Failure, List<SupervisionUnionCamporee>>> getCamporees({
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getCamporees(
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionUnionCamporee>> getCamporee(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getCamporee(
            camporeeId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionCamporeePending>> getPending(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getPending(
            camporeeId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, Unit>> decideClub(
    int camporeeId,
    int camporeeClubId, {
    required bool approve,
    String? reason,
  }) =>
      _guardVoid(() => remoteDataSource.decideClub(
            camporeeId,
            camporeeClubId,
            approve: approve,
            reason: reason,
          ));

  @override
  Future<Either<Failure, Unit>> decideMember(
    int camporeeId,
    int camporeeMemberId, {
    required bool approve,
    String? reason,
  }) =>
      _guardVoid(() => remoteDataSource.decideMember(
            camporeeId,
            camporeeMemberId,
            approve: approve,
            reason: reason,
          ));

  @override
  Future<Either<Failure, Unit>> decidePayment(
    String paymentId, {
    required bool approve,
    String? reason,
  }) =>
      _guardVoid(() => remoteDataSource.decidePayment(
            paymentId,
            approve: approve,
            reason: reason,
          ));
}
