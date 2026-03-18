import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class CreateInventoryItemParams extends Equatable {
  final int clubId;
  final String name;
  final int categoryId;
  final int quantity;
  final ItemCondition condition;
  final String? description;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final double? estimatedValue;
  final String? location;
  final String? assignedTo;
  final String? notes;

  const CreateInventoryItemParams({
    required this.clubId,
    required this.name,
    required this.categoryId,
    required this.quantity,
    required this.condition,
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
        clubId,
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

class CreateInventoryItem {
  final InventoryRepository repository;

  CreateInventoryItem(this.repository);

  Future<Either<Failure, InventoryItem>> call(
      CreateInventoryItemParams params) {
    return repository.createItem(
      clubId: params.clubId,
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
