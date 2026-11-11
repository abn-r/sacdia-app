import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/finances/domain/usecases/get_finances.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';
import 'package:sacdia_app/features/finances/presentation/views/finances_view.dart';
import 'package:sacdia_app/features/finances/presentation/widgets/balance_header_card.dart';
import 'package:sacdia_app/features/finances/presentation/widgets/finance_month_transition.dart';
import 'package:sacdia_app/features/finances/presentation/widgets/finances_loading_skeleton.dart';

import '../../../coordinator/coordinator_test_harness.dart';
import '../../../../support/riverpod_test_support.dart';
import '../../support/finance_use_case_fakes.dart';

class _FixedMonth extends SelectedMonthNotifier {
  _FixedMonth(this.initial);

  final SelectedMonth initial;

  @override
  SelectedMonth build() => initial;
}

typedef _Env = ({
  FakeMonthUseCase month,
  FakeSummaryUseCase summary,
  FakeBreakdownUseCase breakdown,
  ProviderContainer container,
});

const _april = SelectedMonth(year: 2026, month: 4);

Future<_Env> _pump(
  WidgetTester tester, {
  SelectedMonth? initial = _april,
  GetFinances? monthUseCase,
  FakeMonthUseCase? month,
  FakeSummaryUseCase? summary,
  bool acting = false,
  bool pumpToIdle = true,
}) async {
  useTallSurface(tester);
  final fakeMonth = month ?? FakeMonthUseCase();
  final fakeSummary = summary ?? FakeSummaryUseCase();
  final breakdown = FakeBreakdownUseCase();
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        if (initial != null)
          selectedMonthProvider.overrideWith(() => _FixedMonth(initial)),
        currentClubIdProvider.overrideWith((ref) async => 7),
        getFinancesUseCaseProvider.overrideWithValue(monthUseCase ?? fakeMonth),
        getFinanceSummaryUseCaseProvider.overrideWithValue(fakeSummary),
        getCategoryBreakdownUseCaseProvider.overrideWithValue(breakdown),
        canManageFinancesProvider.overrideWith((ref) async => true),
        if (acting)
          actingDependentProvider.overrideWithValue(
            const ActingDependent(userId: 'ana-1', firstName: 'Ana'),
          ),
      ],
      child:
          localized((context) => localizedApp(context, const FinancesView())),
    ),
  );
  if (pumpToIdle) await tester.pumpAndSettle();
  return (
    month: fakeMonth,
    summary: fakeSummary,
    breakdown: breakdown,
    container: ProviderScope.containerOf(
      tester.element(find.byType(EasyLocalization)),
    ),
  );
}

BalanceHeaderCard _header(WidgetTester tester) =>
    tester.widget<BalanceHeaderCard>(find.byType(BalanceHeaderCard));

/// The dimming layer of the content: the outermost opacity of the transition.
AnimatedOpacity _dim(WidgetTester tester) => tester.widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.byType(FinanceMonthTransition),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );

