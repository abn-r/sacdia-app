import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/category_breakdown.dart';
import '../repositories/finances_repository.dart';

class GetCategoryBreakdownParams extends Equatable {
  final int clubId;
  final int year;
  final int? month;

  const GetCategoryBreakdownParams({
    required this.clubId,
    required this.year,
    this.month,
  });

  @override
  List<Object?> get props => [clubId, year, month];
}

class GetCategoryBreakdown {
  final FinancesRepository repository;

  GetCategoryBreakdown(this.repository);

  Future<Either<Failure, CategoryBreakdown>> call(
    GetCategoryBreakdownParams params, {
    RequestCancelToken? cancelToken,
  }) {
    return repository.getByCategory(
      clubId: params.clubId,
      year: params.year,
      month: params.month,
      cancelToken: cancelToken,
    );
  }
}
