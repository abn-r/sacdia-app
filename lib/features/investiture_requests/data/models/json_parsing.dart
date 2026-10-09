/// Helpers de parseo compartidos por los modelos de solicitudes de investidura.
library;

/// Parsea una fecha civil `YYYY-MM-DD` (o un ISO con hora, tomando solo la
/// parte de fecha) sin aplicar zona horaria. Devuelve `null` si no es válida.
DateTime? parseCivilDate(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString();
  if (text.length < 10) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Formatea una fecha civil como `YYYY-MM-DD` para el cuerpo de las peticiones.
String formatCivilDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

int asInt(Object? raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

int? asIntOrNull(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

num asNum(Object? raw, {num fallback = 0}) {
  if (raw is num) return raw;
  return num.tryParse(raw?.toString() ?? '') ?? fallback;
}

String? asStringOrNull(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString();
  return text.isEmpty ? null : text;
}

Map<String, dynamic> asJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

List<Map<String, dynamic>> asJsonMapList(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map(asJsonMap).toList(growable: false);
}

/// Extrae una lista de una respuesta que puede venir como lista, como
/// `{data: [...]}`, `{data: {<nestedKey>: [...]}}` o `{data: {items: [...]}}`.
List<dynamic> extractInvestitureListFromResponse(
  dynamic raw,
  String nestedKey,
) {
  if (raw is List) return raw;

  if (raw is Map) {
    final directNested = raw[nestedKey];
    if (directNested is List) return directNested;

    final data = raw['data'];
    if (data is List) return data;
    if (data is Map) {
      final nested = data[nestedKey];
      if (nested is List) return nested;
      final items = data['items'];
      if (items is List) return items;
    }
  }

  return const [];
}
