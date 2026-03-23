import 'package:dartz/dartz.dart' hide Unit;

import '../../../../core/errors/failures.dart';
import '../entities/unit.dart';
import '../entities/unit_member.dart';
import '../entities/weekly_record.dart';

/// Contrato de acceso a datos del módulo de unidades del club.
abstract class UnitsRepository {
  /// Retorna todas las unidades activas de un club.
  Future<Either<Failure, List<Unit>>> getClubUnits({
    required int clubId,
  });

  /// Retorna el detalle de una unidad con sus miembros activos.
  Future<Either<Failure, Unit>> getUnitDetail({
    required int clubId,
    required int unitId,
  });

  /// Crea una nueva unidad en el club.
  Future<Either<Failure, Unit>> createUnit({
    required int clubId,
    required String name,
    required String captainId,
    required String secretaryId,
    required String advisorId,
    String? substituteAdvisorId,
    required int clubTypeId,
    int? clubSectionId,
  });

  /// Actualiza una unidad existente.
  Future<Either<Failure, Unit>> updateUnit({
    required int clubId,
    required int unitId,
    String? name,
    String? captainId,
    String? secretaryId,
    String? advisorId,
    String? substituteAdvisorId,
    int? clubTypeId,
    int? clubSectionId,
    bool? active,
  });

  /// Elimina (soft-delete) una unidad.
  Future<Either<Failure, void>> deleteUnit({
    required int clubId,
    required int unitId,
  });

  /// Agrega un miembro a la unidad.
  Future<Either<Failure, UnitMember>> addUnitMember({
    required int clubId,
    required int unitId,
    required String userId,
  });

  /// Remueve un miembro de la unidad (soft-delete).
  Future<Either<Failure, void>> removeUnitMember({
    required int clubId,
    required int unitId,
    required int memberId,
  });

  /// Retorna los registros semanales de una unidad.
  Future<Either<Failure, List<WeeklyRecord>>> getWeeklyRecords({
    required int clubId,
    required int unitId,
  });

  /// Crea un registro semanal para un miembro de la unidad.
  Future<Either<Failure, WeeklyRecord>> createWeeklyRecord({
    required int clubId,
    required int unitId,
    required String userId,
    required int week,
    required int attendance,
    required int punctuality,
    required int points,
  });

  /// Actualiza un registro semanal existente.
  Future<Either<Failure, WeeklyRecord>> updateWeeklyRecord({
    required int clubId,
    required int unitId,
    required int recordId,
    int? attendance,
    int? punctuality,
    int? points,
    bool? active,
  });
}
