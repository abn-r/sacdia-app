import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/data/models/finance_summary_model.dart';

void main() {
  group('FinanceSummaryModel', () {
    test('parses backend balance field as totalBalance', () {
      final model = FinanceSummaryModel.fromJson(const {
        'total_income': 650,
        'total_expense': 300,
        'balance': 350,
        'movement_count': 3,
      });

      expect(model.totalIncome, 650);
      expect(model.totalExpense, 300);
      expect(model.totalBalance, 350);
      expect(model.movementCount, 3);
    });

    test(
        'keeps the period totals apart from the all-time balance and the '
        'year-to-date figures', () {
      final model = FinanceSummaryModel.fromJson(const {
        'club_id': 4,
        'period': '2026-04',
        'total_income': 200,
        'total_expense': 50,
        'net': 150,
        'balance': 1800,
        'movement_count': 5,
        'year_income': 900,
        'year_expenses': 400,
        'period_closed': true,
      });

      expect(model.totalIncome, 200);
      expect(model.totalExpense, 50);
      expect(model.net, 150);
      expect(model.totalBalance, 1800);
      expect(model.yearIncome, 900);
      expect(model.yearExpense, 400);
      expect(model.periodClosed, isTrue);
    });

    test('period_closed is null without a month and false for an open one', () {
      final noMonth = FinanceSummaryModel.fromJson(const {
        'total_income': 1,
        'total_expense': 1,
        'period_closed': null,
      });
      final open = FinanceSummaryModel.fromJson(const {
        'total_income': 1,
        'total_expense': 1,
        'period_closed': false,
      });

      expect(noMonth.periodClosed, isNull);
      expect(open.periodClosed, isFalse);
    });

    test('derives net and falls back year figures to the period when absent',
        () {
      final model = FinanceSummaryModel.fromJson(const {
        'total_income': 300,
        'total_expense': 120,
        'balance': 10,
      });

      expect(model.net, 180);
      expect(model.yearIncome, 300);
      expect(model.yearExpense, 120);
      expect(model.periodClosed, isNull);
    });

    test('toEntity keeps the new fields', () {
      final entity = FinanceSummaryModel.fromJson(const {
        'total_income': 10,
        'total_expense': 4,
        'net': 6,
        'balance': 99,
        'year_income': 70,
        'year_expenses': 30,
        'movement_count': 2,
        'period_closed': false,
      }).toEntity();

      expect(entity.totalBalance, 99);
      expect(entity.yearIncome, 70);
      expect(entity.yearExpense, 30);
      expect(entity.movementCount, 2);
      expect(entity.periodClosed, isFalse);
    });
  });
}
