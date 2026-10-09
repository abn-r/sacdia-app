import 'package:easy_localization/easy_localization.dart';

/// Códigos de error del backend (`ErrorCode`) de la investidura por
/// autorización, mapeados a su clave de traducción.
///
/// Mismo mapa para los errores de las acciones y para los motivos de bloqueo
/// (`blocked_code`) de los candidatos.
const Map<String, String> _errorKeysByCode = {
  'INVESTITURE_REQUEST_FORBIDDEN': 'investiture_requests.errors.forbidden',
  'INVESTITURE_REQUEST_STALE': 'investiture_requests.errors.stale',
  'INVESTITURE_REQUEST_ACTIVE_EXISTS':
      'investiture_requests.errors.active_exists',
  'INVESTITURE_REQUEST_ALREADY_INVESTED':
      'investiture_requests.errors.already_invested',
  'INVESTITURE_REQUEST_LEGACY_PIPELINE_ACTIVE':
      'investiture_requests.errors.legacy_pipeline_active',
  'INVESTITURE_REQUEST_CLASS_NOT_ELIGIBLE':
      'investiture_requests.errors.class_not_eligible',
  'INVESTITURE_REQUEST_NOT_ELIGIBLE':
      'investiture_requests.errors.not_eligible',
  'INVESTITURE_REQUEST_OUTSIDE_SECTION':
      'investiture_requests.errors.outside_section',
  'INVESTITURE_REQUEST_WINDOW_CLOSED':
      'investiture_requests.errors.window_closed',
  'INVESTITURE_REQUEST_YEAR_CLOSED': 'investiture_requests.errors.year_closed',
  'INVESTITURE_REQUEST_DATE_OUTSIDE_WINDOW':
      'investiture_requests.errors.date_outside_window',
  'INVESTITURE_REQUEST_DATE_OUTSIDE_YEAR':
      'investiture_requests.errors.date_outside_year',
  'INVESTITURE_REQUEST_DATE_INVALID':
      'investiture_requests.errors.date_invalid',
  'INVESTITURE_REQUEST_PROGRESS_LOCKED':
      'investiture_requests.errors.progress_locked',
  'INVESTITURE_REQUEST_TIME_ZONE_INVALID':
      'investiture_requests.errors.time_zone_invalid',
  'INVESTITURE_REQUEST_NOT_OPERATIONAL':
      'investiture_requests.errors.not_operational',
  'INVESTITURE_REQUEST_NOT_PENDING': 'investiture_requests.errors.not_pending',
  'INVESTITURE_REQUEST_NOT_FOUND': 'investiture_requests.errors.not_found',
  'INVESTITURE_REQUEST_SECTION_NOT_FOUND':
      'investiture_requests.errors.section_not_found',
  'INVESTITURE_REQUEST_EMPTY': 'investiture_requests.errors.empty',
  'INVESTITURE_REQUEST_ALREADY_RESOLVED':
      'investiture_requests.errors.already_resolved',
  'INVESTITURE_REQUEST_REASON_REQUIRED':
      'investiture_requests.errors.reason_required',
  'INVESTITURE_REQUEST_CONFLICTING_DECISION':
      'investiture_requests.errors.conflicting_decision',
  'INVESTITURE_REQUEST_TEXT_TOO_LONG':
      'investiture_requests.errors.text_too_long',
  'INVESTITURE_DURATION_MIN_NOT_MET':
      'investiture_requests.errors.duration_min_not_met',
  'INVESTITURE_DURATION_EXPIRED':
      'investiture_requests.errors.duration_expired',
};

/// Clave de traducción de un código de error de investidura, o `null` si el
/// código no es conocido.
String? investitureRequestErrorKey(String? code) =>
    code == null ? null : _errorKeysByCode[code];

/// Mensaje traducido para [code]; `null` si el código no es conocido.
String? investitureRequestErrorMessage(String? code) {
  final key = investitureRequestErrorKey(code);
  return key == null ? null : tr(key);
}
