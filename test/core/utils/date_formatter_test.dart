import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

  group('SacDateFormatter follows the app language', () {
    final date = DateTime(2026, 3, 25, 14, 30);
    late String? previous;

    setUp(() => previous = Intl.defaultLocale);
    tearDown(() => Intl.defaultLocale = previous);

    String under(String locale, String Function() run) {
      Intl.defaultLocale = locale;
      return run();
    }

    test('dateShort changes with Intl.defaultLocale', () {
      expect(
          under('es', () => SacDateFormatter.dateShort(date)), '25 mar 2026');
      expect(
          under('en', () => SacDateFormatter.dateShort(date)), '25 Mar 2026');
      expect(
          under('fr', () => SacDateFormatter.dateShort(date)), '25 mars 2026');
      expect(under('pt_BR', () => SacDateFormatter.dateShort(date)),
          '25 mar. 2026');
    });

    test('monthYear changes with Intl.defaultLocale', () {
      expect(under('es', () => SacDateFormatter.monthYear(date)), 'marzo 2026');
      expect(under('en', () => SacDateFormatter.monthYear(date)), 'March 2026');
      expect(under('fr', () => SacDateFormatter.monthYear(date)), 'mars 2026');
      expect(
          under('pt_BR', () => SacDateFormatter.monthYear(date)), 'março 2026');
    });

    test('dateFormal is locale aware (no Spanish literals)', () {
      expect(under('es', () => SacDateFormatter.dateFormal(date)),
          '25 de marzo de 2026');
      expect(under('en', () => SacDateFormatter.dateFormal(date)),
          'March 25, 2026');
    });

    test('an explicit locale still wins', () {
      Intl.defaultLocale = 'en';
      expect(SacDateFormatter.format(date, 'MMMM', locale: 'fr'), 'mars');
    });

    test('iso is locale free', () {
      for (final l in ['es', 'en', 'fr', 'pt_BR']) {
        expect(under(l, () => SacDateFormatter.iso(date)), '2026-03-25');
      }
    });
  });

  group('SacDateFormatter.range', () {
    late String? previous;
    setUp(() => previous = Intl.defaultLocale);
    tearDown(() => Intl.defaultLocale = previous);

    test('same month collapses to day – full date', () {
      Intl.defaultLocale = 'es';
      expect(
        SacDateFormatter.range(DateTime(2026, 4, 3), DateTime(2026, 4, 5)),
        '3 – 5 abr 2026',
      );
    });

    test('same year keeps both months, year once', () {
      Intl.defaultLocale = 'es';
      expect(
        SacDateFormatter.range(DateTime(2026, 3, 28), DateTime(2026, 4, 2)),
        '28 mar – 2 abr 2026',
      );
    });

    test('different years show both full dates', () {
      Intl.defaultLocale = 'es';
      expect(
        SacDateFormatter.range(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
        '30 dic 2026 – 2 ene 2027',
      );
    });

    test('follows the language', () {
      Intl.defaultLocale = 'en';
      expect(
        SacDateFormatter.range(DateTime(2026, 4, 3), DateTime(2026, 4, 5)),
        '3 – 5 Apr 2026',
      );
    });

    test('same day and single bound show one date', () {
      Intl.defaultLocale = 'es';
      expect(
        SacDateFormatter.range(DateTime(2026, 4, 3), DateTime(2026, 4, 3)),
        '3 abr 2026',
      );
      expect(SacDateFormatter.range(DateTime(2026, 4, 3), null), '3 abr 2026');
      expect(SacDateFormatter.range(null, null), '');
    });

    test('calendar: false converts UTC to local, true does not', () {
      Intl.defaultLocale = 'es';
      final utc = DateTime.utc(2026, 4, 3, 12);
      final local = utc.toLocal();
      expect(
        SacDateFormatter.range(utc, utc, calendar: true),
        '3 abr 2026',
      );
      expect(
        SacDateFormatter.range(utc, utc, calendar: false),
        '${local.day} ${DateFormat('MMM yyyy').format(local)}',
      );
    });
  });
}
