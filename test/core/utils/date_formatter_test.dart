import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';

void main() {
  group('SacDateFormatter.parseCalendarDate', () {
    test('keeps calendar day from UTC midnight ISO', () {
      final date = SacDateFormatter.parseCalendarDate(
        '2026-08-21T00:00:00.000Z',
      );

      expect(date.year, 2026);
      expect(date.month, 8);
      expect(date.day, 21);
      expect(date.isUtc, isFalse);
    });

    test('keeps date-only YYYY-MM-DD', () {
      final date = SacDateFormatter.parseCalendarDate('2026-08-23');

      expect(date.year, 2026);
      expect(date.month, 8);
      expect(date.day, 23);
    });
  });
}
