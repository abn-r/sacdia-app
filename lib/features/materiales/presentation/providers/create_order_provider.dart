import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/material_entrega.dart';
import '../../domain/entities/orden.dart';
import '../../domain/usecases/create_order.dart';
import 'materiales_providers.dart';

/// Estado del proceso de creación de una orden.
class CreateOrderState {
  final bool isLoading;
  final String? errorMessage;

  const CreateOrderState({
    this.isLoading = false,
    this.errorMessage,
  });

  CreateOrderState copyWith({bool? isLoading, String? errorMessage}) {
    return CreateOrderState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier que gestiona el ciclo de vida de la llamada createOrder.
class CreateOrderNotifier extends AutoDisposeNotifier<CreateOrderState> {
  @override
  CreateOrderState build() => const CreateOrderState();

  /// Ejecuta el caso de uso [CreateOrder] y retorna el resultado.
  ///
  /// El estado [isLoading] se activa durante la llamada. Si hay error,
  /// [errorMessage] se rellena y el caller muestra el snackbar adecuado.
  Future<Either<Failure, Orden>> confirm({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialEntrega entrega,
    String? notas,
  }) async {
    state = const CreateOrderState(isLoading: true);
    final useCase = ref.read(createOrderUseCaseProvider);
    final result = await useCase(
      CreateOrderParams(
        clubSectionId: clubSectionId,
        lines: lines,
        entrega: entrega,
        notas: notas,
      ),
    );
    state = result.fold(
      (failure) => CreateOrderState(errorMessage: failure.message),
      (_) => const CreateOrderState(),
    );
    return result;
  }
}

/// Provider del notifier de creación de orden.
final createOrderProvider =
    NotifierProvider.autoDispose<CreateOrderNotifier, CreateOrderState>(
  CreateOrderNotifier.new,
);
