import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/finance_category.dart';
import '../repositories/finances_repository.dart';

class GetFinanceCategories {
  final FinancesRepository repository;

  GetFinanceCategories(this.repository);

  Future<Either<Failure, List<FinanceCategory>>> call() {
    return repository.getCategories();
  }
}
