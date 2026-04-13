import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../data/models/paginated_transactions_response.dart';
import '../entities/finance_category.dart';
import '../entities/finance_month.dart';
import '../entities/finance_summary.dart';
import '../entities/transaction.dart';

/// Contrato de acceso a datos financieros del club.
abstract class FinancesRepository {
  /// Devuelve el listado de movimientos paginados del club.
  ///
  /// Filtra por [year]/[month] cuando se proporcionen.
  Future<Either<Failure, FinanceMonth>> getFinances({
    required int clubId,
    required int year,
    required int month,
    CancelToken? cancelToken,
  });

  /// Devuelve el resumen financiero global del club.
  Future<Either<Failure, FinanceSummary>> getSummary({
    required int clubId,
    CancelToken? cancelToken,
  });

  /// Devuelve un movimiento por su ID.
  Future<Either<Failure, FinanceTransaction>> getTransaction({
    required int financeId,
    CancelToken? cancelToken,
  });

  /// Crea un nuevo movimiento financiero.
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
  });

  /// Actualiza un movimiento existente.
  Future<Either<Failure, FinanceTransaction>> updateTransaction({
    required int financeId,
    int? categoryId,
    double? amount,
    String? description,
    DateTime? date,
  });

  /// Desactiva (soft-delete) un movimiento.
  Future<Either<Failure, void>> deleteTransaction({required int financeId});

  /// Devuelve las categorías disponibles.
  Future<Either<Failure, List<FinanceCategory>>> getCategories({
    CancelToken? cancelToken,
  });

  /// Devuelve una página de transacciones con filtros opcionales.
  ///
  /// Usado por la pantalla "All Transactions" con paginación infinita.
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
  });
}
