/// Tests for [FinanceLineChart]: pins the FlSpot series handed to fl_chart so
/// library upgrades cannot silently change what is plotted.
library;

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_category.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_month.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_monthly_series.dart';
import 'package:sacdia_app/features/finances/domain/entities/transaction.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';
import 'package:sacdia_app/features/finances/presentation/widgets/finance_line_chart.dart';

import '../../../coordinator/coordinator_test_harness.dart';
import '../../../../support/riverpod_test_support.dart';

const _category = FinanceCategory(id: 1, name: 'General');

FinanceTransaction _tx(
  int id,
  TransactionType type,
  double amount,
  int day,
) =>
    FinanceTransaction(
      id: id,
      type: type,
      amount: amount,
      description: 'tx $id',
      date: DateTime(2026, 2, day),
      year: 2026,
      month: 2,
      category: _category,
      registeredByName: 'Tester',
      registeredAt: DateTime(2026, 2, day),
    );

// February 2026 has 28 days. Two incomes on day 3 aggregate to 150.
final _month = FinanceMonth(
  year: 2026,
  month: 2,
  isOpen: true,
  totalBalance: 0,
  totalIncome: 400,
  totalExpense: 80,
  transactions: [
    _tx(1, TransactionType.income, 100, 3),
    _tx(2, TransactionType.income, 50, 3),
    _tx(3, TransactionType.income, 250, 20),
    _tx(4, TransactionType.expense, 80, 10),
  ],
);

