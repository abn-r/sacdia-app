import '../../domain/entities/finance_category.dart';

class FinanceCategoryModel extends FinanceCategory {
  const FinanceCategoryModel({
    required super.id,
    required super.name,
    super.description,
    super.iconIndex = 0,
    super.typeCode = 0,
  });

  factory FinanceCategoryModel.fromJson(Map<String, dynamic> json) {
    return FinanceCategoryModel(
      id: _parseInt(json['finance_category_id'] ?? json['id'] ?? 0),
      name: (json['name'] ?? 'Sin nombre').toString(),
      description: json['description']?.toString(),
      iconIndex: _parseInt(json['icon'] ?? 0),
      typeCode: _parseInt(json['type'] ?? 0),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  FinanceCategory toEntity() => FinanceCategory(
        id: id,
        name: name,
        description: description,
        iconIndex: iconIndex,
        typeCode: typeCode,
      );
}
