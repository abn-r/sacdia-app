import 'package:equatable/equatable.dart';

/// Categoría de producto en el catálogo de materiales.
class MaterialCategory extends Equatable {
  final String id;
  final String slug;
  final String label;
  final String? icon;
  final int sortOrder;

  const MaterialCategory({
    required this.id,
    required this.slug,
    required this.label,
    this.icon,
    required this.sortOrder,
  });

  @override
  List<Object?> get props => [id, slug, label, icon, sortOrder];
}
