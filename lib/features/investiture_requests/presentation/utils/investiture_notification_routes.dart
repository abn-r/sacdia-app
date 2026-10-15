import '../../../../core/config/route_names.dart';

/// ¿La notificación de la bandeja es un resultado de investidura?
///
/// El backend usa `investiture:invested` e `investiture:rejected` como
/// `source` de ambas audiencias (persona y directiva).
bool isInvestitureResultSource(String? source) {
  final normalized = source?.trim().toLowerCase();
  if (normalized == null) return false;
  return normalized == 'investiture:invested' ||
      normalized == 'investiture:rejected';
}

/// Destino al abrir un resultado desde la bandeja: la directiva ve la pantalla
/// de la sección; el resto, su propia lista de investiduras.
String investitureInboxRoute({required bool isBoard}) =>
    isBoard ? RouteNames.sectionInvestiture : RouteNames.ownInvestiture;

/// Destino de un push `investiture_result`.
///
/// - `audience: board` → pantalla de la directiva.
/// - `audience: person` con `classId` válido → detalle de esa clase.
/// - `audience: person` sin `classId` (filas viejas) o cualquier otro caso →
///   lista propia de investiduras, que no depende de la clase.
String investitureResultPushRoute(Map<String, dynamic> data) {
  final audience = data['audience']?.toString().trim().toLowerCase();
  if (audience == 'board') return RouteNames.sectionInvestiture;
  if (audience == 'person') {
    final raw = data['classId'];
    final classId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (classId != null && classId > 0) {
      return RouteNames.classDetailPath(classId.toString());
    }
  }
  return RouteNames.ownInvestiture;
}
