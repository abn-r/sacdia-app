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
