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
    });
  });
}
