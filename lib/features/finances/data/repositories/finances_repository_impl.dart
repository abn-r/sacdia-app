import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/finances_repository.dart';
import '../datasources/finances_remote_data_source.dart';

class FinancesRepositoryImpl implements FinancesRepository {
  final FinancesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  FinancesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, FinanceMonth>> getFinances({
    required int clubId,
    required int year,
    required int month,
  }) async {
    try {
      final model = await remoteDataSource.getFinances(
        clubId: clubId,
        year: year,
        month: month,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FinanceSummary>> getSummary(
      {required int clubId}) async {
    try {
      final model = await remoteDataSource.getSummary(clubId: clubId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FinanceTransaction>> getTransaction(
      {required int financeId}) async {
    try {
      final model = await remoteDataSource.getTransaction(financeId: financeId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FinanceTransaction>> createTransaction({
    required int clubId,
    required int categoryId,
    required double amount,
    required String description,
    required DateTime date,
    required int year,
    required int month,
    String? notes,
  }) async {
    try {
      final model = await remoteDataSource.createTransaction(
        clubId: clubId,
        categoryId: categoryId,
        amount: amount,
        description: description,
        date: date,
        year: year,
        month: month,
        notes: notes,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FinanceTransaction>> updateTransaction({
    required int financeId,
    int? categoryId,
    double? amount,
    String? description,
    DateTime? date,
    String? notes,
  }) async {
    try {
      final model = await remoteDataSource.updateTransaction(
        financeId: financeId,
        categoryId: categoryId,
        amount: amount,
        description: description,
        date: date,
        notes: notes,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(
      {required int financeId}) async {
    try {
      await remoteDataSource.deleteTransaction(financeId: financeId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FinanceCategory>>> getCategories() async {
    try {
      final models = await remoteDataSource.getCategories();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
