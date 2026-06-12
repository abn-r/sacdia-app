import 'package:equatable/equatable.dart';

/// Entidad de especialidad del dominio
class Honor extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String? categoryName;
  final String? imageUrl;
  final int? skillLevel;
  final String? materialUrl;
  final int approval;
  final String? year;
  final int clubTypeId;
  final String? clubTypeName;
  final bool active;

  const Honor({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    this.categoryName,
    this.imageUrl,
    this.skillLevel,
    this.materialUrl,
    this.approval = 1,
    this.year,
    this.clubTypeId = 1,
    this.clubTypeName,
    this.active = true,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        categoryId,
        categoryName,
        imageUrl,
        skillLevel,
        materialUrl,
        approval,
        year,
        clubTypeId,
        clubTypeName,
        active,
      ];
}
