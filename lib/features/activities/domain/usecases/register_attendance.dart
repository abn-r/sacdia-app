import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/activities_repository.dart';

/// Caso de uso para registrar la asistencia a una actividad
/// Retorna el número de registros creados
class RegisterAttendance implements UseCase<int, RegisterAttendanceParams> {
  final ActivitiesRepository repository;

  RegisterAttendance(this.repository);

  @override
  Future<Either<Failure, int>> call(RegisterAttendanceParams params) async {
    return await repository.registerAttendance(
      params.activityId,
      params.userIds,
    );
  }
}

/// Parámetros para registrar asistencia
class RegisterAttendanceParams {
  final int activityId;
  final List<String> userIds;

  const RegisterAttendanceParams({
    required this.activityId,
    required this.userIds,
  });

  /// Constructor de conveniencia para un solo usuario
  factory RegisterAttendanceParams.single({
    required int activityId,
    required String userId,
  }) {
    return RegisterAttendanceParams(
      activityId: activityId,
      userIds: [userId],
    );
  }
}
