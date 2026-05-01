import 'package:equatable/equatable.dart';

/// Entidad de categoría de logro del dominio
class AchievementCategory extends Equatable {
  final int categoryId;
  final String name;
  final String? description;
  final String? icon;
  final int displayOrder;

  const AchievementCategory({
    required this.categoryId,
    required this.name,
    this.description,
    this.icon,
    this.displayOrder = 0,
  });

  @override
  List<Object?> get props => [
        categoryId,
        name,
        description,
        icon,
        displayOrder,
      ];
}
