import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/orden.dart';
import '../../domain/usecases/cancel_order.dart';
import 'materiales_providers.dart';

/// Estado del proceso de cancelación de una orden.
class CancelOrderState {
  final bool isLoading;
  final String? errorMessage;

  const CancelOrderState({
    this.isLoading = false,
    this.errorMessage,
  });

  CancelOrderState copyWith({bool? isLoading, String? errorMessage}) {
    return CancelOrderState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier para cancelar una orden con motivo.
class CancelOrderNotifier extends AutoDisposeNotifier<CancelOrderState> {
  @override
  CancelOrderState build() => const CancelOrderState();

  Future<Either<Failure, Orden>> cancel({
    required String folioOrId,
    required String reason,
  }) async {
    state = const CancelOrderState(isLoading: true);
    final useCase = ref.read(cancelOrderUseCaseProvider);
    final result = await useCase(
      CancelOrderParams(folioOrId: folioOrId, reason: reason),
    );
    state = result.fold(
      (failure) => CancelOrderState(errorMessage: failure.message),
      (_) => const CancelOrderState(),
    );
    return result;
  }
}

/// Provider del notifier de cancelación de orden.
final cancelOrderProvider =
    NotifierProvider.autoDispose<CancelOrderNotifier, CancelOrderState>(
  CancelOrderNotifier.new,
);
