import 'dart:io';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/create_activity_request.dart';
import '../entities/activity.dart';
import '../entities/attendance.dart';

/// Repositorio de actividades (interfaz del dominio)
abstract class ActivitiesRepository {
  /// Obtiene las actividades de un club
  Future<Either<Failure, List<Activity>>> getClubActivities(
    int clubId, {
    int? clubTypeId,
    int? activityTypeId,
  });


  /// Obtiene el detalle de una actividad
  Future<Either<Failure, Activity>> getActivityById(int activityId);

  /// Crea una nueva actividad en el club especificado
  Future<Either<Failure, Activity>> createActivity({
    required int clubId,
    required CreateActivityRequest request,
  });

  /// Actualiza una actividad existente
  Future<Either<Failure, Activity>> updateActivity({
    required int activityId,
    String? name,
    String? description,
    double? lat,
    double? long,
    String? activityTime,
    String? activityDate,
    String? activityEndDate,
    String? activityPlace,
    int? platform,
    int? activityTypeId,
    String? linkMeet,
    bool? active,
    Set<String> clearFields = const {},
    List<int>? clubSectionIds,
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

  /// Sube una imagen para la actividad y devuelve la URL firmada resultante.
  Future<Either<Failure, String>> uploadActivityImage(
    int activityId,
    File imageFile,
  );
}
