/// Reads `completion_status` from a certification enrollment payload.
///
/// The backend sends a boolean (`true` once the certification is completed);
/// older payloads sent a string. Casting it straight to `String` throws and
/// leaves every enrolled user looking unenrolled.
String completionStatusFromJson(Object? raw) {
  if (raw is String && raw.isNotEmpty) return raw;
  if (raw == true) return 'certified';
  return 'in_progress';
}