FinanceMonthTransition _transition(WidgetTester tester) =>
    tester.widget<FinanceMonthTransition>(find.byType(FinanceMonthTransition));

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('first load', () {
    testWidgets('shows the full skeleton, then the screen', (tester) async {
      final month = FakeMonthUseCase()..gates[4] = Completer<void>();
      await _pump(tester, month: month, pumpToIdle: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(FinancesLoadingSkeleton), findsOneWidget);
      expect(find.byType(BalanceHeaderCard), findsNothing);

      month.gates[4]!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(FinancesLoadingSkeleton), findsNothing);
      expect(find.byType(BalanceHeaderCard), findsOneWidget);
      expect(find.text(r'$1,004.00'), findsOneWidget);
    });
  });

  group('changing month', () {
    testWidgets(
        'keeps the header and dims the old figures while the next month loads',
        (tester) async {
      // March is held back from the start: the prefetch of the previous month
      // waits on it too, so the user really does wait when navigating there.
      final month = FakeMonthUseCase()..gates[3] = Completer<void>();
      final summary = FakeSummaryUseCase()..gates[3] = Completer<void>();
      await _pump(tester, month: month, summary: summary);
      expect(_header(tester).isStale, isFalse);
      expect(_transition(tester).isStale, isFalse);

      await tester.tap(find.bySemanticsLabel('Mes anterior'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Never the skeleton: header, label and arrows stay on screen.
      expect(find.byType(FinancesLoadingSkeleton), findsNothing);
      expect(find.byType(BalanceHeaderCard), findsOneWidget);
      expect(find.bySemanticsLabel('Mes anterior'), findsOneWidget);
      expect(find.bySemanticsLabel('Mes siguiente'), findsOneWidget);
      // The figures on screen are still April's, but flagged and dimmed.
      expect(find.text(r'$1,004.00'), findsOneWidget);
      expect(_header(tester).isStale, isTrue);
      expect(_transition(tester).isStale, isTrue);
      expect(_dim(tester).opacity, kFinanceStaleOpacity);
      // The refresh button swaps to its spinner.
      expect(find.byType(SacLoadingSmall), findsOneWidget);

      month.gates[3]!.complete();
      summary.gates[3]!.complete();
      await tester.pumpAndSettle();

      expect(find.text(r'$1,003.00'), findsOneWidget);
      expect(find.text(r'$1,004.00'), findsNothing);
      expect(_header(tester).isStale, isFalse);
      expect(_dim(tester).opacity, 1);
      expect(find.byType(SacLoadingSmall), findsNothing);
    });

    testWidgets('travelling backwards then forwards flips the direction',
        (tester) async {
      await _pump(tester);
      final notifier = tester.element(find.byType(FinancesView));
      final container = ProviderScope.containerOf(notifier);

      container.read(selectedMonthProvider.notifier).goToPrevious();
      await tester.pumpAndSettle();
      expect(_transition(tester).direction, -1);

      container.read(selectedMonthProvider.notifier).goToNext();
      await tester.pumpAndSettle();
      expect(_transition(tester).direction, 1);
    });

    testWidgets('a visited month comes back at once, without a new request',
        (tester) async {
      final env = await _pump(tester);
      final notifier = env.container.read(selectedMonthProvider.notifier);

      notifier.goToPrevious();
      await tester.pumpAndSettle();
      expect(find.text(r'$1,003.00'), findsOneWidget);

      notifier.goToNext();
      await tester.pump();

      expect(_header(tester).isStale, isFalse, reason: 'no loading state');
      expect(find.text(r'$1,004.00'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(env.month.callsFor(4), 1);
      expect(env.summary.calls.where((c) => c.month == 4), hasLength(1));
    });

    testWidgets('prefetches the previous month once the current one loaded',
        (tester) async {
      final env = await _pump(tester);

      expect(env.month.callsFor(3), 1);
      expect(env.summary.calls.where((c) => c.month == 3), hasLength(1));
      expect(env.breakdown.calls.where((c) => c.month == 3), hasLength(1));

      env.container.read(selectedMonthProvider.notifier).goToPrevious();
      await tester.pump();
      expect(_header(tester).isStale, isFalse);
      expect(find.text(r'$1,003.00'), findsOneWidget);
      expect(env.month.callsFor(3), 1);
    });

    testWidgets('a failing month keeps the header and shows the error',
        (tester) async {
      final failing = FailingMonthUseCase(FakeMonthUseCase(), failMonth: 3);
      await _pump(tester, monthUseCase: failing);
      // Month 3 was prefetched and failed silently; the user now opens it.
      final env = ProviderScope.containerOf(
        tester.element(find.byType(FinancesView)),
      );
      env.read(selectedMonthProvider.notifier).goToPrevious();
      await tester.pumpAndSettle();

      expect(find.byType(BalanceHeaderCard), findsOneWidget);
      expect(find.byType(SacErrorState), findsOneWidget);
      expect(_header(tester).isStale, isTrue);
      expect(find.byType(FinancesLoadingSkeleton), findsNothing);
    });
  });

  group('«Mes actual» button', () {
    testWidgets('is hidden on the current month', (tester) async {
      await _pump(tester, initial: null);

      expect(find.byTooltip('Ir al mes actual'), findsNothing);
    });

    testWidgets('appears on another month and jumps back to the current one',
        (tester) async {
      final env = await _pump(tester,
          initial: const SelectedMonth(year: 2020, month: 1));

      expect(find.byTooltip('Ir al mes actual'), findsOneWidget);

      await tester.tap(find.byTooltip('Ir al mes actual'));
      await tester.pumpAndSettle();

      expect(env.container.read(selectedMonthProvider).isCurrentMonth, isTrue);
      expect(find.byTooltip('Ir al mes actual'), findsNothing);
      // Travelling to the present is travelling forward.
      expect(_transition(tester).direction, 1);
    });
  });

  group('top bar menu', () {
    testWidgets('offers the options menu on your own club', (tester) async {
      await _pump(tester);

      expect(find.byTooltip('Más opciones'), findsOneWidget);
    });

    testWidgets('opens the month options sheet', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();

      expect(find.text('Opciones del mes'), findsOneWidget);
      expect(find.text('Exportar a Excel'), findsOneWidget);
      expect(find.text('Exportar a PDF'), findsOneWidget);
    });

    testWidgets('is hidden while acting for a dependent', (tester) async {
      await _pump(tester, acting: true);

      expect(find.byTooltip('Más opciones'), findsNothing);
    });
  });
}
