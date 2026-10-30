/// Tests for [FinanceLineChart]: pins the FlSpot series handed to fl_chart so
/// library upgrades cannot silently change what is plotted.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_category.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_month.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_summary.dart';
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

const _summary = FinanceSummary(
  totalBalance: 0,
  totalIncome: 600,
  totalExpense: 300,
  monthlyBars: [
    // Deliberately unsorted: the chart sorts by year then month.
    MonthlyBar(year: 2026, month: 2, income: 200, expense: 50),
    MonthlyBar(year: 2025, month: 12, income: 100, expense: 40),
    MonthlyBar(year: 2026, month: 1, income: 300, expense: 210),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  String period = '1M',
  FinanceMonth? month,
  FinanceSummary? summary,
}) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        selectedPeriodProvider.overrideWith((ref) => period),
        financeMonthProvider.overrideWith((ref) async => month),
        financeSummaryProvider.overrideWith((ref) async => summary),
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

    testWidgets('keeps the visual configuration (axis, grid, lines, area)',
        (tester) async {
      await _pump(tester, month: _month);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(data.minY, 0);
      // 15 % headroom above the highest value (250).
      expect(data.maxY, closeTo(250 * 1.15, 1e-9));
      expect(data.clipData, const FlClipData.all());
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
      expect(items[0]!.textStyle.color, const Color(0xFF4FBF9F));
      expect(items[1]!.text, r'$80');
      expect(items[1]!.textStyle.color, const Color(0xFFDC2626));
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

  group('multi-period (monthly bars)', () {
    testWidgets('3M plots one spot per month, sorted, index on x',
        (tester) async {
      await _pump(tester, period: '3M', summary: _summary);

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(_xy(data.lineBarsData[0]), [(0, 100), (1, 300), (2, 200)]);
      expect(_xy(data.lineBarsData[1]), [(0, 40), (1, 210), (2, 50)]);
      expect(data.titlesData.bottomTitles.sideTitles.interval, 1);
      expect(data.maxY, closeTo(300 * 1.15, 1e-9));
    });

    testWidgets('6M keeps only the last bars and still renders',
        (tester) async {
      await _pump(tester, period: '6M', summary: _summary);

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData[0].spots, hasLength(3));
      expect(find.text('Dic'), findsOneWidget);
    });

    testWidgets('shows the empty state with no summary', (tester) async {
      await _pump(tester, period: '3M', summary: null);

      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Sin datos para el período'), findsOneWidget);
    });
  });
}
