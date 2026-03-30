import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/enrollment.dart';

/// Interfaz del repositorio de inscripciones anuales.
abstract class EnrollmentRepository {
  /// Crea una inscripción anual para la sección del club.
  Future<Either<Failure, Enrollment>> createEnrollment({
    required String clubId,
    required int sectionId,
    required String address,
    double? lat,
    double? long,
    required List<MeetingSchedule> meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String> deputyDirectorIds,
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  });

  /// Obtiene la inscripción activa del usuario en la sección.
  Future<Either<Failure, Enrollment?>> getCurrentEnrollment({
    required String clubId,
    required int sectionId,
  });

  /// Actualiza una inscripción existente.
  Future<Either<Failure, Enrollment>> updateEnrollment({
    required String clubId,
    required int sectionId,
    required String enrollmentId,
    String? address,
    double? lat,
    double? long,
    List<MeetingSchedule>? meetingSchedule,
    int? soulsTarget,
    bool? fee,
    double? feeAmount,
    String? directorId,
    List<String>? deputyDirectorIds,
    String? secretaryId,
    String? treasurerId,
    String? secretaryTreasurerId,
  });
}
