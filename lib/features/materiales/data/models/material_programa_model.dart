import '../../domain/entities/material_programa.dart';

/// Modelo de datos para [MaterialPrograma].
///
/// Mapea la respuesta JSON del endpoint GET /materiales/catalogo/programas.
/// Los datos provienen de la tabla `club_types` del backend.
class MaterialProgramaModel extends MaterialPrograma {
  const MaterialProgramaModel({
    required super.id,
    required super.label,
  });

  factory MaterialProgramaModel.fromJson(Map<String, dynamic> json) {
    return MaterialProgramaModel(
      id: (json['id'] as num).toInt(),
      label: (json['label'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
    };
  }

  MaterialPrograma toEntity() => MaterialPrograma(id: id, label: label);
}
