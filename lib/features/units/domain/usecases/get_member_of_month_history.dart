import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/member_of_month_history_response.dart';
import '../repositories/units_repository.dart';

class GetMemberOfMonthHistoryParams extends Equatable {
  final int clubId;
  final int sectionId;
  final int page;
  final int limit;

  const GetMemberOfMonthHistoryParams({
    required this.clubId,
    required this.sectionId,
    this.page = 1,
    this.limit = 12,
  });

  @override
  List<Object> get props => [clubId, sectionId, page, limit];
}

/// Caso de uso: obtiene el historial paginado de Miembros del Mes de una sección.
class GetMemberOfMonthHistory {
  final UnitsRepository _repository;

  const GetMemberOfMonthHistory(this._repository);

  Future<Either<Failure, MemberOfMonthHistoryResponse>> call(
    GetMemberOfMonthHistoryParams params,
  ) {
    return _repository.getMemberOfMonthHistory(
      clubId: params.clubId,
      sectionId: params.sectionId,
      page: params.page,
      limit: params.limit,
    );
  }
}
