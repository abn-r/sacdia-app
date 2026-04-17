import 'package:equatable/equatable.dart';

/// Modelo de medicamento del catálogo
class MedicineModel extends Equatable {
  final int id;
  final String name;
  final bool isSelected;

  const MedicineModel({
    required this.id,
    required this.name,
    this.isSelected = false,
  });

  /// Crea una instancia desde JSON
  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    // Tolerar diferentes nombres de campo para el ID
    final rawId = json['id'] ?? json['medicine_id'];
    return MedicineModel(
      id: rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 0),
      name: (json['name'] as String?) ?? '',
      isSelected: json['is_selected'] as bool? ?? false,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_selected': isSelected,
    };
  }

  /// Crea una copia con campos actualizados
  MedicineModel copyWith({
    int? id,
    String? name,
    bool? isSelected,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [id, name, isSelected];
}
