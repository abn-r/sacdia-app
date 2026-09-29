import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

/// Material calendars follow the locale week start. Spanish and French start
/// on Monday. SACDIA calendars always start on Sunday.
///
/// Flutter maps `DateSymbols.FIRSTDAYOFWEEK` with `(value + 1) % 7`. `6`
/// lands on index 0, and [MaterialLocalizations.narrowWeekdays] index 0 is
/// Sunday.
class SundayFirstMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const SundayFirstMaterialLocalizationsDelegate();

  static const int sundayFirstDayOfWeek = 6;

  @override
  bool isSupported(Locale locale) =>
      GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final localizations =
        await GlobalMaterialLocalizations.delegate.load(locale);
    forceSundayWeekStart(locale);
    return localizations;
  }

  @override
  bool shouldReload(SundayFirstMaterialLocalizationsDelegate old) => false;
}

void forceSundayWeekStart(Locale locale) {
  final names = <String>{
    intl.Intl.canonicalizedLocale(locale.toString()),
    locale.toString(),
    locale.languageCode,
  };
  for (final name in names) {
    if (!intl.DateFormat.localeExists(name)) continue;
    intl.DateFormat.yMMMMEEEEd(name).dateSymbols.FIRSTDAYOFWEEK =
        SundayFirstMaterialLocalizationsDelegate.sundayFirstDayOfWeek;
  }
}
