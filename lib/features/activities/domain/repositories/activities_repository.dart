import 'dart:io';

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/activity_club_section.dart';
import '../entities/create_activity_request.dart';
import '../entities/activity.dart';
import '../entities/attendance.dart';

/// Repositorio de actividades (interfaz del dominio)
abstract class ActivitiesRepository {
  /// Obtiene las actividades de un club
  Future<Either<Failure, List<Activity>>> getClubActivities(
    int clubId, {
    int? clubTypeId,
    RequestCancelToken? cancelToken,
  });

  /// Obtiene el detalle de una actividad
  Future<Either<Failure, Activity>> getActivityById(
    int activityId, {
    RequestCancelToken? cancelToken,
  });

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
  Future<Either<Failure, List<Attendance>>> getActivityAttendance(
    int activityId, {
    RequestCancelToken? cancelToken,
  });

  /// Obtiene las secciones de un club para flujos de actividades conjuntas.
  Future<Either<Failure, List<ActivityClubSection>>> getClubSections(
    int clubId, {
    RequestCancelToken? cancelToken,
  });

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
