import '../../domain/entities/material_program.dart';

/// Modelo de datos para [MaterialProgram].
///
/// Mapea la respuesta JSON del endpoint GET /materials/catalog/programs.
/// Los datos provienen de la tabla `club_types` del backend.
class MaterialProgramModel extends MaterialProgram {
  const MaterialProgramModel({
    required super.id,
    required super.label,
  });

  factory MaterialProgramModel.fromJson(Map<String, dynamic> json) {
    return MaterialProgramModel(
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

  MaterialProgram toEntity() => MaterialProgram(id: id, label: label);
}
