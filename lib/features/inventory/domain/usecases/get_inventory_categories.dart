import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/inventory_category.dart';
import '../repositories/inventory_repository.dart';

class GetInventoryCategories {
  final InventoryRepository repository;

  GetInventoryCategories(this.repository);

  Future<Either<Failure, List<InventoryCategory>>> call({
    CancelToken? cancelToken,
  }) {
    return repository.getCategories(cancelToken: cancelToken);
  }
}
