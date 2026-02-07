import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/attendance.dart';
import '../repositories/activities_repository.dart';

/// Caso de uso para registrar la asistencia a una actividad
class RegisterAttendance implements UseCase<Attendance, RegisterAttendanceParams> {
  final ActivitiesRepository repository;

  RegisterAttendance(this.repository);

  @override
  Future<Either<Failure, Attendance>> call(RegisterAttendanceParams params) async {
    return await repository.registerAttendance(
      params.activityId,
      params.userId,
      params.attended,
    );
  }
}

/// Parámetros para registrar asistencia
class RegisterAttendanceParams {
  final int activityId;
  final String userId;
  final bool attended;

  const RegisterAttendanceParams({
    required this.activityId,
    required this.userId,
    required this.attended,
  });
}
