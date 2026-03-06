import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/models/create_activity_request.dart';
import '../entities/activity.dart';
import '../repositories/activities_repository.dart';

/// Caso de uso para crear una nueva actividad en un club
class CreateActivity implements UseCase<Activity, CreateActivityParams> {
  final ActivitiesRepository repository;

  CreateActivity(this.repository);

  @override
  Future<Either<Failure, Activity>> call(CreateActivityParams params) async {
    return await repository.createActivity(
      clubId: params.clubId,
      request: params.request,
    );
  }
}

/// Parámetros para crear una actividad
class CreateActivityParams {
  final int clubId;
  final CreateActivityRequest request;

  const CreateActivityParams({
    required this.clubId,
    required this.request,
  });
}
