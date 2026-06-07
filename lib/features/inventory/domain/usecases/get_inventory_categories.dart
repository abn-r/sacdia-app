import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/inventory_category.dart';
import '../repositories/inventory_repository.dart';

class GetInventoryCategories {
  final InventoryRepository repository;

  GetInventoryCategories(this.repository);

  Future<Either<Failure, List<InventoryCategory>>> call({
    RequestCancelToken? cancelToken,
  }) {
    return repository.getCategories(cancelToken: cancelToken);
  }
}
