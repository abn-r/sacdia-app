import 'package:equatable/equatable.dart';

/// Entidad de especialidad del dominio
class Honor extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String? imageUrl;
  final int? skillLevel;

  const Honor({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.imageUrl,
    this.skillLevel,
  });

  @override
  List<Object?> get props => [id, name, description, categoryId, imageUrl, skillLevel];
}