// Deliberately NOT the order the chart gets them in: the model sorts, the
// chart plots the series as given (x = index).
const _series = FinanceMonthlySeries(
  items: [
    FinanceMonthlyPoint(
      year: 2025,
      month: 12,
      income: 100,
      expenses: 40,
      net: 60,
      balance: 60,
    ),
    FinanceMonthlyPoint(
      year: 2026,
      month: 1,
      income: 300,
      expenses: 210,
      net: 90,
      balance: 150,
    ),
    FinanceMonthlyPoint(
      year: 2026,
      month: 2,
      income: 200,
      expenses: 50,
      net: 150,
      balance: 300,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  String period = '1M',
  FinanceMonth? month,
  FinanceMonthlySeries? series,
  FutureOr<FinanceMonthlySeries?> Function()? seriesLoader,
}) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        selectedPeriodProvider.overrideWith((ref) => period),
        currentClubIdProvider.overrideWith((ref) async => 1),
        financeMonthByKeyProvider.overrideWith((ref, key) async => month),
        financeSeriesByKeyProvider
            .overrideWith((ref, key) async => seriesLoader?.call() ?? series),
      ],
      child: localized(
        (context) => localizedApp(
          context,
          const Scaffold(
              body: SingleChildScrollView(child: FinanceLineChart())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<(double, double)> _xy(LineChartBarData bar) =>
    bar.spots.map((s) => (s.x, s.y)).toList();

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('1M (daily aggregation)', () {
    testWidgets('plots income and expense per day with the same FlSpot data',
        (tester) async {
      await _pump(tester, month: _month);

      expect(find.byType(LineChart), findsOneWidget);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData, hasLength(2));

      final income = data.lineBarsData[0];
      final expense = data.lineBarsData[1];
      expect(income.spots, hasLength(28));
      expect(expense.spots, hasLength(28));

      // x is the day number, 1..28.
      expect(income.spots.first.x, 1);
      expect(income.spots.last.x, 28);
      expect(expense.spots.map((s) => s.x), income.spots.map((s) => s.x));

      final incomeByDay = {for (final s in income.spots) s.x.toInt(): s.y};
      final expenseByDay = {for (final s in expense.spots) s.x.toInt(): s.y};
      expect(incomeByDay[3], 150);
      expect(incomeByDay[20], 250);
      expect(expenseByDay[10], 80);
      // Days with no movement are plotted as zero, not skipped.
      expect(incomeByDay[1], 0);
      expect(incomeByDay[10], 0);
      expect(expenseByDay[3], 0);
      expect(incomeByDay.values.reduce((a, b) => a + b), 400);
      expect(expenseByDay.values.reduce((a, b) => a + b), 80);
    });

    testWidgets('gives the plot a text alternative with the period totals',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, month: _month);

      expect(
        find.bySemanticsLabel(
          r'Gráfico de ingresos y egresos del periodo. '
          r'Ingresos: $400.00. Egresos: $80.00.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('keeps the visual configuration (axis, grid, lines, area)',
        (tester) async {
      await _pump(tester, month: _month);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(data.minY, 0);
      // 15 % headroom above the highest value (250).
      expect(data.maxY, closeTo(250 * 1.15, 1e-9));
      expect(data.clipData.bottom, isFalse,
          reason: 'a line at 0 must not be cut');
      expect(data.clipData.top, isTrue);
      expect(data.borderData.show, isFalse);
      expect(data.gridData.drawVerticalLine, isFalse);
      expect(data.gridData.horizontalInterval, closeTo(data.maxY / 4, 1e-9));
      expect(data.titlesData.topTitles.sideTitles.showTitles, isFalse);
      expect(data.titlesData.rightTitles.sideTitles.showTitles, isFalse);
      expect(data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
      expect(data.titlesData.leftTitles.sideTitles.reservedSize, 40);
      expect(data.titlesData.bottomTitles.sideTitles.showTitles, isTrue);
      expect(data.titlesData.bottomTitles.sideTitles.interval, 7);

      const incomeColor = Color(0xFF4FBF9F);
      const expenseColor = Color(0xFFDC2626);
      final income = data.lineBarsData[0];
      final expense = data.lineBarsData[1];
      expect(income.color, incomeColor);
      expect(expense.color, expenseColor);
      for (final bar in data.lineBarsData) {
        expect(bar.isCurved, isTrue);
        expect(bar.preventCurveOverShooting, isTrue);
        expect(bar.curveSmoothness, 0.35);
        expect(bar.barWidth, 2.5);
        expect(bar.dotData.show, isFalse);
        expect(bar.belowBarData.show, isTrue);
        expect(bar.belowBarData.gradient, isNotNull);
      }
    });

    testWidgets('tooltip colors income green and expense red', (tester) async {
      await _pump(tester, month: _month);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineTouchData.handleBuiltInTouches, isTrue);

      final tooltip = data.lineTouchData.touchTooltipData;
      expect(
          tooltip.getTooltipColor(LineBarSpot(
            data.lineBarsData[0],
            0,
            data.lineBarsData[0].spots.first,
          )),
          Colors.white);

      final items = tooltip.getTooltipItems([
        LineBarSpot(data.lineBarsData[0], 0, const FlSpot(3, 1500)),
        LineBarSpot(data.lineBarsData[1], 1, const FlSpot(3, 80)),
      ]);
      expect(items, hasLength(2));
      expect(items[0]!.text, r'$1.5k');
      expect(items[0]!.textStyle.color,
          const SacColors(Brightness.light).onSuccessContainer);
      expect(items[1]!.text, r'$80');
      expect(items[1]!.textStyle.color,
          const SacColors(Brightness.light).onErrorContainer);
    });

    testWidgets('shows the empty state without transactions', (tester) async {
      await _pump(
        tester,
        month: const FinanceMonth(
          year: 2026,
          month: 2,
          isOpen: true,
          totalBalance: 0,
          totalIncome: 0,
          totalExpense: 0,
          transactions: [],
        ),
      );

      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Sin datos para el período'), findsOneWidget);
    });
  });

  group('card title follows the period', () {
    for (final (period, title) in [
      ('1M', 'Resumen del mes'),
      ('3M', 'Últimos 3 meses'),
      ('6M', 'Últimos 6 meses'),
      ('1A', 'Últimos 12 meses'),
      ('Todo', 'Todo el historial'),
    ]) {
      testWidgets('$period -> $title', (tester) async {
        await _pump(tester, period: period, month: _month, series: _series);
        expect(find.text(title), findsOneWidget);
      });
    }
  });

  group('multi-period (monthly series)', () {
    testWidgets('3M plots one spot per month, index on x', (tester) async {
      await _pump(tester, period: '3M', series: _series);

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(_xy(data.lineBarsData[0]), [(0, 100), (1, 300), (2, 200)]);
      expect(_xy(data.lineBarsData[1]), [(0, 40), (1, 210), (2, 50)]);
      expect(data.titlesData.bottomTitles.sideTitles.interval, 1);
      expect(data.maxY, closeTo(300 * 1.15, 1e-9));
      expect(data.minX, 0);
      expect(data.maxX, 2);
    });

    testWidgets('labels the months with the app locale', (tester) async {
      await _pump(tester, period: '3M', series: _series);

      expect(find.text('Dic'), findsOneWidget);
      expect(find.text('Ene'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
    });

    testWidgets('Todo labels month and two-digit year', (tester) async {
      await _pump(tester, period: 'Todo', series: _series);

      expect(find.text('Dic 25'), findsOneWidget);
      expect(find.text('Feb 26'), findsOneWidget);
    });

    testWidgets('a text alternative announces the range and its totals',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, period: '6M', series: _series);

      expect(
        find.bySemanticsLabel(RegExp(
          r'Gráfico de ingresos y egresos de .*dic.* 2025 a .*feb.* 2026\. '
          r'Ingresos: \$600\.00\. Egresos: \$300\.00\.',
        )),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a single month still renders', (tester) async {
      await _pump(
        tester,
        period: 'Todo',
        series: const FinanceMonthlySeries(
          items: [
            FinanceMonthlyPoint(
              year: 2026,
              month: 2,
              income: 10,
              expenses: 0,
              net: 10,
              balance: 10,
            ),
          ],
        ),
      );

      expect(find.byType(LineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the empty state with no series', (tester) async {
      await _pump(tester, period: '3M', series: null);

      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Sin datos para el período'), findsOneWidget);
    });

    testWidgets('shows the empty state when every month is zero',
        (tester) async {
      await _pump(
        tester,
        period: '1A',
        series: const FinanceMonthlySeries(
          items: [
            FinanceMonthlyPoint(
              year: 2026,
              month: 1,
              income: 0,
              expenses: 0,
              net: 0,
              balance: 500,
            ),
          ],
        ),
      );

      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Sin datos para el período'), findsOneWidget);
    });

    testWidgets('shows a loader while the series loads', (tester) async {
      final gate = Completer<FinanceMonthlySeries?>();
      useTallSurface(tester);
      await tester.pumpWidget(
        testProviderScope(
          overrides: [
            selectedPeriodProvider.overrideWith((ref) => '3M'),
            currentClubIdProvider.overrideWith((ref) async => 1),
            financeSeriesByKeyProvider.overrideWith((ref, key) => gate.future),
          ],
          child: localized(
            (context) => localizedApp(
              context,
              const Scaffold(
                body: SingleChildScrollView(child: FinanceLineChart()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Sin datos para el período'), findsNothing);
      gate.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('shows an error with retry when the series fails',
        (tester) async {
      await _pump(
        tester,
        period: '3M',
        seriesLoader: () => throw Exception('boom'),
      );

      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
