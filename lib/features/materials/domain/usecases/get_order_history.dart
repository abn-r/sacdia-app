import 'package:dartz/dartz.dart' hide Order;
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/order.dart';
import '../repositories/materials_repository.dart';

class GetOrderHistoryParams extends Equatable {
  final int page;
  final int pageSize;

  const GetOrderHistoryParams({this.page = 1, this.pageSize = 20});

  @override
  List<Object?> get props => [page, pageSize];
}

/// Caso de uso: obtener historial de órdenes propias del usuario.
class GetOrderHistory implements UseCase<List<Order>, GetOrderHistoryParams> {
  GetOrderHistory(this._repo);
  final MaterialsRepository _repo;

  @override
  Future<Either<Failure, List<Order>>> call(GetOrderHistoryParams params) =>
      _repo.getOrderHistory(page: params.page, pageSize: params.pageSize);
}
