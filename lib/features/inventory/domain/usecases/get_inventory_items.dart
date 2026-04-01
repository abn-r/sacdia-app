import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class GetInventoryItemsParams extends Equatable {
  final int clubId;
  final String instanceType;

  const GetInventoryItemsParams({
    required this.clubId,
    required this.instanceType,
  });

  @override
  List<Object?> get props => [clubId, instanceType];
}

class GetInventoryItems {
  final InventoryRepository repository;

  GetInventoryItems(this.repository);

  Future<Either<Failure, List<InventoryItem>>> call(
      GetInventoryItemsParams params) {
    return repository.getItems(
      clubId: params.clubId,
      instanceType: params.instanceType,
    );
  }
}
