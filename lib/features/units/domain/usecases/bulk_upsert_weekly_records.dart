import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/weekly_record.dart';
import '../repositories/units_repository.dart';

class BulkWeeklyRecordEntry extends Equatable {
  final String userId;

  /// Campo legacy de compatibilidad; la asistencia que suma puntos debe viajar
  /// como categoría en [scores].
  final int attendance;

  /// Campo legacy de compatibilidad; la puntualidad que suma puntos debe viajar
  /// como categoría en [scores].
  final int punctuality;
  final List<Map<String, int>> scores;

  const BulkWeeklyRecordEntry({
    required this.userId,
    required this.attendance,
    this.punctuality = 0,
    this.scores = const [],
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'attendance': attendance,
        'punctuality': punctuality,
        if (scores.isNotEmpty) 'scores': scores,
      };

  @override
  List<Object> get props => [userId, attendance, punctuality, scores];
}

class BulkUpsertWeeklyRecordsParams extends Equatable {
  final int clubId;
  final int unitId;
  final int week;
  final int year;
  final List<BulkWeeklyRecordEntry> records;

  const BulkUpsertWeeklyRecordsParams({
    required this.clubId,
    required this.unitId,
    required this.week,
    required this.year,
    required this.records,
  });

  @override
  List<Object> get props => [clubId, unitId, week, year, records];
}

/// Caso de uso: guarda atómicamente la planilla semanal de una unidad.
class BulkUpsertWeeklyRecords {
  final UnitsRepository _repository;

  const BulkUpsertWeeklyRecords(this._repository);

  Future<Either<Failure, List<WeeklyRecord>>> call(
    BulkUpsertWeeklyRecordsParams params,
  ) {
    return _repository.bulkUpsertWeeklyRecords(
      clubId: params.clubId,
      unitId: params.unitId,
      week: params.week,
      year: params.year,
      records: params.records.map((record) => record.toJson()).toList(),
    );
  }
}
