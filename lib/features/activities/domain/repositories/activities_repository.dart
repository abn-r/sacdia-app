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

  /// Crea una nueva actividad
  Future<Either<Failure, Activity>> createActivity({
    required int clubId,
    required String title,
    String? description,
    required int activityType,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    required String instanceType,
    required int instanceId,
  });

  /// Actualiza una actividad existente
  Future<Either<Failure, Activity>> updateActivity({
    required int activityId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? active,
  });

  /// Elimina (desactiva) una actividad
  Future<Either<Failure, void>> deleteActivity(int activityId);

  /// Obtiene la asistencia de una actividad
  Future<Either<Failure, List<Attendance>>> getActivityAttendance(int activityId);

  /// Registra la asistencia de usuarios a una actividad
  Future<Either<Failure, int>> registerAttendance(
    int activityId,
    List<String> userIds,
  );
}
