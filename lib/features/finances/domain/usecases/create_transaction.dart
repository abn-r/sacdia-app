import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transaction.dart';
import '../repositories/finances_repository.dart';

class CreateTransactionParams extends Equatable {
  final int clubId;
  final int categoryId;
  final double amount;
  final String description;
  final DateTime date;
  final int year;
  final int month;
  final int clubSectionId;
  final int clubTypeId;

  const CreateTransactionParams({
    required this.clubId,
    required this.categoryId,
    required this.amount,
    required this.description,
    required this.date,
    required this.year,
    required this.month,
    required this.clubSectionId,
    required this.clubTypeId,
  });

  @override
  List<Object?> get props => [
        clubId,
        categoryId,
        amount,
        description,
        date,
        year,
        month,
        clubSectionId,
        clubTypeId,
      ];
}

class CreateTransaction {
  final FinancesRepository repository;

  CreateTransaction(this.repository);

  Future<Either<Failure, FinanceTransaction>> call(
      CreateTransactionParams params) {
    return repository.createTransaction(
      clubId: params.clubId,
      categoryId: params.categoryId,
      amount: params.amount,
      description: params.description,
      date: params.date,
      year: params.year,
      month: params.month,
      clubSectionId: params.clubSectionId,
      clubTypeId: params.clubTypeId,
    );
  }
}
