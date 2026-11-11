/// Use-case fakes for the finance providers/views: they record every request
/// (so a test can prove a cache hit) and can hold a month behind a gate.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/finances/domain/entities/category_breakdown.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_month.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_summary.dart';
import 'package:sacdia_app/features/finances/domain/repositories/finances_repository.dart';
import 'package:sacdia_app/features/finances/domain/usecases/get_category_breakdown.dart';
import 'package:sacdia_app/features/finances/domain/usecases/get_finance_summary.dart';
import 'package:sacdia_app/features/finances/domain/usecases/get_finances.dart';

/// Month use case that records every request and can hold a month's response
/// behind a [Completer] (see [gates]).
class FakeMonthUseCase implements GetFinances {
  final calls = <GetFinancesParams>[];
  final gates = <int, Completer<void>>{};

  int callsFor(int month) => calls.where((c) => c.month == month).length;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, FinanceMonth>> call(
    GetFinancesParams params, {
    RequestCancelToken? cancelToken,
  }) async {
    calls.add(params);
    await gates[params.month]?.future;
    return Right(
      FinanceMonth(
        year: params.year,
        month: params.month,
        isOpen: true,
        totalBalance: 0,
        totalIncome: params.month * 10.0,
        totalExpense: 0,
        transactions: const [],
      ),
    );
  }
}

class FakeSummaryUseCase implements GetFinanceSummary {
  final calls = <GetFinanceSummaryParams>[];
  final gates = <int, Completer<void>>{};

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, FinanceSummary>> call(
    GetFinanceSummaryParams params, {
    RequestCancelToken? cancelToken,
  }) async {
    calls.add(params);
    await gates[params.month]?.future;
    return Right(
      FinanceSummary(
        totalBalance: 1000.0 + (params.month ?? 0),
        totalIncome: 0,
        totalExpense: 0,
        monthlyBars: const [],
      ),
    );
  }
}

class FakeBreakdownUseCase implements GetCategoryBreakdown {
  final calls = <GetCategoryBreakdownParams>[];

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, CategoryBreakdown>> call(
    GetCategoryBreakdownParams params, {
    RequestCancelToken? cancelToken,
  }) async {
    calls.add(params);
    return const Right(
      CategoryBreakdown(
        period: '',
        income: [],
        expenses: [],
        totalIncome: 0,
        totalExpenses: 0,
      ),
    );
  }
}

/// Wraps a [FakeMonthUseCase] and fails the requests for [failMonth].
class FailingMonthUseCase implements GetFinances {
  FailingMonthUseCase(this.inner, {required this.failMonth});

  final FakeMonthUseCase inner;
  final int failMonth;
  int attempts = 0;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, FinanceMonth>> call(
    GetFinancesParams params, {
    RequestCancelToken? cancelToken,
  }) {
    attempts++;
    if (params.month == failMonth) {
      return Future.value(
        const Left(ServerFailure(message: 'boom', code: 500)),
      );
    }
    return inner(params, cancelToken: cancelToken);
  }
}
