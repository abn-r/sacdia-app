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
