import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/annual_ranking_progress.dart';

abstract class AnnualRankingProgressRepository {
  Future<Either<Failure, AnnualRankingProgress>> getAnnualRankingProgress({
    required int sectionId,
    required int yearId,
    RequestCancelToken? cancelToken,
  });
}
