import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/section_ranking.dart';
import '../../domain/repositories/section_rankings_repository.dart';
import '../datasources/rankings_remote_data_source.dart';

/// Concrete implementation of [SectionRankingsRepository].
class SectionRankingsRepositoryImpl implements SectionRankingsRepository {
  final RankingsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  SectionRankingsRepositoryImpl({
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

  // ── SectionRankingsRepository ─────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<SectionRanking>>> getSectionRankings({
    required int yearId,
    int? clubId,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'Sin conexión a internet'));
    }

    try {
      final dtos = await remoteDataSource.getSectionRankings(
        yearId: yearId,
        clubId: clubId,
        page: page,
        limit: limit,
        cancelToken: cancelToken,
      );
      return Right(dtos.map((d) => d.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<SectionMember>>> getSectionMembers(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'Sin conexión a internet'));
    }

    try {
      final dtos = await remoteDataSource.getSectionMembers(
        sectionId,
        yearId,
        cancelToken: cancelToken,
      );
      return Right(dtos.map((d) => d.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
