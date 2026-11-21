import 'package:intl/intl.dart';

/// Short date for the grid card ("14 sep"); the year only when it is not the
/// current one. Follows the app language (`Intl.defaultLocale`).
String achievementShortDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final sameYear = local.year == (now ?? DateTime.now()).year;
  return (sameYear ? DateFormat.MMMd() : DateFormat.yMMMd()).format(local);
}

/// Long date for the detail sheet ("14 de septiembre"); the year only when
/// it is not the current one.
String achievementLongDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final sameYear = local.year == (now ?? DateTime.now()).year;
  return (sameYear ? DateFormat.MMMMd() : DateFormat.yMMMMd()).format(local);
}
