import 'package:equatable/equatable.dart';
import '../../domain/entities/honor_category.dart';

/// Modelo de categoría de especialidad para la capa de datos
class HonorCategoryModel extends Equatable {
  final int id;
  final String name;
  final String? description;

  const HonorCategoryModel({
    required this.id,
    required this.name,
    this.description,
  });

  /// Crea una instancia desde JSON
  factory HonorCategoryModel.fromJson(Map<String, dynamic> json) {
    return HonorCategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  /// Convierte el modelo a entidad de dominio
  HonorCategory toEntity() {
    return HonorCategory(
      id: id,
      name: name,
      description: description,
    );
  }

  /// Crea una copia con campos actualizados
  HonorCategoryModel copyWith({
    int? id,
    String? name,
    String? description,
  }) {
    return HonorCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [id, name, description];
}
