import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/finance_monthly_series.dart';
import '../repositories/finances_repository.dart';

/// Rango de la serie. [fromYear]/[fromMonth] nulos = desde el primer
/// movimiento del club («Todo»); [toYear]/[toMonth] es el último mes.
class GetFinanceMonthlySeriesParams extends Equatable {
  final int clubId;
  final int? fromYear;
  final int? fromMonth;
  final int toYear;
  final int toMonth;

  const GetFinanceMonthlySeriesParams({
    required this.clubId,
    this.fromYear,
    this.fromMonth,
    required this.toYear,
    required this.toMonth,
  });

  @override
  List<Object?> get props => [clubId, fromYear, fromMonth, toYear, toMonth];
}

class GetFinanceMonthlySeries {
  final FinancesRepository repository;

  GetFinanceMonthlySeries(this.repository);

  Future<Either<Failure, FinanceMonthlySeries>> call(
    GetFinanceMonthlySeriesParams params, {
    RequestCancelToken? cancelToken,
  }) {
    return repository.getMonthlySeries(
      clubId: params.clubId,
      fromYear: params.fromYear,
      fromMonth: params.fromMonth,
      toYear: params.toYear,
      toMonth: params.toMonth,
      cancelToken: cancelToken,
    );
  }
}
