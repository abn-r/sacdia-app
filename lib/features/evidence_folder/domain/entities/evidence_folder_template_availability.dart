/// Indica si la Carpeta Anual de Evidencias puede crearse para una sección:
/// existe una plantilla publicada para su tipo de club y año eclesiástico.
class EvidenceFolderTemplateAvailability {
  final bool isAvailable;

  /// Nombre legible del tipo de club (p. ej. "Guías Mayores").
  final String? clubTypeName;

  /// Etiqueta del año eclesiástico (p. ej. "2025-2026").
  final String? yearLabel;

  const EvidenceFolderTemplateAvailability({
    required this.isAvailable,
    this.clubTypeName,
    this.yearLabel,
  });

  factory EvidenceFolderTemplateAvailability.fromJson(
      Map<String, dynamic> json) {
    return EvidenceFolderTemplateAvailability(
      isAvailable: json['template_available'] == true,
      clubTypeName: json['club_type_name'] as String?,
      yearLabel: json['year_label'] as String?,
    );
  }
}
