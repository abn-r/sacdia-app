import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/annual_ranking_progress.dart';

abstract class AnnualRankingProgressRepository {
  Future<Either<Failure, AnnualRankingProgress>> getAnnualRankingProgress({
    required int sectionId,
    required int yearId,
    CancelToken? cancelToken,
  });
}
