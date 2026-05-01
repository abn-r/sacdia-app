import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/member_breakdown.dart';
import '../../domain/entities/member_ranking.dart';
import '../../domain/repositories/member_rankings_repository.dart';
import '../datasources/rankings_remote_data_source.dart';

/// Concrete implementation of [MemberRankingsRepository].
class MemberRankingsRepositoryImpl implements MemberRankingsRepository {
  final RankingsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MemberRankingsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Failure helpers ───────────────────────────────────────────────────────────

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── MemberRankingsRepository ──────────────────────────────────────────────────

  @override
  Future<Either<Failure, MyRankingView?>> getMyRanking(
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    // Check connectivity; return NetworkFailure when offline.
    if (!await networkInfo.isConnected) {
      return const Left(
        NetworkFailure(message: 'Sin conexión a internet'),
      );
    }

    try {
      final dto = await remoteDataSource.getMyRanking(
        yearId,
        cancelToken: cancelToken,
      );
      return Right(dto.toEntity());
    } on MemberRankingHiddenException {
      // Visibility = hidden → graceful empty state (not an error).
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, MemberBreakdown>> getBreakdown(
    int enrollmentId,
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(
        NetworkFailure(message: 'Sin conexión a internet'),
      );
    }

    try {
      final dto = await remoteDataSource.getBreakdown(
        enrollmentId,
        yearId,
        cancelToken: cancelToken,
      );
      return Right(dto.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
