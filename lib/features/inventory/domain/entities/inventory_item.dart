import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

import 'inventory_category.dart';

/// Estado de conservación del ítem.
enum ItemCondition {
  bueno,
  regular,
  malo;

  String get label {
    switch (this) {
      case ItemCondition.bueno:
        return tr('inventory.conditions.good');
      case ItemCondition.regular:
        return tr('inventory.conditions.regular');
      case ItemCondition.malo:
        return tr('inventory.conditions.bad');
    }
  }

  String get shortLabel {
    switch (this) {
      case ItemCondition.bueno:
        return tr('inventory.conditions.good_short');
      case ItemCondition.regular:
        return tr('inventory.conditions.regular');
      case ItemCondition.malo:
        return tr('inventory.conditions.bad_short');
    }
  }
}

/// Foto/evidencia asociada a un artículo de inventario.
class InventoryEvidence extends Equatable {
  final int id;
  final int inventoryId;
  final String url;
  final String fileName;
  final String fileType;
  final int? fileSize;
  final String? uploadedById;
  final DateTime uploadedAt;

  const InventoryEvidence({
    required this.id,
    required this.inventoryId,
    required this.url,
    required this.fileName,
    required this.fileType,
    this.fileSize,
    this.uploadedById,
    required this.uploadedAt,
  });

  @override
  List<Object?> get props => [
        id,
        inventoryId,
        url,
        fileName,
        fileType,
        fileSize,
        uploadedById,
        uploadedAt,
      ];
}

/// Representa un ítem del inventario del club.
class InventoryItem extends Equatable {
  final int id;
  final String name;
  final String? description;
  final InventoryCategory category;
  final int quantity;
  final ItemCondition condition;
  final String? serialNumber;
  final String? photoUrl;
  final List<InventoryEvidence> evidences;
  final DateTime? purchaseDate;
  final double? estimatedValue;
  final String? location;
  final String? assignedTo;
  final String? notes;
  final String registeredByName;
  final DateTime registeredAt;
  final String? modifiedByName;
  final DateTime? modifiedAt;

  const InventoryItem({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.quantity,
    required this.condition,
    this.serialNumber,
    this.photoUrl,
    this.evidences = const [],
    this.purchaseDate,
    this.estimatedValue,
    this.location,
    this.assignedTo,
    this.notes,
    required this.registeredByName,
    required this.registeredAt,
    this.modifiedByName,
    this.modifiedAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        category,
        quantity,
        condition,
        serialNumber,
        photoUrl,
        evidences,
        purchaseDate,
        estimatedValue,
        location,
        assignedTo,
        notes,
        registeredByName,
        registeredAt,
        modifiedByName,
        modifiedAt,
      ];
}
