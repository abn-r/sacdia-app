import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/finance_category.dart';
import '../repositories/finances_repository.dart';

class GetFinanceCategories {
  final FinancesRepository repository;

  GetFinanceCategories(this.repository);

  Future<Either<Failure, List<FinanceCategory>>> call({
    RequestCancelToken? cancelToken,
  }) {
    return repository.getCategories(cancelToken: cancelToken);
  }
}
