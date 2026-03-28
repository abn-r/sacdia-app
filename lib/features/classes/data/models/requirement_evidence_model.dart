import 'package:sacdia_app/core/utils/app_logger.dart';
import '../../domain/entities/requirement_evidence.dart';

const String _tag = 'RequirementEvidenceModel';

/// Modelo de datos para [RequirementEvidence].
///
/// Mapea la respuesta JSON de la API al dominio y viceversa.
class RequirementEvidenceModel extends RequirementEvidence {
  const RequirementEvidenceModel({
    required super.id,
    required super.url,
    required super.fileName,
    required super.type,
    required super.uploadedByName,
    required super.uploadedAt,
  });

  factory RequirementEvidenceModel.fromJson(Map<String, dynamic> json) {
    return RequirementEvidenceModel(
      id: (json['id'] ?? json['file_id'] ?? '').toString(),
      url: (json['url'] ?? json['file_url'] ?? '').toString(),
      fileName: (json['file_name'] ?? json['fileName'] ?? '').toString(),
      type: evidenceFileTypeFromString(
        json['file_type'] ?? json['type'] ?? '',
      ),
      uploadedByName: (json['uploaded_by_name'] ??
              json['uploadedByName'] ??
              'Desconocido')
          .toString(),
      uploadedAt: () {
        final raw = json['uploaded_at'] ?? json['uploadedAt'];
        if (raw != null) {
          final parsed = DateTime.tryParse(raw.toString());
          if (parsed == null) {
            AppLogger.w('Failed to parse date: $raw, using DateTime.now()', tag: _tag);
          }
          return parsed ?? DateTime.now();
        }
        return DateTime.now();
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'file_name': fileName,
      'file_type': type == EvidenceFileType.pdf ? 'pdf' : 'image',
      'uploaded_by_name': uploadedByName,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }

  RequirementEvidence toEntity() => RequirementEvidence(
        id: id,
        url: url,
        fileName: fileName,
        type: type,
        uploadedByName: uploadedByName,
        uploadedAt: uploadedAt,
      );
}
