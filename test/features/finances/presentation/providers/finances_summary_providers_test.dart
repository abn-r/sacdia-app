import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/finances/domain/entities/category_breakdown.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_month.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_summary.dart';
import 'package:sacdia_app/features/finances/domain/repositories/finances_repository.dart';
import 'package:sacdia_app/features/finances/domain/usecases/get_category_breakdown.dart';
import 'package:sacdia_app/features/finances/domain/usecases/get_finance_summary.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';

import '../../../../support/riverpod_test_support.dart';

class _FakeSummaryUseCase implements GetFinanceSummary {
  _FakeSummaryUseCase(this.result);

  final Either<Failure, FinanceSummary> result;
  GetFinanceSummaryParams? lastParams;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, FinanceSummary>> call(
    GetFinanceSummaryParams params, {
    RequestCancelToken? cancelToken,
  }) async {
    lastParams = params;
    return result;
  }
}

class _FakeBreakdownUseCase implements GetCategoryBreakdown {
  _FakeBreakdownUseCase(this.result);

  final Either<Failure, CategoryBreakdown> result;
  GetCategoryBreakdownParams? lastParams;

  @override
  FinancesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, CategoryBreakdown>> call(
    GetCategoryBreakdownParams params, {
    RequestCancelToken? cancelToken,
  }) async {
    lastParams = params;
    return result;
  }
}

const _summary = FinanceSummary(
  totalBalance: 1800,
  totalIncome: 200,
  totalExpense: 50,
  net: 150,
  yearIncome: 900,
  yearExpense: 400,
  movementCount: 5,
  periodClosed: true,
  monthlyBars: [],
);

const _breakdown = CategoryBreakdown(
  period: '2026-04',
  income: [CategoryTotal(categoryId: 1, name: 'Cuotas', total: 500, count: 3)],
  expenses: [],
  totalIncome: 500,
  totalExpenses: 0,
);

/// Waits (microtasks only) until the selected-month slice stops loading.
Future<void> settle(
    ProviderContainer container, ProviderListenable<FinanceSlice> p) async {
  for (var i = 0; i < 50 && container.read(p).isLoading; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('financeSummaryProvider', () {
    test('asks for the selected month and exposes the parsed summary',
        () async {
      final useCase = _FakeSummaryUseCase(const Right(_summary));
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => 7),
          getFinanceSummaryUseCaseProvider.overrideWithValue(useCase),
        ],
      );
      container.read(selectedMonthProvider.notifier).jumpTo(2026, 4);

      container.listen(financeSummaryProvider, (_, __) {});
      await settle(container, financeSummaryProvider);

      expect(container.read(financeSummaryProvider).value, _summary);
      expect(useCase.lastParams?.clubId, 7);
      expect(useCase.lastParams?.year, 2026);
      expect(useCase.lastParams?.month, 4);
    });

    test('surfaces a failure as an error', () async {
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => 7),
          getFinanceSummaryUseCaseProvider.overrideWithValue(
            _FakeSummaryUseCase(
              const Left(ServerFailure(message: 'boom', code: 500)),
            ),
          ),
        ],
      );

      container.listen(financeSummaryProvider, (_, __) {});
      await settle(container, financeSummaryProvider);

      final slice = container.read(financeSummaryProvider);
      expect(slice.hasError, isTrue);
      expect(slice.error.toString(), contains('boom'));
    });

    test('is null without a club', () async {
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => null),
        ],
      );

      container.listen(financeSummaryProvider, (_, __) {});
      await settle(container, financeSummaryProvider);

      final slice = container.read(financeSummaryProvider);
      expect(slice.value, isNull);
      expect(slice.isLoading, isFalse);
    });
  });

  group('financeByCategoryProvider', () {
    test('asks for the selected year and month and parses the lists', () async {
      final useCase = _FakeBreakdownUseCase(const Right(_breakdown));
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => 7),
          getCategoryBreakdownUseCaseProvider.overrideWithValue(useCase),
        ],
      );
      container.read(selectedMonthProvider.notifier).jumpTo(2026, 4);

      container.listen(financeByCategoryProvider, (_, __) {});
      await settle(container, financeByCategoryProvider);

      expect(container.read(financeByCategoryProvider).value, _breakdown);
      expect(useCase.lastParams?.clubId, 7);
      expect(useCase.lastParams?.year, 2026);
      expect(useCase.lastParams?.month, 4);
    });

    test('surfaces a failure as an error', () async {
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => 7),
          getCategoryBreakdownUseCaseProvider.overrideWithValue(
            _FakeBreakdownUseCase(
              const Left(ServerFailure(message: 'sin permiso', code: 403)),
            ),
          ),
        ],
      );

      container.listen(financeByCategoryProvider, (_, __) {});
      await settle(container, financeByCategoryProvider);

      final slice = container.read(financeByCategoryProvider);
      expect(slice.hasError, isTrue);
      expect(slice.error.toString(), contains('sin permiso'));
    });

    test('is null without a club', () async {
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => null),
        ],
      );

      container.listen(financeByCategoryProvider, (_, __) {});
      await settle(container, financeByCategoryProvider);

      final slice = container.read(financeByCategoryProvider);
      expect(slice.value, isNull);
      expect(slice.isLoading, isFalse);
    });
  });

  group('financePeriodClosedProvider', () {
    FinanceMonth month({required bool isOpen}) => FinanceMonth(
          year: 2026,
          month: 4,
          isOpen: isOpen,
          totalBalance: 0,
          totalIncome: 0,
          totalExpense: 0,
          transactions: const [],
        );

    Future<bool> closedWith({
      FinanceSummary? summary,
      FinanceMonth? financeMonth,
    }) async {
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => 1),
          financeSummaryByKeyProvider.overrideWith((ref, key) async => summary),
          financeMonthByKeyProvider
              .overrideWith((ref, key) async => financeMonth),
        ],
      );
      // autoDispose providers: keep them alive while the values resolve.
      container.listen(financeSummaryProvider, (_, __) {});
      container.listen(financeMonthProvider, (_, __) {});
      container.listen(financePeriodClosedProvider, (_, __) {});
      await settle(container, financeSummaryProvider);
      await settle(container, financeMonthProvider);
      return container.read(financePeriodClosedProvider);
    }

    test('uses period_closed of the summary first', () async {
      expect(
        await closedWith(summary: _summary, financeMonth: month(isOpen: true)),
        isTrue,
      );
    });

    test('falls back to the month movements when the summary has no flag',
        () async {
      const noFlag = FinanceSummary(
        totalBalance: 0,
        totalIncome: 0,
        totalExpense: 0,
        monthlyBars: [],
      );
      expect(
        await closedWith(summary: noFlag, financeMonth: month(isOpen: false)),
        isTrue,
      );
      expect(
        await closedWith(summary: noFlag, financeMonth: month(isOpen: true)),
        isFalse,
      );
    });

    test('an open summary wins over closed movements', () async {
      const open = FinanceSummary(
        totalBalance: 0,
        totalIncome: 0,
        totalExpense: 0,
        monthlyBars: [],
        periodClosed: false,
      );
      expect(
        await closedWith(summary: open, financeMonth: month(isOpen: false)),
        isFalse,
      );
    });
  });
}
