import '../../domain/entities/certification_status.dart';

/// Lee el `summary` de una inscripción o de su progreso. Nulo si el backend
/// no lo envía (servidor anterior al rediseño).
CertificationSummary? certificationSummaryFromJson(Object? raw) {
  if (raw is! Map) return null;
  int read(String key) => (raw[key] as num?)?.toInt() ?? 0;
  return CertificationSummary(
    total: read('total'),
    approved: read('approved'),
    submitted: read('submitted'),
    changesRequested: read('changes_requested'),
    notStartedOrDraft: read('not_started_or_draft'),
  );
}

/// Lee un `DateTime` ISO 8601 o nulo.
DateTime? certificationDateFromJson(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;

/// Estado de la inscripción: `status` si llega; si no, lo deduce del
/// `completion_status` legado (booleano o texto).
CertificationEnrollmentStatus certificationEnrollmentStatusFromJson(
  Map<String, dynamic> json,
) {
  final raw = json['status'];
  if (raw is String && raw.isNotEmpty) {
    return certificationEnrollmentStatusFromWire(raw);
  }
  final completion = json['completion_status'];
  final done = completion == true ||
      (completion is String &&
          {'certified', 'completed'}.contains(completion.toLowerCase()));
  return done
      ? CertificationEnrollmentStatus.certified
      : CertificationEnrollmentStatus.inProgress;
}
