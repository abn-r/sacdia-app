import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/finances_repository.dart';

class DeleteTransaction {
  final FinancesRepository repository;

  DeleteTransaction(this.repository);

  Future<Either<Failure, void>> call({required int financeId}) {
    return repository.deleteTransaction(financeId: financeId);
  }
}
