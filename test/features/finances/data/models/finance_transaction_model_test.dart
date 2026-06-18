import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/data/models/finance_category_model.dart';
import 'package:sacdia_app/features/finances/data/models/transaction_model.dart';
import 'package:sacdia_app/features/finances/domain/entities/transaction.dart';

void main() {
  group('FinanceCategoryModel', () {
    test('parses paginated response iconIndex and typeCode aliases', () {
      final category = FinanceCategoryModel.fromJson(const {
        'id': 8,
        'name': 'Ventas',
        'iconIndex': 8,
        'typeCode': 0,
      });

      expect(category.id, 8);
      expect(category.iconIndex, 8);
      expect(category.typeCode, 0);
      expect(category.appliesToIncome, isTrue);
    });
  });

  group('FinanceTransactionModel', () {
    test('infers expense from backend category type 1', () {
      final transaction = FinanceTransactionModel.fromJson(const {
        'finance_id': 10,
        'amount': 250,
        'description': 'Pago de seguros médicos',
        'finance_date': '2026-06-18',
        'year': 2026,
        'month': 6,
        'created_at': '2026-06-18T16:57:00Z',
        'finances_categories': {
          'finance_category_id': 2,
          'name': 'Seguro Médico',
          'type': 1,
          'icon': 5,
        },
      });

      expect(transaction.type, TransactionType.expense);
      expect(transaction.category.typeCode, 1);
      expect(transaction.category.appliesToExpense, isTrue);
    });

    test('keeps income from backend category type 0', () {
      final transaction = FinanceTransactionModel.fromJson(const {
        'finance_id': 11,
        'amount': 300,
        'description': 'Ganancias ventas',
        'finance_date': '2026-06-18',
        'year': 2026,
        'month': 6,
        'created_at': '2026-06-18T16:57:00Z',
        'finances_categories': {
          'finance_category_id': 8,
          'name': 'Ventas',
          'type': 0,
          'icon': 8,
        },
      });

      expect(transaction.type, TransactionType.income);
      expect(transaction.category.typeCode, 0);
      expect(transaction.category.appliesToIncome, isTrue);
    });
  });
}
