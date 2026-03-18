import '../../domain/entities/inventory_item.dart';
import 'inventory_category_model.dart';

class InventoryItemModel extends InventoryItem {
  const InventoryItemModel({
    required super.id,
    required super.name,
    super.description,
    required super.category,
    required super.quantity,
    required super.condition,
    super.serialNumber,
    super.photoUrl,
    super.purchaseDate,
    super.estimatedValue,
    super.location,
    super.assignedTo,
    super.notes,
    required super.registeredByName,
    required super.registeredAt,
    super.modifiedByName,
    super.modifiedAt,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    // Categoria embebida o solo el ID
    final categoryJson =
        json['inventory_categories'] as Map<String, dynamic>? ??
            json['category'] as Map<String, dynamic>? ??
            {
              'id': json['inventory_category_id'] ?? 0,
              'name': 'General',
            };
    final category = InventoryCategoryModel.fromJson(categoryJson).toEntity();

    // Datos del creador
    final createdByUser = json['users'] as Map<String, dynamic>? ?? {};
    final registeredByName =
        _extractName(createdByUser, json['created_by']?.toString() ?? 'Sistema');

    return InventoryItemModel(
      id: _parseInt(json['inventory_id'] ?? json['id'] ?? 0),
      name: (json['name'] ?? 'Sin nombre').toString(),
      description: json['description']?.toString(),
      category: category,
      quantity: _parseInt(json['quantity'] ?? 1),
      condition: _parseCondition(json['condition']?.toString()),
      serialNumber: json['serial_number']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      purchaseDate: json['purchase_date'] != null
          ? _parseDate(json['purchase_date'])
          : null,
      estimatedValue: json['estimated_value'] != null
          ? _parseDouble(json['estimated_value'])
          : null,
      location: json['location']?.toString(),
      assignedTo: json['assigned_to']?.toString(),
      notes: json['notes']?.toString(),
      registeredByName: registeredByName,
      registeredAt: _parseDate(json['created_at']),
      modifiedByName: json['modified_by_name']?.toString(),
      modifiedAt: json['updated_at'] != null
          ? _parseDate(json['updated_at'])
          : null,
    );
  }

  static ItemCondition _parseCondition(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'bueno':
      case 'good':
      case 'buen_estado':
        return ItemCondition.bueno;
      case 'regular':
        return ItemCondition.regular;
      case 'malo':
      case 'bad':
      case 'mal_estado':
        return ItemCondition.malo;
      default:
        return ItemCondition.bueno;
    }
  }

  static String _extractName(Map<String, dynamic> user, String fallback) {
    if (user.isEmpty) return fallback;
    final first = user['name']?.toString() ??
        user['first_name']?.toString() ??
        '';
    final last = user['paternal_last_name']?.toString() ??
        user['last_name']?.toString() ??
        '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : fallback;
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  InventoryItem toEntity() => InventoryItem(
        id: id,
        name: name,
        description: description,
        category: category,
        quantity: quantity,
        condition: condition,
        serialNumber: serialNumber,
        photoUrl: photoUrl,
        purchaseDate: purchaseDate,
        estimatedValue: estimatedValue,
        location: location,
        assignedTo: assignedTo,
        notes: notes,
        registeredByName: registeredByName,
        registeredAt: registeredAt,
        modifiedByName: modifiedByName,
        modifiedAt: modifiedAt,
      );

  /// Serializa la condición al formato que espera el backend.
  static String conditionToString(ItemCondition condition) {
    switch (condition) {
      case ItemCondition.bueno:
        return 'bueno';
      case ItemCondition.regular:
        return 'regular';
      case ItemCondition.malo:
        return 'malo';
    }
  }
}
