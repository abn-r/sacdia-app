import 'package:equatable/equatable.dart';
import '../../domain/entities/honor_group.dart';
import '../models/honor_category_model.dart';
import '../models/honor_model.dart';

const String _honorImagesBase =
    'https://sacdia-files.s3.us-east-1.amazonaws.com/Especialidades/';

String? _buildImageUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  return '$_honorImagesBase$raw';
}

/// Modelo de grupo de especialidades por categoría para la capa de datos
class HonorGroupModel extends Equatable {
  final HonorCategoryModel category;
  final List<HonorModel> honors;

  const HonorGroupModel({
    required this.category,
    required this.honors,
  });

  /// Crea una instancia desde JSON del endpoint grouped-by-category.
  ///
  /// Formato esperado:
  /// ```json
  /// {
  ///   "category": { "honor_category_id": 1, "name": "...", "description": "...", "icon": 3 },
  ///   "honors": [ { "honor_id": 10, "name": "...", "honor_image": null, "skill_level": 1, ... } ]
  /// }
  /// ```
  factory HonorGroupModel.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'] as Map<String, dynamic>;

    // honor_category_id puede ser null (categoría "Sin categoría")
    final rawCategoryId = categoryJson['honor_category_id'];
    final categoryId = (rawCategoryId as int?) ?? 0;

    final category = HonorCategoryModel(
      id: categoryId,
      name: categoryJson['name'] as String,
      description: categoryJson['description'] as String?,
    );

    final honorsJson = json['honors'] as List<dynamic>;
    final honors = honorsJson.map((h) {
      final honorMap = h as Map<String, dynamic>;
      // Los honores en este endpoint usan honor_image en vez de image_url
      return HonorModel(
        id: (honorMap['honor_id'] ?? honorMap['id']) as int,
        name: honorMap['name'] as String,
        description: honorMap['description'] as String?,
        categoryId: (honorMap['honor_category_id'] as int?) ?? categoryId,
        imageUrl: _buildImageUrl(honorMap['honor_image'] as String?),
        skillLevel: honorMap['skill_level'] as int?,
        materialUrl: honorMap['material_url'] as String?,
      );
    }).toList();

    return HonorGroupModel(category: category, honors: honors);
  }

  /// Convierte el modelo a entidad de dominio
  HonorGroup toEntity() {
    return HonorGroup(
      category: category.toEntity(),
      honors: honors.map((h) => h.toEntity()).toList(),
    );
  }

  @override
  List<Object?> get props => [category, honors];
}
