import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/orden.dart';
import '../repositories/materiales_repository.dart';

class GetOrderDetailParams extends Equatable {
  final String folioOrId;

  const GetOrderDetailParams({required this.folioOrId});

  @override
  List<Object?> get props => [folioOrId];
}

/// Caso de uso: obtener detalle completo de una orden por folio o ID.
class GetOrderDetail implements UseCase<Orden, GetOrderDetailParams> {
  GetOrderDetail(this._repo);
  final MaterialesRepository _repo;

  @override
  Future<Either<Failure, Orden>> call(GetOrderDetailParams params) =>
      _repo.getOrderByFolio(params.folioOrId);
}
