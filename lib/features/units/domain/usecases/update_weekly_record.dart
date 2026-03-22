import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/weekly_record.dart';
import '../repositories/units_repository.dart';

class UpdateWeeklyRecordParams extends Equatable {
  final int clubId;
  final int unitId;
  final int recordId;
  final int? attendance;
  final int? punctuality;
  final int? points;
  final bool? active;

  const UpdateWeeklyRecordParams({
    required this.clubId,
    required this.unitId,
    required this.recordId,
    this.attendance,
    this.punctuality,
    this.points,
    this.active,
  });

  @override
  List<Object?> get props =>
      [clubId, unitId, recordId, attendance, punctuality, points, active];
}

/// Caso de uso: actualiza un registro semanal existente.
class UpdateWeeklyRecord {
  final UnitsRepository _repository;

  const UpdateWeeklyRecord(this._repository);

  Future<Either<Failure, WeeklyRecord>> call(UpdateWeeklyRecordParams params) {
    return _repository.updateWeeklyRecord(
      clubId: params.clubId,
      unitId: params.unitId,
      recordId: params.recordId,
      attendance: params.attendance,
      punctuality: params.punctuality,
      points: params.points,
      active: params.active,
    );
  }
}
