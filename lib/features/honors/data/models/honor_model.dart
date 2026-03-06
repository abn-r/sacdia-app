import 'package:equatable/equatable.dart';
import '../../domain/entities/honor.dart';

const String _honorImagesBase =
    'https://sacdia-files.s3.us-east-1.amazonaws.com/Especialidades/';

String? _buildImageUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  return '$_honorImagesBase$raw';
}

/// Modelo de especialidad para la capa de datos
class HonorModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String? imageUrl;
  final int? skillLevel;
  final String? materialUrl;
  final int approval;
  final String? year;
  final int clubTypeId;
  final bool active;

  const HonorModel({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.imageUrl,
    this.skillLevel,
    this.materialUrl,
    this.approval = 1,
    this.year,
    this.clubTypeId = 1,
    this.active = true,
  });

  /// Crea una instancia desde JSON
  factory HonorModel.fromJson(Map<String, dynamic> json) {
    return HonorModel(
      // Backend PK is 'honor_id'; 'id' is fallback
      id: (json['honor_id'] ?? json['id']) as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      // Backend FK is 'honors_category_id'; 'category_id' is fallback
      categoryId: (json['honors_category_id'] ?? json['category_id']) as int,
      imageUrl: _buildImageUrl(
        json['honor_image'] as String? ?? json['image_url'] as String?,
      ),
      skillLevel: json['skill_level'] as int?,
      materialUrl: json['material_url'] as String?,
      approval: (json['approval'] as int?) ?? 1,
      year: json['year'] as String?,
      clubTypeId: (json['club_type_id'] as int?) ?? 1,
      active: (json['active'] as bool?) ?? true,
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
      'material_url': materialUrl,
      'approval': approval,
      'year': year,
      'club_type_id': clubTypeId,
      'active': active,
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
      materialUrl: materialUrl,
      approval: approval,
      year: year,
      clubTypeId: clubTypeId,
      active: active,
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
    String? materialUrl,
    int? approval,
    String? year,
    int? clubTypeId,
    bool? active,
  }) {
    return HonorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      skillLevel: skillLevel ?? this.skillLevel,
      materialUrl: materialUrl ?? this.materialUrl,
      approval: approval ?? this.approval,
      year: year ?? this.year,
      clubTypeId: clubTypeId ?? this.clubTypeId,
      active: active ?? this.active,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        categoryId,
        imageUrl,
        skillLevel,
        materialUrl,
        approval,
        year,
        clubTypeId,
        active,
      ];
}
