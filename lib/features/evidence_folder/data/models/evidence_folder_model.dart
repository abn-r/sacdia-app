import '../../domain/entities/evidence_folder.dart';
import 'evidence_section_model.dart';

/// Modelo de datos para [EvidenceFolder].
///
/// Mapea la respuesta JSON del módulo AnnualFolders al dominio.
/// Campos clave:
///   annual_folder_id, status, total_earned_points, total_max_points,
///   progress_percentage, template.name, sections (array).
class EvidenceFolderModel extends EvidenceFolder {
  const EvidenceFolderModel({
    required super.folderId,
    required super.id,
    required super.name,
    super.description,
    required super.isOpen,
    required super.totalPoints,
    required super.totalPercentage,
    required super.sections,
    super.totalEarnedPoints,
    super.totalMaxPoints,
    super.progressPercentage,
    super.evaluatedAt,
    super.status,
  });

  factory EvidenceFolderModel.fromJson(Map<String, dynamic> json) {
    // ── annual_folder_id (UUID necesario para operaciones mutantes) ──────────
    final folderId =
        (json['annual_folder_id'] ?? json['folder_id'] ?? json['id'] ?? '')
            .toString();

    // ── Nombre: AnnualFolders lo trae dentro de template.name ────────────────
    final template = json['template'] as Map<String, dynamic>?;
    final name = (template?['name'] ??
            json['name'] ??
            json['folder_name'] ??
            'Carpeta de Evidencias')
        .toString();

    // ── Status ────────────────────────────────────────────────────────────────
    final status = json['status']?.toString();

    // isOpen: la carpeta está abierta cuando status == 'open'
    // Fallback al campo booleano legacy si existe
    final isOpen = status != null
        ? status == 'open'
        : (json['is_open'] as bool? ?? json['isOpen'] as bool? ?? true);

    // ── Secciones (pasar folderStatus para derivar status por sección) ────────
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    final sections = rawSections
        .map((s) => EvidenceSectionModel.fromJson(
              s as Map<String, dynamic>,
              folderStatus: status,
            ).toEntity())
        .toList();

    return EvidenceFolderModel(
      folderId: folderId,
      // id es igual a folderId — mantenemos el campo heredado para compat.
      id: folderId,
      name: name,
      description: json['description']?.toString(),
      isOpen: isOpen,
      // totalPoints: AnnualFolders usa total_max_points como referencia
      totalPoints: _parseInt(
          json['total_max_points'] ?? json['totalMaxPoints'] ??
              json['total_points'] ?? json['totalPoints'] ?? 0),
      // totalPercentage: se mapea desde progress_percentage (0–100 → ratio 0–1)
      totalPercentage: _parseDouble(
              json['progress_percentage'] ?? json['progressPercentage'] ??
                  json['total_percentage'] ?? json['totalPercentage'] ?? 0) /
          100.0,
      sections: sections,
      totalEarnedPoints: _parseIntNullable(
          json['total_earned_points'] ?? json['totalEarnedPoints']),
      totalMaxPoints:
          _parseIntNullable(json['total_max_points'] ?? json['totalMaxPoints']),
      progressPercentage: _parseDoubleNullable(
          json['progress_percentage'] ?? json['progressPercentage']),
      evaluatedAt: _parseDate(
          json['evaluated_at']?.toString() ?? json['evaluatedAt']?.toString()),
      status: status,
    );
  }

  // ── Parse helpers ─────────────────────────────────────────────────────────────

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  EvidenceFolder toEntity() => EvidenceFolder(
        folderId: folderId,
        id: id,
        name: name,
        description: description,
        isOpen: isOpen,
        totalPoints: totalPoints,
        totalPercentage: totalPercentage,
        sections: sections,
        totalEarnedPoints: totalEarnedPoints,
        totalMaxPoints: totalMaxPoints,
        progressPercentage: progressPercentage,
        evaluatedAt: evaluatedAt,
        status: status,
      );
}
