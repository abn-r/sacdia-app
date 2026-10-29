final _generatedName = RegExp(
  r'^(scaled_)?(image_picker_|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-)',
  caseSensitive: false,
);

/// The file name worth showing to a person, or null when the phone made it up
/// (`image_picker_<uuid>.jpg`, `scaled_image_picker_...`, a bare UUID): it
/// means nothing to the user. Callers show their own label in that case.
String? meaningfulFileName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || _generatedName.hasMatch(trimmed)) return null;
  return trimmed;
}
