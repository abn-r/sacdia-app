import 'package:equatable/equatable.dart';
import '../../domain/entities/progressive_class.dart';

/// Modelo de clase progresiva para la capa de datos
class ClassModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int clubTypeId;
  final String? imageUrl;

  const ClassModel({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
  });

  /// Crea una instancia desde JSON
  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      clubTypeId: json['club_type_id'] as int,
      imageUrl: json['image_url'] as String?,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'club_type_id': clubTypeId,
      'image_url': imageUrl,
    };
  }

  /// Convierte el modelo a entidad de dominio
  ProgressiveClass toEntity() {
    return ProgressiveClass(
      id: id,
      name: name,
      description: description,
      clubTypeId: clubTypeId,
      imageUrl: imageUrl,
    );
  }

  /// Crea una copia con campos actualizados
  ClassModel copyWith({
    int? id,
    String? name,
    String? description,
    int? clubTypeId,
    String? imageUrl,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      clubTypeId: clubTypeId ?? this.clubTypeId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [id, name, description, clubTypeId, imageUrl];
}
