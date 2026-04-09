import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/finances_repository.dart';
import '../datasources/finances_remote_data_source.dart';
import '../models/paginated_transactions_response.dart';

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
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getFinances(
        clubId: clubId,
        year: year,
        month: month,
        cancelToken: cancelToken,
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
  Future<Either<Failure, FinanceSummary>> getSummary({
    required int clubId,
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getSummary(
        clubId: clubId,
        cancelToken: cancelToken,
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
  Future<Either<Failure, FinanceTransaction>> getTransaction({
    required int financeId,
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getTransaction(
        financeId: financeId,
        cancelToken: cancelToken,
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
  Future<Either<Failure, FinanceTransaction>> createTransaction({
    required int clubId,
    required int categoryId,
    required double amount,
    required String description,
    required DateTime date,
    required int year,
    required int month,
    required int clubSectionId,
    required int clubTypeId,
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
        clubSectionId: clubSectionId,
        clubTypeId: clubTypeId,
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
  }) async {
    try {
      final model = await remoteDataSource.updateTransaction(
        financeId: financeId,
        categoryId: categoryId,
        amount: amount,
        description: description,
        date: date,
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
  Future<Either<Failure, List<FinanceCategory>>> getCategories({
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getCategories(
        cancelToken: cancelToken,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PaginatedTransactionsResponse>>
      getTransactionsPaginated({
    required int clubId,
    required int page,
    required int limit,
    String? type,
    String? search,
    String? startDate,
    String? endDate,
    String? sortBy,
    String? sortOrder,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await remoteDataSource.getTransactionsPaginated(
        clubId: clubId,
        page: page,
        limit: limit,
        type: type,
        search: search,
        startDate: startDate,
        endDate: endDate,
        sortBy: sortBy,
        sortOrder: sortOrder,
        cancelToken: cancelToken,
      );
      return Right(response);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
