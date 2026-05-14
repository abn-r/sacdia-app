import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/material_item.dart';
import '../repositories/materiales_repository.dart';

class GetProductDetailParams extends Equatable {
  final String id;

  const GetProductDetailParams({required this.id});

  @override
  List<Object?> get props => [id];
}

/// Caso de uso: obtener detalle completo de un producto del catálogo.
class GetProductDetail
    implements UseCase<MaterialItem, GetProductDetailParams> {
  GetProductDetail(this._repo);
  final MaterialesRepository _repo;

  @override
  Future<Either<Failure, MaterialItem>> call(
          GetProductDetailParams params) =>
      _repo.getProductDetail(params.id);
}
