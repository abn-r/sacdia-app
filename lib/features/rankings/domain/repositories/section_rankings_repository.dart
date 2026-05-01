import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/section_ranking.dart';

/// Abstract repository for section rankings domain operations.
abstract class SectionRankingsRepository {
  /// Returns a paginated list of section rankings for [yearId].
  ///
  /// [clubId] is optional — backend filters by RBAC scope when omitted.
  Future<Either<Failure, List<SectionRanking>>> getSectionRankings({
    required int yearId,
    int? clubId,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  });

  /// Returns members ranked within a specific section for [yearId].
  Future<Either<Failure, List<SectionMember>>> getSectionMembers(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  });
}
