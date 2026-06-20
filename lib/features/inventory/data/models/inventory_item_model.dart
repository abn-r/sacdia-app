import '../../domain/entities/inventory_item.dart';
import 'inventory_category_model.dart';

class InventoryEvidenceModel extends InventoryEvidence {
  const InventoryEvidenceModel({
    required super.id,
    required super.inventoryId,
    required super.url,
    required super.fileName,
    required super.fileType,
    super.fileSize,
    super.uploadedById,
    required super.uploadedAt,
  });

  factory InventoryEvidenceModel.fromJson(Map<String, dynamic> json) {
    return InventoryEvidenceModel(
      id: InventoryItemModel._parseInt(json['evidence_id'] ??
          json['inventory_evidence_file_id'] ??
          json['id'] ??
          0),
      inventoryId: InventoryItemModel._parseInt(json['inventory_id'] ?? 0),
      url: (json['url'] ?? json['file_url'] ?? '').toString(),
      fileName: (json['file_name'] ?? json['name'] ?? 'Evidencia').toString(),
      fileType: (json['file_type'] ?? json['mime_type'] ?? '').toString(),
      fileSize: json['file_size'] != null
          ? InventoryItemModel._parseInt(json['file_size'])
          : null,
      uploadedById: json['uploaded_by_id']?.toString(),
      uploadedAt: InventoryItemModel._parseDate(json['uploaded_at']),
    );
  }

  InventoryEvidence toEntity() => InventoryEvidence(
        id: id,
        inventoryId: inventoryId,
        url: url,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        uploadedById: uploadedById,
        uploadedAt: uploadedAt,
      );
}

class InventoryItemModel extends InventoryItem {
  const InventoryItemModel({
    required super.id,
    required super.name,
    super.description,
    required super.category,
    required super.quantity,
    required super.condition,
    super.clubSectionId,
    super.isActive,
    super.serialNumber,
    super.photoUrl,
    super.evidences,
    super.purchaseDate,
    super.estimatedValue,
    super.location,
    super.assignedTo,
    super.notes,
    required super.registeredByName,
    super.registeredByAvatarUrl,
    required super.registeredAt,
    super.modifiedByName,
    super.modifiedByAvatarUrl,
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
    final createdByUser = _mapOrNull(json['users']) ??
        _mapOrNull(json['created_by']) ??
        _mapOrNull(json['registered_by']) ??
        {};
    final registeredByName = _extractName(
      createdByUser,
      json['created_by_name']?.toString() ??
          _stringOrNull(json['created_by']) ??
          'Sistema',
    );
    final registeredByAvatarUrl = _extractAvatar(
      createdByUser,
      json['created_by_avatar_url']?.toString() ??
          json['registered_by_avatar_url']?.toString(),
    );

    final modifiedByUser = _mapOrNull(json['modified_by']) ?? {};
    final modifiedByName = _emptyToNull(_extractName(
      modifiedByUser,
      json['modified_by_name']?.toString() ??
          _stringOrNull(json['modified_by']) ??
          '',
    ));
    final modifiedByAvatarUrl = _extractAvatar(
      modifiedByUser,
      json['modified_by_avatar_url']?.toString(),
    );

    final evidences = (json['evidences'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(InventoryEvidenceModel.fromJson)
        .toList();

    return InventoryItemModel(
      id: _parseInt(json['inventory_id'] ?? json['id'] ?? 0),
      name: (json['name'] ?? 'Sin nombre').toString(),
      description: json['description']?.toString(),
      category: category,
      quantity: _parseInt(json['amount'] ?? json['quantity'] ?? 1),
      condition: _parseCondition(json['condition']?.toString()),
      clubSectionId: json['club_section_id'] != null
          ? _parseInt(json['club_section_id'])
          : null,
      isActive: json['active'] != false,
      serialNumber: json['serial_number']?.toString(),
      photoUrl: json['photo_url']?.toString() ??
          (evidences.isNotEmpty ? evidences.first.url : null),
      evidences: evidences,
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
      registeredByAvatarUrl: registeredByAvatarUrl,
      registeredAt: _parseDate(json['created_at']),
      modifiedByName: modifiedByName,
      modifiedByAvatarUrl: modifiedByAvatarUrl,
      modifiedAt:
          json['updated_at'] != null ? _parseDate(json['updated_at']) : null,
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
    final first =
        user['name']?.toString() ?? user['first_name']?.toString() ?? '';
    final last = user['paternal_last_name']?.toString() ??
        user['last_name']?.toString() ??
        '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : fallback;
  }

  static String? _extractAvatar(Map<String, dynamic> user, String? fallback) {
    final value = user['avatar_url'] ??
        user['avatar'] ??
        user['user_image'] ??
        user['photo_url'] ??
        fallback;
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
        clubSectionId: clubSectionId,
        isActive: isActive,
        serialNumber: serialNumber,
        photoUrl: photoUrl,
        evidences: evidences,
        purchaseDate: purchaseDate,
        estimatedValue: estimatedValue,
        location: location,
        assignedTo: assignedTo,
        notes: notes,
        registeredByName: registeredByName,
        registeredByAvatarUrl: registeredByAvatarUrl,
        registeredAt: registeredAt,
        modifiedByName: modifiedByName,
        modifiedByAvatarUrl: modifiedByAvatarUrl,
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
