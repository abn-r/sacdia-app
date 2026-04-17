import 'package:intl/intl.dart';

/// Utilidad centralizada para formatear fechas UTC a zona horaria local.
///
/// Todas las fechas del backend llegan en UTC. Esta clase garantiza
/// la conversión a zona horaria local del dispositivo antes de formatear.
class SacDateFormatter {
  SacDateFormatter._();

  /// Formatea una fecha UTC a local con el patrón dado.
  /// Retorna cadena vacía si la fecha es null.
  static String format(DateTime? date, String pattern, {String locale = 'es'}) {
    if (date == null) return '';
    return DateFormat(pattern, locale).format(date.toLocal());
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
  static String dateTimeShort(DateTime? date) => format(date, 'd MMM yyyy, HH:mm');

  /// HH:mm — "14:30"
  static String time(DateTime? date) => format(date, 'HH:mm');

  /// EEEE, dd MMMM yyyy — "martes, 25 marzo 2026"
  static String dateFull(DateTime? date) => format(date, 'EEEE, dd MMMM yyyy');

  /// dd 'de' MMMM 'de' yyyy — "25 de marzo de 2026"
  static String dateFormal(DateTime? date) =>
      format(date, "dd 'de' MMMM 'de' yyyy");

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
