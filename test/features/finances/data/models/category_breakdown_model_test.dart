import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/data/models/category_breakdown_model.dart';

void main() {
  group('CategoryBreakdownModel', () {
    test('parses income, expenses and totals in the order the API sends', () {
      final model = CategoryBreakdownModel.fromJson(const {
        'club_id': 1,
        'club_section_id': null,
        'period': '2026-04',
        'income': [
          {'category_id': 3, 'name': 'Cuotas', 'total': 500, 'count': 10},
          {'category_id': 8, 'name': 'Ventas', 'total': 120, 'count': 2},
        ],
        'expenses': [
          {'category_id': 2, 'name': 'Transporte', 'total': 300, 'count': 1},
        ],
        'totals': {'income': 620, 'expenses': 300},
      });

      expect(model.period, '2026-04');
      expect(model.income.map((e) => e.name), ['Cuotas', 'Ventas']);
      expect(model.income.first.categoryId, 3);
      expect(model.income.first.total, 500);
      expect(model.income.first.count, 10);
      expect(model.expenses.single.name, 'Transporte');
      expect(model.totalIncome, 620);
      expect(model.totalExpenses, 300);
      expect(model.isEmpty, isFalse);
    });

    test('is empty with empty lists and tolerates a missing totals block', () {
      final model = CategoryBreakdownModel.fromJson(const {
        'period': '2026-05',
        'income': [],
        'expenses': [],
      });

      expect(model.isEmpty, isTrue);
      expect(model.totalIncome, 0);
      expect(model.totalExpenses, 0);
    });

    test('sums the lists when totals are missing and parses string numbers',
        () {
      final model = CategoryBreakdownModel.fromJson(const {
        'period': '2026-05',
        'income': [
          {'category_id': '1', 'name': 'A', 'total': '40', 'count': '2'},
          {'category_id': 2, 'name': 'B', 'total': 60.5, 'count': 1},
        ],
        'expenses': [],
      });

      expect(model.income.first.categoryId, 1);
      expect(model.income.first.total, 40);
      expect(model.income.first.count, 2);
      expect(model.totalIncome, 100.5);
    });
  });
}
