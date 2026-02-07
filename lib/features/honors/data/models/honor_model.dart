import 'package:equatable/equatable.dart';
import '../../domain/entities/honor.dart';

/// Modelo de especialidad para la capa de datos
class HonorModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String? imageUrl;
  final int? skillLevel;

  const HonorModel({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.imageUrl,
    this.skillLevel,
  });

  /// Crea una instancia desde JSON
  factory HonorModel.fromJson(Map<String, dynamic> json) {
    return HonorModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as int,
      imageUrl: json['image_url'] as String?,
      skillLevel: json['skill_level'] as int?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'image_url': imageUrl,
      'skill_level': skillLevel,
    };
  }

  /// Convierte el modelo a entidad de dominio
  Honor toEntity() {
    return Honor(
      id: id,
      name: name,
      description: description,
      categoryId: categoryId,
      imageUrl: imageUrl,
      skillLevel: skillLevel,
    );
  }

  /// Crea una copia con campos actualizados
  HonorModel copyWith({
    int? id,
    String? name,
    String? description,
    int? categoryId,
    String? imageUrl,
    int? skillLevel,
  }) {
    return HonorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      skillLevel: skillLevel ?? this.skillLevel,
    );
  }

  @override
  List<Object?> get props => [id, name, description, categoryId, imageUrl, skillLevel];
}
