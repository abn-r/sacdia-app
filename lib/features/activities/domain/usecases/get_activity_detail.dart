import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/activity.dart';
import '../repositories/activities_repository.dart';

/// Caso de uso para obtener el detalle de una actividad
class GetActivityDetail implements UseCase<Activity, GetActivityDetailParams> {
  final ActivitiesRepository repository;

  GetActivityDetail(this.repository);

  @override
  Future<Either<Failure, Activity>> call(
    GetActivityDetailParams params, {
    CancelToken? cancelToken,
  }) async {
    return await repository.getActivityById(
      params.activityId,
      cancelToken: cancelToken,
    );
  }
}

/// Parámetros para obtener el detalle de una actividad
class GetActivityDetailParams {
  final int activityId;

  const GetActivityDetailParams({required this.activityId});
}
