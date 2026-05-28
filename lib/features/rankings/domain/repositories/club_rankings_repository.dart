import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/club_ranking.dart';

abstract class ClubRankingsRepository {
  Future<Either<Failure, List<ClubRanking>>> getClubRankings({
    required int clubTypeId,
    required int yearId,
    int? localFieldId,
    String? categoryId,
    CancelToken? cancelToken,
  });
}
