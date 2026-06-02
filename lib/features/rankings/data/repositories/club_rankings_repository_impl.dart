import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/club_ranking.dart';
import '../../domain/repositories/club_rankings_repository.dart';
import '../datasources/rankings_remote_data_source.dart';

class ClubRankingsRepositoryImpl implements ClubRankingsRepository {
  final RankingsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ClubRankingsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ClubRanking>>> getClubRankings({
    required int clubTypeId,
    required int yearId,
    int? localFieldId,
    String? categoryId,
    CancelToken? cancelToken,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'Sin conexión a internet'));
    }

    try {
      final dtos = await remoteDataSource.getClubRankings(
        clubTypeId: clubTypeId,
        yearId: yearId,
        localFieldId: localFieldId,
        categoryId: categoryId,
        cancelToken: cancelToken,
      );
      return Right(dtos.map((dto) => dto.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
