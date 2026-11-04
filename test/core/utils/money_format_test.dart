import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/utils/money_format.dart';

void main() {
  group('SacMoney.format', () {
    test('uses es_MX grouping and two decimals', () {
      expect(SacMoney.format(1234.5), r'$1,234.50');
      expect(SacMoney.format(0), r'$0.00');
      expect(SacMoney.format(1000000), r'$1,000,000.00');
    });

    test('has no currency suffix', () {
      expect(SacMoney.format(10), isNot(contains('MXN')));
    });

    test('does not follow the app language', () {
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);
      for (final locale in ['es', 'en', 'fr', 'pt_BR']) {
        Intl.defaultLocale = locale;
        expect(SacMoney.format(1234.5), r'$1,234.50', reason: locale);
      }
    });

    test('negative unsigned keeps a hyphen', () {
      expect(SacMoney.format(-5), r'-$5.00');
    });

    test('signed adds + or the real minus U+2212, zero has none', () {
      expect(SacMoney.format(1234.5, signed: true), r'+$1,234.50');
      expect(SacMoney.format(-1234.5, signed: true), '−\$1,234.50');
      expect(SacMoney.format(0, signed: true), r'$0.00');
      expect(SacMoney.format(-0.001, signed: true), r'$0.00');
    });
  });

  group('SacMoney.fromCentavos', () {
    test('converts centavos to pesos', () {
      expect(SacMoney.fromCentavos(123450), r'$1,234.50');
      expect(SacMoney.fromCentavos(5), r'$0.05');
      expect(SacMoney.fromCentavos(0), r'$0.00');
    });

    test('supports signed', () {
      expect(SacMoney.fromCentavos(1000, signed: true), r'+$10.00');
      expect(SacMoney.fromCentavos(-1000, signed: true), '−\$10.00');
    });
  });

  group('SacMoney.compact', () {
    test('shows plain integers below one thousand', () {
      expect(SacMoney.compact(0), r'$0');
      expect(SacMoney.compact(950), r'$950');
      expect(SacMoney.compact(950.4), r'$950');
    });

    test('uses k with one decimal under 10k and none from 10k', () {
      expect(SacMoney.compact(1000), r'$1k');
      expect(SacMoney.compact(1234), r'$1.2k');
      expect(SacMoney.compact(9990), r'$10k');
      expect(SacMoney.compact(12000), r'$12k');
      expect(SacMoney.compact(12500), r'$13k');
    });

    test('uses M from one million', () {
      expect(SacMoney.compact(1500000), r'$1.5M');
      expect(SacMoney.compact(1000000), r'$1M');
      expect(SacMoney.compact(25000000), r'$25M');
    });

    test('rolls over at rounding boundaries', () {
      expect(SacMoney.compact(999.6), r'$1k');
      expect(SacMoney.compact(999600), r'$1M');
    });

    test('never ends with .0', () {
      expect(SacMoney.compact(2000), isNot(contains('.0')));
    });
  });

  test('tabularFigures carries the tabular feature', () {
    expect(SacMoney.tabularFigures, hasLength(1));
    expect(SacMoney.tabularFigures.first.feature, 'tnum');
  });
}
