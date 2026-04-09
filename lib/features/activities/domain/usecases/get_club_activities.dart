import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/activity.dart';
import '../repositories/activities_repository.dart';

/// Caso de uso para obtener las actividades de un club
class GetClubActivities implements UseCase<List<Activity>, GetClubActivitiesParams> {
  final ActivitiesRepository repository;

  GetClubActivities(this.repository);

  @override
  Future<Either<Failure, List<Activity>>> call(
    GetClubActivitiesParams params, {
    CancelToken? cancelToken,
  }) async {
    return await repository.getClubActivities(
      params.clubId,
      clubTypeId: params.clubTypeId,
      cancelToken: cancelToken,
    );
  }
}

/// Parámetros para obtener las actividades de un club
class GetClubActivitiesParams {
  final int clubId;
  final int? clubTypeId;

  const GetClubActivitiesParams({
    required this.clubId,
    this.clubTypeId,
  });
}
