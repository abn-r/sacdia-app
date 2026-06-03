/// Helpers de cumpleaños sin dependencia de Flutter.
///
/// SACDIA recibe `birthday` como fecha de calendario, no como instante real.
/// Por eso comparamos solo mes/día y evitamos cálculos de edad o zona horaria.
class BirthdayParts {
  final int month;
  final int day;

  const BirthdayParts({required this.month, required this.day});
}

BirthdayParts? birthdayPartsFromDate(DateTime? birthday) {
  if (birthday == null) return null;
  return _isValidMonthDay(birthday.month, birthday.day)
      ? BirthdayParts(month: birthday.month, day: birthday.day)
      : null;
}

bool isBirthdayToday(DateTime? birthday, {DateTime? today}) {
  final parts = birthdayPartsFromDate(birthday);
  if (parts == null) return false;

  final current = today ?? DateTime.now();
  return parts.month == current.month && parts.day == current.day;
}

String? birthdayDismissalKey({
  required String? userId,
  required DateTime? birthday,
  DateTime? today,
}) {
  final normalizedUserId = userId?.trim();
  final parts = birthdayPartsFromDate(birthday);
  final current = today ?? DateTime.now();

  if (normalizedUserId == null || normalizedUserId.isEmpty || parts == null) {
    return null;
  }

  final month = parts.month.toString().padLeft(2, '0');
  final day = parts.day.toString().padLeft(2, '0');

  return 'sacdia:birthday:$normalizedUserId:${current.year}:$month-$day';
}

Duration durationUntilNextLocalDay(DateTime now) {
  final nextDay = DateTime(now.year, now.month, now.day + 1);
  return nextDay.difference(now);
}

bool _isValidMonthDay(int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  final normalized = DateTime.utc(2000, month, day);
  return normalized.month == month && normalized.day == day;
}
