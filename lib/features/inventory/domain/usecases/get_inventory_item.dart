import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class GetInventoryItemParams extends Equatable {
  final int itemId;

  const GetInventoryItemParams({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class GetInventoryItem {
  final InventoryRepository repository;

  GetInventoryItem(this.repository);

  Future<Either<Failure, InventoryItem>> call(
    GetInventoryItemParams params, {
    CancelToken? cancelToken,
  }) {
    return repository.getItem(
      itemId: params.itemId,
      cancelToken: cancelToken,
    );
  }
}
