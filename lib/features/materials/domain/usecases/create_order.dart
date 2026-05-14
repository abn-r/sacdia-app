import 'package:dartz/dartz.dart' hide Order;
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/material_delivery.dart';
import '../entities/order.dart';
import '../repositories/materials_repository.dart';

class CreateOrderParams extends Equatable {
  final int clubSectionId;
  final List<({String productId, String? variantOptionId, int qty})> lines;
  final MaterialDelivery delivery;
  final String? notas;

  const CreateOrderParams({
    required this.clubSectionId,
    required this.lines,
    required this.delivery,
    this.notas,
  });

  @override
  List<Object?> get props => [clubSectionId, lines, delivery, notas];
}

/// Caso de uso: crear una nueva orden de materiales.
class CreateOrder implements UseCase<Order, CreateOrderParams> {
  CreateOrder(this._repo);
  final MaterialsRepository _repo;

  @override
  Future<Either<Failure, Order>> call(CreateOrderParams params) =>
      _repo.createOrder(
        clubSectionId: params.clubSectionId,
        lines: params.lines,
        delivery: params.delivery,
        notas: params.notas,
      );
}
