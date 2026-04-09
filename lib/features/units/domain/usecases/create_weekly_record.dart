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

  /// Puntajes por categoría dinámica.
  /// Formato: `[{ 'category_id': 1, 'points': 5 }, ...]`
  final List<Map<String, int>> scores;

  const CreateWeeklyRecordParams({
    required this.clubId,
    required this.unitId,
    required this.userId,
    required this.week,
    required this.attendance,
    this.scores = const [],
  });

  @override
  List<Object> get props =>
      [clubId, unitId, userId, week, attendance, scores];
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
      scores: params.scores,
    );
  }
}
