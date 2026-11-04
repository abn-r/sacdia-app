import 'package:intl/intl.dart';

final _isoDatePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// Utilidad centralizada para formatear fechas.
///
/// Sin `locale` explícito usa el idioma vigente de la app (`Intl.defaultLocale`,
/// sincronizado con easy_localization en `main.dart`): las fechas siguen el
/// idioma que el usuario eligió. No fijes `'es'` en ningún `DateFormat`.
///
/// Timestamps (`created_at`, `paid_at`, etc.): [format] convierte UTC → local.
/// Fechas de calendario (`start_date` / `end_date` como `YYYY-MM-DD`):
/// [parseCalendarDate] + [formatCalendar]. No usar [DateTime.parse] + [toLocal]
/// en esos campos: medianoche UTC en México muestra el día anterior.
class SacDateFormatter {
  SacDateFormatter._();

  /// Día de calendario desde prefijo ISO `YYYY-MM-DD`.
  ///
  /// `2026-08-21T00:00:00.000Z` queda 21 ago, no 20, fuera de UTC.
  static DateTime parseCalendarDate(String raw) {
    final match = _isoDatePrefix.firstMatch(raw.trim());
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.parse(raw);
  }

  static DateTime? tryParseCalendarDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return parseCalendarDate(raw);
    } catch (_) {
      return null;
    }
  }

  /// Formatea una fecha de calendario sin convertir zona horaria.
  static String formatCalendar(
    DateTime? date,
    String pattern, {
    String? locale,
  }) {
    if (date == null) return '';
    return DateFormat(pattern, locale).format(date);
  }

  /// Formatea una fecha UTC a local con el patrón dado.
  /// Retorna cadena vacía si la fecha es null.
  static String format(DateTime? date, String pattern, {String? locale}) {
    if (date == null) return '';
    return DateFormat(pattern, locale).format(date.toLocal());
  }

  /// Rango compacto en el idioma vigente, colapsando mes/año repetidos:
  /// "3 – 5 abr 2026" · "28 mar – 2 abr 2026" · "30 dic 2026 – 2 ene 2027".
  ///
  /// [calendar] = true (por defecto) trata las fechas como días de calendario
  /// (sin conversión UTC → local); false las trata como timestamps.
  static String range(
    DateTime? start,
    DateTime? end, {
    bool calendar = true,
    String? locale,
  }) {
    if (start == null && end == null) return '';
    DateTime norm(DateTime d) => calendar ? d : d.toLocal();
    final full = DateFormat('d MMM yyyy', locale);
    if (start == null || end == null) return full.format(norm(start ?? end!));
    final s = norm(start);
    final e = norm(end);
    if (s.year == e.year && s.month == e.month) {
      if (s.day == e.day) return full.format(e);
      return '${s.day} – ${full.format(e)}';
    }
    if (s.year == e.year) {
      return '${DateFormat('d MMM', locale).format(s)} – ${full.format(e)}';
    }
    return '${full.format(s)} – ${full.format(e)}';
  }

  /// dd/MM/yyyy — "25/03/2026"
  static String date(DateTime? date) => format(date, 'dd/MM/yyyy');

  /// d MMM yyyy — "25 mar 2026"
  static String dateShort(DateTime? date) => format(date, 'd MMM yyyy');

  /// d MMM — "25 mar"
  static String dayMonth(DateTime? date) => format(date, 'd MMM');

  /// dd/MM/yyyy HH:mm — "25/03/2026 14:30"
  static String dateTime(DateTime? date) => format(date, 'dd/MM/yyyy HH:mm');

  /// d MMM yyyy, HH:mm — "25 mar 2026, 14:30"
  static String dateTimeShort(DateTime? date) =>
      format(date, 'd MMM yyyy, HH:mm');

  /// HH:mm — "14:30"
  static String time(DateTime? date) => format(date, 'HH:mm');

  /// EEEE, dd MMMM yyyy — "martes, 25 marzo 2026"
  static String dateFull(DateTime? date) => format(date, 'EEEE, dd MMMM yyyy');

  /// Long localized date — es: "25 de marzo de 2026", en: "March 25, 2026".
  static String dateFormal(DateTime? date) {
    if (date == null) return '';
    return DateFormat.yMMMMd().format(date.toLocal());
  }

  /// MMMM yyyy — "marzo 2026"
  static String monthYear(DateTime? date) => format(date, 'MMMM yyyy');

  /// EEEE, d MMM — "martes, 25 mar"
  static String dayNameShort(DateTime? date) => format(date, 'EEEE, d MMM');

  /// yyyy-MM-dd — "2026-03-25" (for form values, no locale needed)
  static String iso(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date.toLocal());
  }
}
