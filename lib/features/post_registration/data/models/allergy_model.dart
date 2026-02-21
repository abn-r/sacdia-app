import 'package:equatable/equatable.dart';

/// Modelo de alergia del catálogo
class AllergyModel extends Equatable {
  final int id;
  final String name;
  final bool isSelected;

  AllergyModel({
    required this.id,
    required this.name,
    this.isSelected = false,
  });

  /// Crea una instancia desde JSON
  factory AllergyModel.fromJson(Map<String, dynamic> json) {
    // Tolerar diferentes nombres de campo para el ID
    final rawId = json['id'] ?? json['allergy_id'];
    return AllergyModel(
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
  AllergyModel copyWith({
    int? id,
    String? name,
    bool? isSelected,
  }) {
    return AllergyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [id, name, isSelected];
}
