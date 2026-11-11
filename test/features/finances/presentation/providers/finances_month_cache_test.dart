import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../support/finance_use_case_fakes.dart';

typedef _Harness = ({
  ProviderContainer container,
  FakeMonthUseCase month,
  FakeSummaryUseCase summary,
  FakeBreakdownUseCase breakdown,
});

_Harness _harness({int clubId = 7}) {
  final month = FakeMonthUseCase();
  final summary = FakeSummaryUseCase();
  final breakdown = FakeBreakdownUseCase();
  final container = createTestContainer(
    overrides: [
      currentClubIdProvider.overrideWith((ref) async => clubId),
      getFinancesUseCaseProvider.overrideWithValue(month),
      getFinanceSummaryUseCaseProvider.overrideWithValue(summary),
      getCategoryBreakdownUseCaseProvider.overrideWithValue(breakdown),
    ],
  );
  container.read(selectedMonthProvider.notifier).jumpTo(2026, 4);
  return (
    container: container,
    month: month,
    summary: summary,
    breakdown: breakdown,
  );
}

/// Pumps microtasks and reads the slice each turn: a container (unlike a
/// widget) only rebuilds a dirty provider when something reads it.
Future<void> _flush(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    container.read(financeMonthProvider);
  }
}

Future<void> _settle(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(container.read(financeMonthProvider).isLoading, isFalse);
}

