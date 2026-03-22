import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/weekly_record.dart';
import '../repositories/units_repository.dart';

class CreateWeeklyRecordParams extends Equatable {
  final int clubId;
  final int unitId;
  final String userId;
  final int week;
  final int attendance;
  final int punctuality;
  final int points;

  const CreateWeeklyRecordParams({
    required this.clubId,
    required this.unitId,
    required this.userId,
    required this.week,
    required this.attendance,
    required this.punctuality,
    required this.points,
  });

  @override
  List<Object> get props =>
      [clubId, unitId, userId, week, attendance, punctuality, points];
}

/// Caso de uso: crea un registro semanal para un miembro de la unidad.
class CreateWeeklyRecord {
  final UnitsRepository _repository;

  const CreateWeeklyRecord(this._repository);

  Future<Either<Failure, WeeklyRecord>> call(CreateWeeklyRecordParams params) {
    return _repository.createWeeklyRecord(
      clubId: params.clubId,
      unitId: params.unitId,
      userId: params.userId,
      week: params.week,
      attendance: params.attendance,
      punctuality: params.punctuality,
      points: params.points,
    );
  }
}
