/// Safe JSON parsing helpers.
///
/// These helpers handle type mismatches that can occur when an API returns
/// an unexpected type (e.g. a String "123" where an int is expected, or null
/// where a non-nullable type is expected). All helpers accept [dynamic] and
/// fall back gracefully instead of throwing a [TypeError].
library;

/// Safe integer parsing from a JSON value (handles int, double, String, null).
int safeInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Safe nullable integer parsing.
int? safeIntOrNull(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Alias for [safeIntOrNull] — provided for consistency with the
/// private `_parseInt` helpers previously scattered across models.
///
/// Returns null when [value] is null or cannot be parsed.
int? parseInt(dynamic value, {int? defaultValue}) {
  final result = safeIntOrNull(value);
  return result ?? defaultValue;
}

/// Safe string parsing — returns [value].toString() for non-null non-String values.
String safeString(dynamic value, [String fallback = '']) {
  if (value is String) return value;
  if (value != null) return value.toString();
  return fallback;
}

/// Safe nullable string — returns [value].toString() for non-null non-String values.
String? safeStringOrNull(dynamic value) {
  if (value is String) return value;
  if (value != null) return value.toString();
  return null;
}

/// Safe double parsing (handles double, int, String, null).
double safeDouble(dynamic value, [double fallback = 0.0]) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Safe bool parsing (handles bool, int 0/1, String "true"/"false", null).
bool safeBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}
