import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/data/models/finance_month_model.dart';

Map<String, dynamic> _row(int id, {bool? closed}) => {
      'id': id,
      'type': 'income',
      'amount': 100,
      'description': 'Cuota $id',
      'date': '2026-04-10',
      'year': 2026,
      'month': 4,
      if (closed != null) 'period_closed': closed,
      'category': {'id': 1, 'name': 'Cuotas', 'typeCode': 0},
    };

void main() {
  group('FinanceMonthModel', () {
    test('is closed when the movements carry period_closed', () {
      final month = FinanceMonthModel.fromJson(
        {
          'data': [_row(1, closed: true), _row(2, closed: true)],
        },
        year: 2026,
        month: 4,
      );

      expect(month.isOpen, isFalse);
      expect(month.transactions.every((t) => t.periodClosed), isTrue);
    });

    test('is open for open movements, an empty month or no flag', () {
      final open = FinanceMonthModel.fromJson(
        {
          'data': [_row(1, closed: false)],
        },
        year: 2026,
        month: 4,
      );
      final empty = FinanceMonthModel.fromJson(
        const {'data': []},
        year: 2026,
        month: 4,
      );
      final legacy = FinanceMonthModel.fromJson(
        {
          'data': [_row(1)],
        },
        year: 2026,
        month: 4,
      );

      expect(open.isOpen, isTrue);
      expect(empty.isOpen, isTrue);
      expect(legacy.isOpen, isTrue);
    });
  });
}
