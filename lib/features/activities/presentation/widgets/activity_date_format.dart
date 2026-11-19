import 'package:intl/intl.dart';

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// "Sábado 21 de noviembre", in [locale].
String activityFullDate(DateTime date, String locale) {
  final local = date.toLocal();
  final weekday = DateFormat.EEEE(locale).format(local);
  final day = DateFormat.MMMMd(locale).format(local);
  return _capitalize('$weekday $day');
}

/// "Sábado", in [locale].
String activityWeekday(DateTime date, String locale) =>
    _capitalize(DateFormat.EEEE(locale).format(date.toLocal()));

/// Short month for the date tile ("nov"), without a trailing period.
String activityShortMonth(DateTime date, String locale) =>
    DateFormat.MMM(locale).format(date.toLocal()).replaceAll('.', '');

/// "d MMM" for ranges ("23 nov"), in [locale].
String activityDayMonth(DateTime date, String locale) =>
    DateFormat.MMMd(locale).format(date.toLocal());

/// "08:00" -> "8:00". Null when there is no usable time.
String? activityTimeLabel(String? time) {
  final value = time?.trim() ?? '';
  if (!value.contains(':')) return null;
  final parts = value.split(':');
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return '$hour:${minute.toString().padLeft(2, '0')}';
}
