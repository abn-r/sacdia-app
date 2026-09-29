import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/l10n/sunday_first_material_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const delegate = SundayFirstMaterialLocalizationsDelegate();

  test('spanish and french calendars start on Sunday', () async {
    for (final locale in const [Locale('es'), Locale('fr'), Locale('en')]) {
      final localizations = await delegate.load(locale);
      expect(localizations.firstDayOfWeekIndex, 0, reason: locale.toString());
    }
  });

  test('month grid leaves Sunday in the first column', () async {
    final localizations = await delegate.load(const Locale('es'));
    // 1 Sep 2026 is Tuesday. Sunday-first grid has two leading blanks.
    final offset = const GregorianCalendarDelegate().firstDayOffset(
      2026,
      9,
      localizations,
    );
    expect(DateTime(2026, 9, 1).weekday, DateTime.tuesday);
    expect(offset, 2);
  });
}
