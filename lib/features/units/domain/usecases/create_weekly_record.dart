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

  /// Año ISO 8601 al que pertenece el registro.
  final int year;

  final int attendance;

  /// Puntos de puntualidad (1 si estuvo puntual, 0 si no).
  final int punctuality;

  /// Puntajes por categoría dinámica.
  /// Formato: `[{ 'category_id': 1, 'points': 5 }, ...]`
  final List<Map<String, int>> scores;

  const CreateWeeklyRecordParams({
    required this.clubId,
    required this.unitId,
    required this.userId,
    required this.week,
    required this.year,
    required this.attendance,
    this.punctuality = 0,
    this.scores = const [],
  });

  @override
  List<Object> get props =>
      [clubId, unitId, userId, week, year, attendance, punctuality, scores];
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
      year: params.year,
      attendance: params.attendance,
      punctuality: params.punctuality,
      scores: params.scores,
    );
  }
}
