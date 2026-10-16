import 'package:equatable/equatable.dart';

/// Estado posible de una exportación de datos.
enum DataExportStatus { pending, processing, ready, failed, expired }

/// Representa una solicitud de exportación de datos personales del usuario.
///
/// Refleja exactamente la respuesta de GET /users/me/data-exports.
class DataExport extends Equatable {
  final String exportId;
  final DataExportStatus status;
  final String format;
  final int? fileSizeBytes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final String? failureReason;

  const DataExport({
    required this.exportId,
    required this.status,
    required this.format,
    this.fileSizeBytes,
    required this.createdAt,
    this.completedAt,
    this.expiresAt,
    this.failureReason,
  });

  /// Verdadero si la exportación está en progreso (no se puede solicitar otra).
  bool get isInProgress =>
      status == DataExportStatus.pending ||
      status == DataExportStatus.processing;

  /// Verdadero si la exportación está disponible para descargar.
  bool get isReady => status == DataExportStatus.ready;

  /// Verdadero si terminó (éxito, falla o expiración).
  bool get isTerminal =>
      status == DataExportStatus.ready ||
      status == DataExportStatus.failed ||
      status == DataExportStatus.expired;

  /// Etiqueta localizada del estado.
  String get statusLabel {
    switch (status) {
      case DataExportStatus.pending:
        return 'Pendiente';
      case DataExportStatus.processing:
        return 'Generando...';
      case DataExportStatus.ready:
        return 'Listo para descargar';
      case DataExportStatus.failed:
        return 'Falló';
      case DataExportStatus.expired:
        return 'Expirada';
    }
  }

  /// Tamaño del archivo formateado como KB o MB.
  String? get formattedSize {
    if (fileSizeBytes == null) return null;
    final bytes = fileSizeBytes!;
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  List<Object?> get props => [
        exportId,
        status,
        format,
        fileSizeBytes,
        createdAt,
        completedAt,
        expiresAt,
        failureReason,
      ];
}

/// Cooldown the backend enforces between completed exports.
const dataExportCooldown = Duration(hours: 24);

/// When the user may request another export, or null if they can now.
///
/// Mirrors the backend rule: only a ready export created inside the
/// cooldown blocks a new request; failed and expired ones do not.
DateTime? nextDataExportAvailableAt(
  List<DataExport> exports, {
  required DateTime now,
}) {
  DateTime? latest;
  for (final export in exports) {
    if (export.status != DataExportStatus.ready) continue;
    if (latest == null || export.createdAt.isAfter(latest)) {
      latest = export.createdAt;
    }
  }
  if (latest == null) return null;
  final next = latest.add(dataExportCooldown);
  return next.isAfter(now) ? next : null;
}

/// Short wait label: whole hours rounded up, or minutes under an hour.
String formatDataExportWait(Duration wait) {
  if (wait.inMinutes >= 60) {
    return '${(wait.inMinutes / 60).ceil()} h';
  }
  final minutes = (wait.inSeconds / 60).ceil();
  return '${minutes < 1 ? 1 : minutes} min';
}

/// File name for a shared export, dated by when it was generated.
String dataExportFileName(DateTime createdAt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'sacdia-mis-datos-'
      '${createdAt.year}-${two(createdAt.month)}-${two(createdAt.day)}.json';
}
