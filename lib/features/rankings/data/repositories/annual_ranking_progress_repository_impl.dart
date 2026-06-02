import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../../domain/repositories/annual_ranking_progress_repository.dart';
import '../datasources/annual_ranking_progress_remote_data_source.dart';

class AnnualRankingProgressRepositoryImpl
    implements AnnualRankingProgressRepository {
  final AnnualRankingProgressRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  AnnualRankingProgressRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, AnnualRankingProgress>> getAnnualRankingProgress({
    required int sectionId,
    required int yearId,
    CancelToken? cancelToken,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'Sin conexión a internet'));
    }

    try {
      final dto = await remoteDataSource.getAnnualRankingProgress(
        sectionId: sectionId,
        yearId: yearId,
        cancelToken: cancelToken,
      );

      return Right(dto.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
