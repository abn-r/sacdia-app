import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/achievement_category.dart';

/// Modelo de categoría de logro para la capa de datos
class AchievementCategoryModel extends Equatable {
  final int categoryId;
  final String name;
  final String? description;
  final String? icon;
  final int displayOrder;

  const AchievementCategoryModel({
    required this.categoryId,
    required this.name,
    this.description,
    this.icon,
    this.displayOrder = 0,
  });

  factory AchievementCategoryModel.fromJson(Map<String, dynamic> json) {
    return AchievementCategoryModel(
      categoryId: safeInt(
        json['category_id'] ?? json['achievement_category_id'] ?? json['id'],
      ),
      name: safeString(json['name']),
      description: safeStringOrNull(json['description']),
      icon: safeStringOrNull(json['icon']),
      displayOrder: safeInt(json['display_order']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
    };
  }

  AchievementCategory toEntity() {
    return AchievementCategory(
      categoryId: categoryId,
      name: name,
      description: description,
      icon: icon,
      displayOrder: displayOrder,
    );
  }

  @override
  List<Object?> get props => [categoryId, name, description, icon, displayOrder];
}
