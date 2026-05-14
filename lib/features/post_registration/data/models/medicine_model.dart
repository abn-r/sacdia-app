import 'package:equatable/equatable.dart';

/// Modelo de medicamento del catálogo
class MedicineModel extends Equatable {
  final int id;
  final String name;
  final bool isSelected;

  /// Dosis del medicamento (ej. "500mg cada 8 hs"). Nullable — sin default.
  final String? dose;

  const MedicineModel({
    required this.id,
    required this.name,
    this.isSelected = false,
    this.dose,
  });

  /// Crea una instancia desde JSON.
  ///
  /// Tolera `dose` ausente (catálogo y respuestas antiguas).
  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    // Tolerar diferentes nombres de campo para el ID
    final rawId = json['id'] ?? json['medicine_id'];
    return MedicineModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      isSelected: json['is_selected'] as bool? ?? false,
      dose: json['dose'] as String?,
    );
  }

  /// Convierte la instancia a JSON (para serialización local)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_selected': isSelected,
      if (dose != null) 'dose': dose,
    };
  }

  /// Crea una copia con campos actualizados
  MedicineModel copyWith({
    int? id,
    String? name,
    bool? isSelected,
    String? dose,
    bool clearDose = false,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
      dose: clearDose ? null : (dose ?? this.dose),
    );
  }

  @override
  List<Object?> get props => [id, name, isSelected, dose];
}
