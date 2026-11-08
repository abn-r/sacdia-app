import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';

/// Día calendario del valor, sin hora.
DateTime camporeeCalendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Sigue abierto si el día de cierre es hoy o posterior.
///
/// Un camporee que termina hoy se queda en la lista principal.
/// Desde el día siguiente pasa al histórico.
bool camporeeIsOpen(Camporee camporee, DateTime now) {
  final end = camporeeCalendarDay(camporee.endDate);
  return !end.isBefore(camporeeCalendarDay(now));
}

/// Conserva el orden de entrada (el API ya viene por creación).
List<Camporee> currentCamporees(List<Camporee> camporees, DateTime now) {
  return [
    for (final camporee in camporees)
      if (camporeeIsOpen(camporee, now)) camporee,
  ];
}

/// Más reciente primero. Empate por id descendente.
List<Camporee> historicalCamporees(List<Camporee> camporees, DateTime now) {
  final past = [
    for (final camporee in camporees)
      if (!camporeeIsOpen(camporee, now)) camporee,
  ];
  past.sort((a, b) {
    final byEnd = b.endDate.compareTo(a.endDate);
    if (byEnd != 0) return byEnd;
    return b.camporeeId.compareTo(a.camporeeId);
  });
  return past;
}

/// Where a camporee stands on a given day, for the list's status chip.
enum CamporeeTimingKind {
  /// Starts in [CamporeeTiming.days] days (1 = tomorrow).
  upcoming,

  /// Running: today is day [CamporeeTiming.day] of [CamporeeTiming.totalDays].
  ongoing,

  /// Ended [CamporeeTiming.days] days ago (1 = yesterday).
  ended,
}

class CamporeeTiming {
  const CamporeeTiming._(
    this.kind, {
    this.days = 0,
    this.day = 0,
    this.totalDays = 0,
  });

  final CamporeeTimingKind kind;
  final int days;
  final int day;
  final int totalDays;

  /// Running and today is its last day.
  bool get endsToday => kind == CamporeeTimingKind.ongoing && day == totalDays;

  /// Calendar days only, so the time of day and DST never shift the count.
  factory CamporeeTiming.of(Camporee camporee, DateTime now) {
    int dayNumber(DateTime d) =>
        DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final today = dayNumber(now);
    final start = dayNumber(camporee.startDate);
    final end = dayNumber(camporee.endDate);
    // A bad range (end before start) still reads as one day.
    final last = end < start ? start : end;

    if (today < start) {
      return CamporeeTiming._(CamporeeTimingKind.upcoming, days: start - today);
    }
    if (today > last) {
      return CamporeeTiming._(CamporeeTimingKind.ended, days: today - last);
    }
    return CamporeeTiming._(
      CamporeeTimingKind.ongoing,
      day: today - start + 1,
      totalDays: last - start + 1,
    );
  }
}
