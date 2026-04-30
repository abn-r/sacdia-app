import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_ranking.dart';

/// Abstract repository for member rankings domain operations.
abstract class MemberRankingsRepository {
  /// Returns the calling member's own ranking for [yearId].
  ///
  /// - 200 OK → [Right<MyRankingView>] (member may be null when uncalculated)
  /// - 403 MEMBER_RANKING_HIDDEN → [Right(null)] (graceful empty state)
  /// - Other 403 / 4xx / 5xx → [Left<Failure>]
  Future<Either<Failure, MyRankingView?>> getMyRanking(
    int yearId, {
    CancelToken? cancelToken,
  });
}
