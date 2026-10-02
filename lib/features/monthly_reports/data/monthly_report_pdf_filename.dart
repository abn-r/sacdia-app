/// Nombre de archivo que el usuario ve al guardar o compartir el PDF.
/// Acepta el `Content-Disposition` del backend y descarta cualquier valor
/// que no sea un basename PDF seguro.
String monthlyReportPdfFileName(
  String? contentDisposition, {
  required String fallback,
}) {
  final parsed = _fileNameFromContentDisposition(contentDisposition);
  if (_isSafePdfFileName(parsed)) return parsed!;
  if (_isSafePdfFileName(fallback)) return fallback;
  return 'informe-mensual.pdf';
}

String? _fileNameFromContentDisposition(String? header) {
  if (header == null || header.trim().isEmpty) return null;

  final encoded = RegExp(
    r"""filename\*\s*=\s*(?:UTF-8''|"UTF-8''|utf-8'')([^";]+)""",
    caseSensitive: false,
  ).firstMatch(header);
  if (encoded != null) {
    final raw = encoded.group(1)?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        return Uri.decodeComponent(raw);
      } catch (_) {
        return raw;
      }
    }
  }

  final quoted = RegExp(
    r'filename\s*=\s*"([^"]+)"',
    caseSensitive: false,
  ).firstMatch(header);
  if (quoted != null) return quoted.group(1)?.trim();

  final plain = RegExp(
    r'filename\s*=\s*([^;]+)',
    caseSensitive: false,
  ).firstMatch(header);
  return plain?.group(1)?.trim().replaceAll('"', '');
}

bool _isSafePdfFileName(String? value) {
  if (value == null || value.length > 200) return false;
  return RegExp(r'^[A-Za-z0-9._-]+\.pdf$').hasMatch(value);
}
