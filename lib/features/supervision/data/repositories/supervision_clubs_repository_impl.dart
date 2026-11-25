import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/supervision_club.dart';
import '../../domain/repositories/supervision_clubs_repository.dart';
import '../datasources/supervision_clubs_remote_data_source.dart';

class SupervisionClubsRepositoryImpl implements SupervisionClubsRepository {
  final SupervisionClubsRemoteDataSource remoteDataSource;

  SupervisionClubsRepositoryImpl({required this.remoteDataSource});

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

  /// Runs a secondary part without ever throwing, so an early error never
  /// goes unhandled while the profile is still pending. Cancellation and
  /// authorization-stale rejections are kept in `fatal` for the caller.
  Future<({T? value, Object? fatal})> _optional<T>(
    Future<T> Function() call,
  ) async {
    try {
      return (value: await call(), fatal: null);
    } on DioException catch (e) {
      return (
        value: null,
        fatal: e.type == DioExceptionType.cancel ? e : null,
      );
    } catch (e) {
      return (value: null, fatal: isAuthorizationStale(e) ? e : null);
    }
  }

  @override
  Future<Either<Failure, SupervisionClubPage>> getClubs({
    required SupervisionClubActiveFilter filter,
    required String search,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() => remoteDataSource.getClubs(
            filter: filter,
            search: search,
            page: page,
            limit: limit,
            cancelToken: cancelToken.asDioCancelToken(),
          ));

  @override
  Future<Either<Failure, SupervisionClubSummary>> getClubSummary(
    int clubId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(() async {
        final token = cancelToken.asDioCancelToken();
        // Started together; the optional parts never throw.
        final overviewFuture = _optional(
            () => remoteDataSource.getOverview(clubId, cancelToken: token));
        final leadershipFuture = _optional(
            () => remoteDataSource.getLeadership(clubId, cancelToken: token));
        final profile =
            await remoteDataSource.getClub(clubId, cancelToken: token);
        final overview = await overviewFuture;
        final leadership = await leadershipFuture;
        final fatal = overview.fatal ?? leadership.fatal;
        if (fatal != null) throw fatal;
        return SupervisionClubSummary(
          profile: profile,
          overview: overview.value,
          leadership: leadership.value,
        );
      });
}
