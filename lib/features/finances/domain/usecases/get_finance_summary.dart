import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/finance_summary.dart';
import '../repositories/finances_repository.dart';

class GetFinanceSummaryParams extends Equatable {
  final int clubId;

  const GetFinanceSummaryParams({required this.clubId});

  @override
  List<Object?> get props => [clubId];
}

class GetFinanceSummary {
  final FinancesRepository repository;

  GetFinanceSummary(this.repository);

  Future<Either<Failure, FinanceSummary>> call(
    GetFinanceSummaryParams params, {
    CancelToken? cancelToken,
  }) {
    return repository.getSummary(
      clubId: params.clubId,
      cancelToken: cancelToken,
    );
  }
}
