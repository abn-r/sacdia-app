import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_annual_progress.dart';
import '../../domain/repositories/supervision_annual_progress_repository.dart';
import '../datasources/supervision_annual_progress_remote_data_source.dart';

class SupervisionAnnualProgressRepositoryImpl
    implements SupervisionAnnualProgressRepository {
  final SupervisionAnnualProgressRemoteDataSource remoteDataSource;

  SupervisionAnnualProgressRepositoryImpl({required this.remoteDataSource});

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

  @override
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getUnions(
    int divisionId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getUnions(
            divisionId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getLocalFields(
    int unionId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getLocalFields(
            unionId,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionAnnualProgress>> getAnnualProgress(
    SupervisionAnnualProgressQuery query, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getAnnualProgress(
            query,
            cancelToken: cancelToken.asDioCancelToken(),
          ));
}
