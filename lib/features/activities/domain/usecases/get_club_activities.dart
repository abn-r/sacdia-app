import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/activity.dart';
import '../repositories/activities_repository.dart';

/// Caso de uso para obtener las actividades de un club
class GetClubActivities implements UseCase<List<Activity>, GetClubActivitiesParams> {
  final ActivitiesRepository repository;

  GetClubActivities(this.repository);

  @override
  Future<Either<Failure, List<Activity>>> call(GetClubActivitiesParams params) async {
    return await repository.getClubActivities(params.clubId);
  }
}

/// Parámetros para obtener las actividades de un club
class GetClubActivitiesParams {
  final int clubId;

  const GetClubActivitiesParams({required this.clubId});
}
