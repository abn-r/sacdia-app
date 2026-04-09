import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_of_month.dart';
import '../repositories/units_repository.dart';

class GetMemberOfMonthParams extends Equatable {
  final int clubId;
  final int sectionId;

  const GetMemberOfMonthParams({
    required this.clubId,
    required this.sectionId,
  });

  @override
  List<Object> get props => [clubId, sectionId];
}

/// Caso de uso: obtiene el Miembro del Mes actual de una sección del club.
///
/// Retorna null si no hay evaluación para el mes actual.
class GetMemberOfMonth {
  final UnitsRepository _repository;

  const GetMemberOfMonth(this._repository);

  Future<Either<Failure, MemberOfMonth?>> call(
    GetMemberOfMonthParams params, {
    CancelToken? cancelToken,
  }) {
    return _repository.getMemberOfMonth(
      clubId: params.clubId,
      sectionId: params.sectionId,
      cancelToken: cancelToken,
    );
  }
}
