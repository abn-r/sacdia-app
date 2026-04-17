import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/finance_month.dart';
import '../repositories/finances_repository.dart';

class GetFinancesParams extends Equatable {
  final int clubId;
  final int year;
  final int month;

  const GetFinancesParams({
    required this.clubId,
    required this.year,
    required this.month,
  });

  @override
  List<Object?> get props => [clubId, year, month];
}

class GetFinances {
  final FinancesRepository repository;

  GetFinances(this.repository);

  Future<Either<Failure, FinanceMonth>> call(
    GetFinancesParams params, {
    CancelToken? cancelToken,
  }) {
    return repository.getFinances(
      clubId: params.clubId,
      year: params.year,
      month: params.month,
      cancelToken: cancelToken,
    );
  }
}