void main() {
  group('SelectedMonthNotifier.goToCurrent', () {
    test('returns to the current month from a past one', () {
      final container = createTestContainer();
      container.read(selectedMonthProvider.notifier).jumpTo(2020, 1);
      expect(container.read(selectedMonthProvider).isCurrentMonth, isFalse);

      container.read(selectedMonthProvider.notifier).goToCurrent();

      final now = DateTime.now();
      expect(
        container.read(selectedMonthProvider),
        SelectedMonth(year: now.year, month: now.month),
      );
      expect(container.read(selectedMonthProvider).isCurrentMonth, isTrue);
    });
  });

  group('selected month slices', () {
    test('keep the previous month value while the next one loads', () async {
      final h = _harness();
      h.container.listen(financeMonthProvider, (_, __) {});
      await _settle(h.container);
      expect(h.container.read(financeMonthProvider).value?.month, 4);

      h.month.gates[3] = Completer<void>();
      h.container.read(selectedMonthProvider.notifier).goToPrevious();
      await Future<void>.delayed(Duration.zero);

      final loading = h.container.read(financeMonthProvider);
      expect(loading.isLoading, isTrue);
      expect(loading.isStale, isTrue);
      expect(loading.value?.month, 4, reason: 'April data kept, not dropped');

      h.month.gates[3]!.complete();
      await _settle(h.container);

      final loaded = h.container.read(financeMonthProvider);
      expect(loaded.isLoading, isFalse);
      expect(loaded.value?.month, 3);
    });

    test('the very first load has no value to keep', () async {
      final h = _harness();
      h.month.gates[4] = Completer<void>();
      h.container.listen(financeMonthProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final first = h.container.read(financeMonthProvider);
      expect(first.isLoading, isTrue);
      expect(first.value, isNull);
    });

    test('a failing month keeps the old value but reports the error', () async {
      final month = FakeMonthUseCase();
      final failing = FailingMonthUseCase(month, failMonth: 3);
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => 7),
          getFinancesUseCaseProvider.overrideWithValue(failing),
          getFinanceSummaryUseCaseProvider
              .overrideWithValue(FakeSummaryUseCase()),
          getCategoryBreakdownUseCaseProvider
              .overrideWithValue(FakeBreakdownUseCase()),
        ],
      );
      container.read(selectedMonthProvider.notifier).jumpTo(2026, 4);
      container.listen(financeMonthProvider, (_, __) {});
      await _settle(container);

      container.read(selectedMonthProvider.notifier).goToPrevious();
      await _settle(container);

      final slice = container.read(financeMonthProvider);
      expect(slice.hasError, isTrue);
      expect(slice.isStale, isTrue);
      expect(slice.value?.month, 4);
    });
  });

  group('per-month cache', () {
    test('going back to a visited month does not call the use case again',
        () async {
      final h = _harness();
      h.container.listen(financeMonthProvider, (_, __) {});
      h.container.listen(financeSummaryProvider, (_, __) {});
      h.container.listen(financeByCategoryProvider, (_, __) {});
      await _settle(h.container);

      final notifier = h.container.read(selectedMonthProvider.notifier);
      notifier.goToPrevious();
      await _settle(h.container);
      notifier.goToNext();

      // Instant: the cached month is available on the very next read.
      final back = h.container.read(financeMonthProvider);
      expect(back.isLoading, isFalse);
      expect(back.value?.month, 4);
      await _settle(h.container);

      expect(h.month.callsFor(4), 1);
      expect(h.month.callsFor(3), 1);
      expect(h.summary.calls.where((c) => c.month == 4), hasLength(1));
      expect(h.breakdown.calls.where((c) => c.month == 4), hasLength(1));
    });

    test('is keyed by club: another club is a different entry', () async {
      final h = _harness();
      final a = FinanceMonthKey(clubId: 1, year: 2026, month: 4);
      final b = FinanceMonthKey(clubId: 2, year: 2026, month: 4);
      h.container.listen(financeMonthByKeyProvider(a), (_, __) {});
      h.container.listen(financeMonthByKeyProvider(b), (_, __) {});
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(h.month.calls.map((c) => c.clubId), unorderedEquals([1, 2]));
    });

    test('a mutation (invalidateFinanceData) forces the next read to refetch',
        () async {
      final h = _harness();
      h.container.listen(financeMonthProvider, (_, __) {});
      await _settle(h.container);
      expect(h.month.callsFor(4), 1);

      invalidateFinanceData(h.container.invalidate);
      await _settle(h.container);

      expect(h.month.callsFor(4), 2);
    });

    test('does not cache a failure: the next read retries', () async {
      final failing = FailingMonthUseCase(FakeMonthUseCase(), failMonth: 4);
      final container = createTestContainer(
        overrides: [
          currentClubIdProvider.overrideWith((ref) async => 7),
          getFinancesUseCaseProvider.overrideWithValue(failing),
        ],
      );
      const key = FinanceMonthKey(clubId: 7, year: 2026, month: 4);

      final sub = container.listen(financeMonthByKeyProvider(key), (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      sub.close();
      await Future<void>.delayed(Duration.zero);

      container.listen(financeMonthByKeyProvider(key), (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(failing.inner.callsFor(4), 0);
      expect(failing.attempts, 2);
    });

    testWidgets('keeps a month for the TTL after it is left, then releases it',
        (tester) async {
      final h = _harness();
      final notifier = h.container.read(selectedMonthProvider.notifier);
      h.container.listen(financeMonthProvider, (_, __) {});
      await _flush(tester, h.container);
      expect(h.month.callsFor(4), 1);

      notifier.goToPrevious();
      await _flush(tester, h.container);

      // Within the TTL: still cached.
      await tester.pump(kFinanceCacheTtl - const Duration(seconds: 30));
      notifier.goToNext();
      await _flush(tester, h.container);
      expect(h.month.callsFor(4), 1);

      // Leave April again and let the TTL run out.
      notifier.goToPrevious();
      await _flush(tester, h.container);
      await tester.pump(kFinanceCacheTtl + const Duration(seconds: 1));
      notifier.goToNext();
      await _flush(tester, h.container);
      expect(h.month.callsFor(4), 2, reason: 'released after the TTL');

      // Cache timers are cancelled with the container: nothing pending after.
      h.container.dispose();
    });
  });

  group('prefetch', () {
    test('loads the previous month once the selected one has settled',
        () async {
      final h = _harness();
      h.container.listen(financePrefetchProvider, (_, __) {});
      await _settle(h.container);
      await _settle(h.container);

      expect(h.month.callsFor(3), 1);
      expect(h.summary.calls.where((c) => c.month == 3), hasLength(1));
      expect(h.breakdown.calls.where((c) => c.month == 3), hasLength(1));

      // Going back is instant, no new request.
      h.container.read(selectedMonthProvider.notifier).goToPrevious();
      final slice = h.container.read(financeMonthProvider);
      expect(slice.isLoading, isFalse);
      expect(slice.value?.month, 3);
      expect(h.month.callsFor(3), 1);
    });

    test('waits for the selected month: nothing is prefetched while it loads',
        () async {
      final h = _harness();
      h.month.gates[4] = Completer<void>();
      h.container.listen(financePrefetchProvider, (_, __) {});
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(h.month.callsFor(3), 0);

      h.month.gates[4]!.complete();
      await _settle(h.container);
      await _settle(h.container);
      expect(h.month.callsFor(3), 1);
    });

    test('crosses the year boundary', () {
      const key = FinanceMonthKey(clubId: 7, year: 2026, month: 1);
      expect(
        key.previous,
        const FinanceMonthKey(clubId: 7, year: 2025, month: 12),
      );
    });
  });
}
