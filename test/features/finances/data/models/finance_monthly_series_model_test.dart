import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/data/models/finance_monthly_series_model.dart';

void main() {
  group('FinanceMonthlySeriesModel', () {
    test('parses the backend items and sorts them by month', () {
      final model = FinanceMonthlySeriesModel.fromJson(const {
        'club_id': 4,
        'club_section_id': null,
        'from': '2026-01',
        'to': '2026-03',
        'items': [
          {
            'year': 2026,
            'month': 2,
            'income': 200,
            'expenses': 50,
            'net': 150,
            'balance': 400,
          },
          {
            'year': 2025,
            'month': 12,
            'income': 100,
            'expenses': 0,
            'net': 100,
            'balance': 250,
          },
        ],
      });

      expect(
          model.items.map((p) => (p.year, p.month)), [(2025, 12), (2026, 2)]);
      final feb = model.items.last;
      expect(feb.income, 200);
      expect(feb.expenses, 50);
      expect(feb.net, 150);
      expect(feb.balance, 400);
      expect(model.totalIncome, 300);
      expect(model.totalExpenses, 50);
      expect(model.isEmpty, isFalse);
    });

    test('derives net when absent and tolerates numeric strings', () {
      final model = FinanceMonthlySeriesModel.fromJson(const {
        'items': [
          {'year': '2026', 'month': '3', 'income': '90.5', 'expenses': 40},
        ],
      });

      expect(model.items.single.month, 3);
      expect(model.items.single.net, 50.5);
      expect(model.items.single.balance, 0);
    });

    test('an empty or missing list is an empty series', () {
      expect(
        FinanceMonthlySeriesModel.fromJson(const {'items': []}).isEmpty,
        isTrue,
      );
      expect(FinanceMonthlySeriesModel.fromJson(const {}).items, isEmpty);
    });

    test('a series of only zero months counts as empty', () {
      final model = FinanceMonthlySeriesModel.fromJson(const {
        'items': [
          {'year': 2026, 'month': 1, 'income': 0, 'expenses': 0, 'balance': 9},
        ],
      });
      expect(model.items, hasLength(1));
      expect(model.isEmpty, isTrue);
    });

    test('toEntity keeps the points', () {
      final model = FinanceMonthlySeriesModel.fromJson(const {
        'items': [
          {'year': 2026, 'month': 1, 'income': 1, 'expenses': 0},
        ],
      });
      expect(model.toEntity().items, model.items);
    });
  });
}
