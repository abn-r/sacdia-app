import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class UpdateInventoryItemParams extends Equatable {
  final int itemId;
  final String? name;
  final int? categoryId;
  final int? quantity;
  final ItemCondition? condition;
  final String? description;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final double? estimatedValue;
  final String? location;
  final String? assignedTo;
  final String? notes;

  const UpdateInventoryItemParams({
    required this.itemId,
    this.name,
    this.categoryId,
    this.quantity,
    this.condition,
    this.description,
    this.serialNumber,
    this.purchaseDate,
    this.estimatedValue,
    this.location,
    this.assignedTo,
    this.notes,
  });

  @override
  List<Object?> get props => [
        itemId,
        name,
        categoryId,
        quantity,
        condition,
        description,
        serialNumber,
        purchaseDate,
        estimatedValue,
        location,
        assignedTo,
        notes,
      ];
}

class UpdateInventoryItem {
  final InventoryRepository repository;

  UpdateInventoryItem(this.repository);

  Future<Either<Failure, InventoryItem>> call(
      UpdateInventoryItemParams params) {
    return repository.updateItem(
      itemId: params.itemId,
      name: params.name,
      categoryId: params.categoryId,
      quantity: params.quantity,
      condition: params.condition,
      description: params.description,
      serialNumber: params.serialNumber,
      purchaseDate: params.purchaseDate,
      estimatedValue: params.estimatedValue,
      location: params.location,
      assignedTo: params.assignedTo,
      notes: params.notes,
    );
  }
}
