import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../support/finance_use_case_fakes.dart';

({ProviderContainer container, FakeSeriesUseCase series}) _harness({
  String period = '3M',
}) {
  final series = FakeSeriesUseCase();
  final container = createTestContainer(
    overrides: [
      currentClubIdProvider.overrideWith((ref) async => 7),
      getFinanceMonthlySeriesUseCaseProvider.overrideWithValue(series),
    ],
  );
  container.read(selectedMonthProvider.notifier).jumpTo(2026, 2);
  container.read(selectedPeriodProvider.notifier).state = period;
  return (container: container, series: series);
}

Future<void> _settle() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('FinanceSeriesKey', () {
    test('3M, 6M and 1A end at the selected month and cross the year', () {
      const base = (clubId: 7, year: 2026, month: 2);
      FinanceSeriesKey key(String p) => FinanceSeriesKey(
            clubId: base.clubId,
            period: p,
            year: base.year,
            month: base.month,
          );

      expect(key('3M').from, (year: 2025, month: 12));
      expect(key('6M').from, (year: 2025, month: 9));
      expect(key('1A').from, (year: 2025, month: 3));
    });

    test('Todo has no start: the server picks the first movement', () {
      const key = FinanceSeriesKey(
        clubId: 7,
        period: 'Todo',
        year: 2026,
        month: 2,
      );
      expect(key.from, isNull);
    });

    test('keys with the same club, period and month are equal', () {
      const a = FinanceSeriesKey(clubId: 1, period: '3M', year: 2026, month: 2);
      const b = FinanceSeriesKey(clubId: 1, period: '3M', year: 2026, month: 2);
      const c = FinanceSeriesKey(clubId: 1, period: '6M', year: 2026, month: 2);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('financeSeriesProvider', () {
    test('requests the range of the period ending at the selected month',
        () async {
      final h = _harness(period: '6M');
      h.container.listen(financeSeriesProvider, (_, __) {});
      await _settle();

      expect(h.series.calls, hasLength(1));
      final call = h.series.calls.single;
      expect(call.clubId, 7);
      expect((call.fromYear, call.fromMonth), (2025, 9));
      expect((call.toYear, call.toMonth), (2026, 2));
      final slice = h.container.read(financeSeriesProvider);
      expect(slice.isLoading, isFalse);
      expect(slice.value?.items, hasLength(6));
    });

    test('Todo sends no start month', () async {
      final h = _harness(period: 'Todo');
      h.container.listen(financeSeriesProvider, (_, __) {});
      await _settle();

      final call = h.series.calls.single;
      expect(call.fromYear, isNull);
      expect(call.fromMonth, isNull);
      expect((call.toYear, call.toMonth), (2026, 2));
    });

    test('1M never asks for the series', () async {
      final h = _harness(period: '1M');
      h.container.listen(financeSeriesProvider, (_, __) {});
      await _settle();

      expect(h.series.calls, isEmpty);
      expect(h.container.read(financeSeriesProvider).value, isNull);
    });

    test('revisiting a period is a cache hit; another period is a new request',
        () async {
      final h = _harness();
      h.container.listen(financeSeriesProvider, (_, __) {});
      await _settle();
      expect(h.series.calls, hasLength(1));

      h.container.read(selectedPeriodProvider.notifier).state = '1A';
      await _settle();
      expect(h.series.calls, hasLength(2));

      h.container.read(selectedPeriodProvider.notifier).state = '3M';
      await _settle();
      expect(h.series.calls, hasLength(2), reason: '3M still cached');
    });

    test('changing the selected month asks for the new range', () async {
      final h = _harness();
      h.container.listen(financeSeriesProvider, (_, __) {});
      await _settle();

      h.container.read(selectedMonthProvider.notifier).goToPrevious();
      await _settle();

      expect(h.series.calls, hasLength(2));
      expect(
          (h.series.calls.last.toYear, h.series.calls.last.toMonth), (2026, 1));
    });

    test('invalidateFinanceData wipes the series cache', () async {
      final h = _harness();
      h.container.listen(financeSeriesProvider, (_, __) {});
      await _settle();
      expect(h.series.calls, hasLength(1));

      invalidateFinanceData(h.container.invalidate);
      await _settle();

      expect(h.series.calls, hasLength(2));
    });

    test('a failure is reported and not cached', () async {
      final h = _harness();
      h.series.fail = true;
      h.container.listen(financeSeriesProvider, (_, __) {});
      await _settle();
      expect(h.container.read(financeSeriesProvider).hasError, isTrue);

      h.series.fail = false;
      invalidateFinanceData(h.container.invalidate);
      await _settle();

      final slice = h.container.read(financeSeriesProvider);
      expect(slice.hasError, isFalse);
      expect(slice.value?.items, hasLength(3));
    });
  });
}
