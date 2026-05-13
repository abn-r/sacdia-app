import 'package:equatable/equatable.dart';

/// Modelo de enfermedad del catálogo
class DiseaseModel extends Equatable {
  final int id;
  final String name;
  final bool isSelected;

  /// Año desde el cual el usuario padece la enfermedad. Nullable — sin default.
  final int? sinceYear;

  const DiseaseModel({
    required this.id,
    required this.name,
    this.isSelected = false,
    this.sinceYear,
  });

  /// Crea una instancia desde JSON.
  ///
  /// Tolera `since_year` ausente (catálogo y respuestas antiguas).
  factory DiseaseModel.fromJson(Map<String, dynamic> json) {
    // Tolerar diferentes nombres de campo para el ID
    final rawId = json['id'] ?? json['disease_id'];
    return DiseaseModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      isSelected: json['is_selected'] as bool? ?? false,
      sinceYear: (json['since_year'] as num?)?.toInt(),
    );
  }

  /// Convierte la instancia a JSON (para serialización local)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_selected': isSelected,
      if (sinceYear != null) 'since_year': sinceYear,
    };
  }

  /// Crea una copia con campos actualizados
  DiseaseModel copyWith({
    int? id,
    String? name,
    bool? isSelected,
    int? sinceYear,
    bool clearSinceYear = false,
  }) {
    return DiseaseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
      sinceYear: clearSinceYear ? null : (sinceYear ?? this.sinceYear),
    );
  }

  @override
  List<Object?> get props => [id, name, isSelected, sinceYear];
}
