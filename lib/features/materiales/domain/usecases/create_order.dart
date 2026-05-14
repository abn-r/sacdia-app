import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/material_entrega.dart';
import '../entities/orden.dart';
import '../repositories/materiales_repository.dart';

class CreateOrderParams extends Equatable {
  final int clubSectionId;
  final List<({String productId, String? variantOptionId, int qty})> lines;
  final MaterialEntrega entrega;
  final String? notas;

  const CreateOrderParams({
    required this.clubSectionId,
    required this.lines,
    required this.entrega,
    this.notas,
  });

  @override
  List<Object?> get props => [clubSectionId, lines, entrega, notas];
}

/// Caso de uso: crear una nueva orden de materiales.
class CreateOrder implements UseCase<Orden, CreateOrderParams> {
  CreateOrder(this._repo);
  final MaterialesRepository _repo;

  @override
  Future<Either<Failure, Orden>> call(CreateOrderParams params) =>
      _repo.createOrder(
        clubSectionId: params.clubSectionId,
        lines: params.lines,
        entrega: params.entrega,
        notas: params.notas,
      );
}
