import '../../domain/entities/inventory_category.dart';

class InventoryCategoryModel extends InventoryCategory {
  const InventoryCategoryModel({
    required super.id,
    required super.name,
  });

  factory InventoryCategoryModel.fromJson(Map<String, dynamic> json) {
    return InventoryCategoryModel(
      id: _parseInt(json['inventory_category_id'] ?? json['id'] ?? 0),
      name: (json['name'] ?? 'Sin categoría').toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  InventoryCategory toEntity() => InventoryCategory(id: id, name: name);
}
