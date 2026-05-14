import 'package:dartz/dartz.dart' hide Order;
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/order.dart';
import '../repositories/materials_repository.dart';

class GetOrderDetailParams extends Equatable {
  final String folioOrId;

  const GetOrderDetailParams({required this.folioOrId});

  @override
  List<Object?> get props => [folioOrId];
}

/// Caso de uso: obtener detalle completo de una orden por folio o ID.
class GetOrderDetail implements UseCase<Order, GetOrderDetailParams> {
  GetOrderDetail(this._repo);
  final MaterialsRepository _repo;

  @override
  Future<Either<Failure, Order>> call(GetOrderDetailParams params) =>
      _repo.getOrderByFolio(params.folioOrId);
}
