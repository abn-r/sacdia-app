import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/activity.dart';
import '../entities/attendance.dart';

/// Repositorio de actividades (interfaz del dominio)
abstract class ActivitiesRepository {
  /// Obtiene las actividades de un club
  Future<Either<Failure, List<Activity>>> getClubActivities(int clubId);

  /// Obtiene el detalle de una actividad
  Future<Either<Failure, Activity>> getActivityById(int activityId);

  /// Obtiene la asistencia de una actividad
  Future<Either<Failure, List<Attendance>>> getActivityAttendance(int activityId);

  /// Registra la asistencia de un usuario a una actividad
  Future<Either<Failure, Attendance>> registerAttendance(
    int activityId,
    String userId,
    bool attended,
  );
}
