import 'package:equatable/equatable.dart';

/// Entidad de categoría de especialidad del dominio
class HonorCategory extends Equatable {
  final int id;
  final String name;
  final String? description;

  const HonorCategory({
    required this.id,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [id, name, description];
}
