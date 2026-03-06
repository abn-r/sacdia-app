import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/inventory_repository.dart';

class DeleteInventoryItemParams extends Equatable {
  final int itemId;

  const DeleteInventoryItemParams({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class DeleteInventoryItem {
  final InventoryRepository repository;

  DeleteInventoryItem(this.repository);

  Future<Either<Failure, void>> call(DeleteInventoryItemParams params) {
    return repository.deleteItem(itemId: params.itemId);
  }
}
