import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/features/finances/domain/entities/category_breakdown.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_category.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_month.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_summary.dart';
import 'package:sacdia_app/features/finances/domain/entities/transaction.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';
import 'package:sacdia_app/features/finances/presentation/views/finances_view.dart';

import '../../../coordinator/coordinator_test_harness.dart';
import '../../../../support/riverpod_test_support.dart';

final _transaction = FinanceTransaction(
  id: 1,
  type: TransactionType.income,
  amount: 100,
  description: 'Cuota abril',
  date: DateTime(2026, 4, 10),
  year: 2026,
  month: 4,
  category: const FinanceCategory(id: 1, name: 'Cuotas'),
  registeredByName: 'Ana',
  registeredAt: DateTime(2026, 4, 10),
);

// The list endpoint says 1000 / 10 for the month; the summary (the source of
// truth for the header) says 200 / 50 so a test can tell which one is shown.
final _month = FinanceMonth(
  year: 2026,
  month: 4,
  isOpen: true,
  totalBalance: 0,
  totalIncome: 1000,
  totalExpense: 10,
  transactions: [_transaction],
);

FinanceSummary _summary({bool? periodClosed}) => FinanceSummary(
      totalBalance: 1800,
      totalIncome: 200,
      totalExpense: 50,
      net: 150,
      yearIncome: 900,
      yearExpense: 400,
      periodClosed: periodClosed,
      monthlyBars: const [],
    );

const _breakdown = CategoryBreakdown(
  period: '2026-04',
  income: [
    CategoryTotal(categoryId: 1, name: 'Cuotas', total: 150, count: 3),
    CategoryTotal(categoryId: 2, name: 'Ventas', total: 50, count: 1),
  ],
  expenses: [
    CategoryTotal(categoryId: 5, name: 'Transporte', total: 50, count: 2),
  ],
  totalIncome: 200,
  totalExpenses: 50,
);

Future<void> _pump(
  WidgetTester tester, {
  FinanceSummary? summary,
  Future<CategoryBreakdown?> Function()? breakdown,
  bool canManage = true,
}) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        selectedMonthProvider.overrideWith(
          () => _FixedMonth(),
        ),
        currentClubIdProvider.overrideWith((ref) async => 1),
        financeMonthByKeyProvider.overrideWith((ref, key) async => _month),
        financeSummaryByKeyProvider.overrideWith((ref, key) async => summary),
        financeByCategoryByKeyProvider.overrideWith(
          (ref, key) => (breakdown ?? () async => _breakdown)(),
        ),
        canManageFinancesProvider.overrideWith((ref) async => canManage),
      ],
      child: localized(
        (context) => localizedApp(context, const FinancesView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedMonth extends SelectedMonthNotifier {
  @override
  SelectedMonth build() => const SelectedMonth(year: 2026, month: 4);
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('header', () {
    testWidgets(
        'labels the balance as accumulated and shows it from the '
        'summary', (tester) async {
      await _pump(tester, summary: _summary(periodClosed: false));

      expect(find.text('SALDO ACUMULADO'), findsOneWidget);
      expect(find.text(r'$1,800.00'), findsOneWidget);
    });

    testWidgets(
        'shows the month income and expense from the summary, not '
        'the list', (tester) async {
      await _pump(tester, summary: _summary(periodClosed: false));

      final summaryText = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText())
          .firstWhere((t) => t.startsWith('Este mes'));
      expect(summaryText, contains(r'$200.00'));
      expect(summaryText, contains(r'$50.00'));
      expect(summaryText, isNot(contains(r'$1,000.00')));
    });
  });

  group('closed period', () {
    testWidgets(
        'shows the banner and hides the add button when the summary '
        'says the month is closed', (tester) async {
      await _pump(tester, summary: _summary(periodClosed: true));

      expect(find.textContaining('Este período está cerrado'), findsOneWidget);
      expect(find.byTooltip('Nuevo Movimiento'), findsNothing);
    });

    testWidgets('no banner and an add button for an open month',
        (tester) async {
      await _pump(tester, summary: _summary(periodClosed: false));

      expect(find.textContaining('Este período está cerrado'), findsNothing);
      expect(find.byTooltip('Nuevo Movimiento'), findsOneWidget);
    });

    testWidgets('without permission there is no add button even when open',
        (tester) async {
      await _pump(
        tester,
        summary: _summary(periodClosed: false),
        canManage: false,
      );

      expect(find.byTooltip('Nuevo Movimiento'), findsNothing);
    });
  });

  group('by category', () {
    testWidgets('lists income and expense categories with totals and counts',
        (tester) async {
      await _pump(tester, summary: _summary(periodClosed: false));

      expect(find.text('Por categoría'), findsOneWidget);
      expect(find.text('Cuotas'), findsWidgets);
      expect(find.text('Ventas'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text(r'+$150.00'), findsOneWidget);
      expect(find.text(r'−$50.00'), findsWidgets);
      expect(find.textContaining('3 movimientos'), findsOneWidget);
      expect(find.textContaining('1 movimiento ·'), findsOneWidget);
      // Share of the group: 150 of 200 income = 75 %.
      expect(find.textContaining('75 % del total'), findsOneWidget);
    });

    testWidgets('shows the empty state when the month has no movements',
        (tester) async {
      await _pump(
        tester,
        summary: _summary(periodClosed: false),
        breakdown: () async => const CategoryBreakdown(
          period: '2026-04',
          income: [],
          expenses: [],
          totalIncome: 0,
          totalExpenses: 0,
        ),
      );

      expect(
        find.text('No hay movimientos por categoría este mes'),
        findsOneWidget,
      );
    });

    testWidgets('shows an error with retry when the request fails',
        (tester) async {
      var calls = 0;
      await _pump(
        tester,
        summary: _summary(periodClosed: false),
        breakdown: () async {
          calls++;
          throw Exception('sin conexión');
        },
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      final before = calls;

      await tester.tap(
        find.descendant(
          of: find.byType(SacErrorState),
          matching: find.byType(SacButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, greaterThan(before));
    });
  });
}
