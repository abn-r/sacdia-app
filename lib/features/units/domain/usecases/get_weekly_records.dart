import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/weekly_record.dart';
import '../repositories/units_repository.dart';

class GetWeeklyRecordsParams extends Equatable {
  final int clubId;
  final int unitId;

  const GetWeeklyRecordsParams({required this.clubId, required this.unitId});

  @override
  List<Object> get props => [clubId, unitId];
}

/// Caso de uso: obtiene los registros semanales de una unidad.
class GetWeeklyRecords {
  final UnitsRepository _repository;

  const GetWeeklyRecords(this._repository);

  Future<Either<Failure, List<WeeklyRecord>>> call(
      GetWeeklyRecordsParams params, {CancelToken? cancelToken}) {
    return _repository.getWeeklyRecords(
      clubId: params.clubId,
      unitId: params.unitId,
      cancelToken: cancelToken,
    );
  }
}
