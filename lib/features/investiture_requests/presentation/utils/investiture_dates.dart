import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Fecha civil legible ("15 nov 2026") en el idioma activo.
String formatInvestitureDate(BuildContext context, DateTime date) =>
    DateFormat('d MMM yyyy', context.locale.toString()).format(date);

/// Fecha corta con día de la semana ("sáb 14 dic") en el idioma activo.
String formatInvestitureShortDay(BuildContext context, DateTime date) =>
    DateFormat('EEE d MMM', context.locale.toString()).format(date);

/// Día y mes ("14 dic") en el idioma activo.
String formatInvestitureDayMonth(BuildContext context, DateTime date) =>
    DateFormat('d MMM', context.locale.toString()).format(date);

/// Fecha larga con día de la semana ("sábado 14 de diciembre").
String formatInvestitureLongDay(BuildContext context, DateTime date) {
  final locale = context.locale.toString();
  return '${DateFormat.EEEE(locale).format(date)} '
      '${DateFormat.MMMMd(locale).format(date)}';
}

/// Quita la hora: el backend maneja fechas civiles, sin zona.
DateTime civilDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Lleva [value] al rango [first]..[last] (inclusivo).
DateTime clampCivilDay(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}
