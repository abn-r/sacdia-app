import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transaction.dart';
import '../repositories/finances_repository.dart';

class UpdateTransactionParams extends Equatable {
  final int financeId;
  final int? categoryId;
  final double? amount;
  final String? description;
  final DateTime? date;

  const UpdateTransactionParams({
    required this.financeId,
    this.categoryId,
    this.amount,
    this.description,
    this.date,
  });

  @override
  List<Object?> get props =>
      [financeId, categoryId, amount, description, date];
}

class UpdateTransaction {
  final FinancesRepository repository;

  UpdateTransaction(this.repository);

  Future<Either<Failure, FinanceTransaction>> call(
      UpdateTransactionParams params) {
    return repository.updateTransaction(
      financeId: params.financeId,
      categoryId: params.categoryId,
      amount: params.amount,
      description: params.description,
      date: params.date,
    );
  }
}
