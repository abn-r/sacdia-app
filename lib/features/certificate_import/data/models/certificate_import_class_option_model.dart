import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/certificate_import_class_option.dart';

/// `{class_id, name, asset_code, club_type_id, institutional}` from
/// `GET /certificate-bulk-imports/catalog/classes`.
abstract final class CertificateImportClassOptionModel {
  /// Skips entries without id or name instead of failing the whole list.
  static CertificateImportClassOption? fromJson(Map<String, dynamic> json) {
    final id = safeIntOrNull(json['class_id']);
    final name = safeStringOrNull(json['name']);
    if (id == null || name == null) return null;
    return CertificateImportClassOption(
      id: id,
      name: name,
      assetCode: safeStringOrNull(json['asset_code']),
      clubTypeId: safeIntOrNull(json['club_type_id']),
      institutional: json['institutional'] == true,
    );
  }
}
