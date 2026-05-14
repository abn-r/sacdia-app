import 'package:dartz/dartz.dart' hide Order;
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/order.dart';
import '../repositories/materials_repository.dart';

class CancelOrderParams extends Equatable {
  final String folioOrId;
  final String reason;

  const CancelOrderParams({required this.folioOrId, required this.reason});

  @override
  List<Object?> get props => [folioOrId, reason];
}

/// Caso de uso: cancelar una orden con motivo de cancelación.
class CancelOrder implements UseCase<Order, CancelOrderParams> {
  CancelOrder(this._repo);
  final MaterialsRepository _repo;

  @override
  Future<Either<Failure, Order>> call(CancelOrderParams params) =>
      _repo.cancelOrder(params.folioOrId, params.reason);
}
