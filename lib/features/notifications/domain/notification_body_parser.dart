/// Parsed in-app layout for a notification [body].
///
/// Director "member of the month" messages used to dump every winner into one
/// comma-separated sentence. The sheet reads better as a summary + name list.
class ParsedNotificationBody {
  const ParsedNotificationBody.plain(this.raw)
      : names = const [],
        section = null,
        points = null;

  const ParsedNotificationBody.namedList({
    required this.raw,
    required this.names,
    this.section,
    this.points,
  });

  final String raw;
  final List<String> names;
  final String? section;
  final int? points;

  bool get hasNameList => names.length >= 2;
}

final _directorLine = RegExp(
  r'destac(?:ó|aron)\s+en\s+(?<section>.+?)(?:\s+con\s+(?<points>\d+)\s+puntos)?\.?\s*$',
  caseSensitive: false,
  unicode: true,
);

final _commaDirector = RegExp(
  r'^(?<names>.+?)\s+destac(?:ó|aron)\s+en\s+(?<section>.+?)(?:\s+con\s+(?<points>\d+)\s+puntos)?\.?\s*$',
  caseSensitive: false,
  unicode: true,
);

/// Splits member-of-month director copy into a summary and a name list.
ParsedNotificationBody parseNotificationBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return ParsedNotificationBody.plain(body);

  final blocks = trimmed.split(RegExp(r'\n\s*\n'));
  if (blocks.length >= 2) {
    final names = blocks
        .skip(1)
        .expand((block) => block.split('\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (_isNameList(names)) {
      final meta = _directorLine.firstMatch(blocks.first.trim());
      return ParsedNotificationBody.namedList(
        raw: body,
        names: names,
        section: meta?.namedGroup('section')?.trim(),
        points: int.tryParse(meta?.namedGroup('points') ?? ''),
      );
    }
  }

  final match = _commaDirector.firstMatch(trimmed);
  if (match != null) {
    final names = match
        .namedGroup('names')!
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (_isNameList(names)) {
      return ParsedNotificationBody.namedList(
        raw: body,
        names: names,
        section: match.namedGroup('section')?.trim(),
        points: int.tryParse(match.namedGroup('points') ?? ''),
      );
    }
  }

  return ParsedNotificationBody.plain(body);
}

bool _isNameList(List<String> names) {
  return names.length >= 2 && names.every(_looksLikePersonName);
}

bool _looksLikePersonName(String value) {
  if (value.length > 80) return false;
  if (RegExp(r'[.!?:]').hasMatch(value)) return false;
  final words = value.split(RegExp(r'\s+'));
  return words.isNotEmpty && words.length <= 6;
}
