import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_category.dart';

void main() {
  group('FinanceCategory', () {
    test('uses backend type 0 as income only', () {
      const category = FinanceCategory(id: 1, name: 'Ventas', typeCode: 0);

      expect(category.appliesToIncome, isTrue);
      expect(category.appliesToExpense, isFalse);
    });

    test('uses backend non-zero type as expense', () {
      const category = FinanceCategory(
        id: 2,
        name: 'Seguro Médico',
        typeCode: 1,
      );

      expect(category.appliesToIncome, isFalse);
      expect(category.appliesToExpense, isTrue);
    });
  });
}
