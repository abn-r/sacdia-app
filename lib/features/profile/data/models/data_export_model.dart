import '../../domain/entities/data_export.dart';

/// Modelo de datos que mapea la respuesta JSON de
/// GET /users/me/data-exports y POST /users/me/data-export.
class DataExportModel extends DataExport {
  const DataExportModel({
    required super.exportId,
    required super.status,
    required super.format,
    super.fileSizeBytes,
    required super.createdAt,
    super.completedAt,
    super.expiresAt,
    super.failureReason,
  });

  factory DataExportModel.fromJson(Map<String, dynamic> json) {
    return DataExportModel(
      exportId: json['export_id'] as String,
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      format: json['format'] as String? ?? 'json',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      failureReason: json['failure_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'export_id': exportId,
        'status': _statusToString(status),
        'format': format,
        'file_size_bytes': fileSizeBytes,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'failure_reason': failureReason,
      };

  static DataExportStatus _parseStatus(String raw) {
    switch (raw) {
      case 'pending':
        return DataExportStatus.pending;
      case 'processing':
        return DataExportStatus.processing;
      case 'ready':
        return DataExportStatus.ready;
      case 'failed':
        return DataExportStatus.failed;
      case 'expired':
        return DataExportStatus.expired;
      default:
        return DataExportStatus.pending;
    }
  }

  static String _statusToString(DataExportStatus status) {
    switch (status) {
      case DataExportStatus.pending:
        return 'pending';
      case DataExportStatus.processing:
        return 'processing';
      case DataExportStatus.ready:
        return 'ready';
      case DataExportStatus.failed:
        return 'failed';
      case DataExportStatus.expired:
        return 'expired';
    }
  }
}
