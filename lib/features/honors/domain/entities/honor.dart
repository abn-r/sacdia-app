import 'package:equatable/equatable.dart';

/// Entidad de especialidad del dominio
class Honor extends Equatable {
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

  const Honor({
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
