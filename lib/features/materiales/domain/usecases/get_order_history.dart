import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/orden.dart';
import '../repositories/materiales_repository.dart';

class GetOrderHistoryParams extends Equatable {
  final int page;
  final int pageSize;

  const GetOrderHistoryParams({this.page = 1, this.pageSize = 20});

  @override
  List<Object?> get props => [page, pageSize];
}

/// Caso de uso: obtener historial de órdenes propias del usuario.
///
/// Usa GET /ordenes/historial — siempre filtrado por created_by del caller.
class GetOrderHistory implements UseCase<List<Orden>, GetOrderHistoryParams> {
  GetOrderHistory(this._repo);
  final MaterialesRepository _repo;

  @override
  Future<Either<Failure, List<Orden>>> call(GetOrderHistoryParams params) =>
      _repo.getOrderHistory(page: params.page, pageSize: params.pageSize);
}
