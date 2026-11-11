import 'dart:typed_data';

import '../../domain/entities/finance_export.dart';

/// Respuesta binaria de `GET /clubs/:clubId/finances/export`.
class FinanceExportFileModel {
  final Uint8List bytes;
  final String fileName;

  const FinanceExportFileModel({required this.bytes, required this.fileName});

  FinanceExportFile toEntity() =>
      FinanceExportFile(bytes: bytes, fileName: fileName);

  /// Nombre del archivo a partir de `Content-Disposition`.
  ///
  /// Acepta `filename="x.pdf"`, `filename=x.pdf` y `filename*=UTF-8''x.pdf`.
  /// El nombre se compartirá desde un directorio temporal: se descartan rutas
  /// y se reemplaza todo lo que no sea `[A-Za-z0-9._-]`. Si el encabezado falta
  /// o no sirve (o la extensión no coincide con el formato pedido) se usa
  /// `finanzas-YYYY-MM.<ext>`.
  static String resolveFileName(
    String? contentDisposition, {
    required int year,
    required int month,
    required FinanceExportFormat format,
  }) {
    final fallback =
        'finanzas-$year-${month.toString().padLeft(2, '0')}.${format.apiValue}';
    final header = contentDisposition;
    if (header == null || header.trim().isEmpty) return fallback;

    final encoded =
        RegExp(r"filename\*\s*=\s*[^']*'[^']*'([^;]+)", caseSensitive: false)
            .firstMatch(header)
            ?.group(1);
    final quoted = RegExp(r'filename\s*=\s*"([^"]*)"', caseSensitive: false)
        .firstMatch(header)
        ?.group(1);
    final bare = RegExp(r'filename\s*=\s*([^";\s]+)', caseSensitive: false)
        .firstMatch(header)
        ?.group(1);

    var raw = encoded ?? quoted ?? bare;
    if (raw == null) return fallback;
    if (encoded != null) {
      try {
        raw = Uri.decodeComponent(raw);
      } catch (_) {
        return fallback;
      }
    }

    final base = raw.trim().split(RegExp(r'[\\/]')).last;
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty ||
        safe.startsWith('.') ||
        !safe.toLowerCase().endsWith('.${format.apiValue}')) {
      return fallback;
    }
    return safe;
  }
}
