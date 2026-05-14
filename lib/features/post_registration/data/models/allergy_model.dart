import 'package:equatable/equatable.dart';

/// Nivel de severidad de una alergia
enum AllergySeverity { leve, media, alta }

/// Extension para parseo y display de [AllergySeverity]
extension AllergySeverityX on AllergySeverity {
  /// Parsea un String desde la API; desconocido/null → [AllergySeverity.leve]
  static AllergySeverity parse(String? value) {
    switch (value) {
      case 'media':
        return AllergySeverity.media;
      case 'alta':
        return AllergySeverity.alta;
      default:
        return AllergySeverity.leve;
    }
  }

  /// Valor de visualización para la UI (coincide con el nombre del enum)
  String get display => name;

  /// i18n key bajo `profile.medical_info.severity.*`
  String get i18nKey => 'profile.medical_info.severity.$name';
}

/// Modelo de alergia del catálogo
class AllergyModel extends Equatable {
  final int id;
  final String name;
  final bool isSelected;

  /// Severidad de la alergia para el usuario. Default: [AllergySeverity.leve].
  final AllergySeverity severity;

  const AllergyModel({
    required this.id,
    required this.name,
    this.isSelected = false,
    this.severity = AllergySeverity.leve,
  });

  /// Crea una instancia desde JSON.
  ///
  /// Tolera campos faltantes para compatibilidad con el catálogo
  /// (que no incluye `severity`) y con respuestas antiguas del GET usuario.
  factory AllergyModel.fromJson(Map<String, dynamic> json) {
    // Tolerar diferentes nombres de campo para el ID
    final rawId = json['id'] ?? json['allergy_id'];
    return AllergyModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      isSelected: json['is_selected'] as bool? ?? false,
      severity: AllergySeverityX.parse(json['severity'] as String?),
    );
  }

  /// Convierte la instancia a JSON (para serialización local)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_selected': isSelected,
      'severity': severity.name,
    };
  }

  /// Crea una copia con campos actualizados
  AllergyModel copyWith({
    int? id,
    String? name,
    bool? isSelected,
    AllergySeverity? severity,
  }) {
    return AllergyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
      severity: severity ?? this.severity,
    );
  }

  @override
  List<Object?> get props => [id, name, isSelected, severity];
}
